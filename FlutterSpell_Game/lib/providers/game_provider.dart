import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../services/api_client.dart';
import '../services/sound_service.dart';

class GameProvider extends ChangeNotifier {
  late ApiClient apiClient;
  late String _userName;
  late SoundService _soundService;
  late SharedPreferences _prefs;

  List<Level> levels = [];
  List<DeckCard> deckCards = [];
  List<LessonSummary> englishLessons = [];
  List<LessonSummary> chineseLessons = [];
  bool isLoggedIn = false;
  List<String> recentUsers = [];

  List<Word> get deckWords => deckCards.map((c) => c.word).toList();
  Level? currentLevel;
  LevelProgress? currentProgress;
  UserStats? userStats;
  List<Unlockable> unlockables = [];
  List<LeaderboardEntry> leaderboard = [];
  List<Challenge> challenges = [];
  String currentLeaderboardFilter = 'global';

  bool isLoading = false;
  String? errorMessage;
  bool _soundEnabled = true;

  String get userName => _userName;
  bool get soundEnabled => _soundEnabled;

  void init(String userName) {
    _userName = userName;
    apiClient = ApiClient(userName: userName);
    _soundService = SoundService();
    _initializeSoundSettings();
  }

  Future<void> _initializeSoundSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
    await _soundService.init();
    if (!_soundEnabled) {
      await _soundService.setSoundEnabled(false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _soundService.setSoundEnabled(enabled);
    await _prefs.setBool('sound_enabled', enabled);
    notifyListeners();
  }

  /// Login with password verification, then record the login event and
  /// persist the session (see [_onAuthenticated]).
  Future<bool> login(String password) async {
    try {
      final verified = await apiClient.verifyPassword(password);
      isLoggedIn = verified;
      if (verified) {
        await _onAuthenticated(_userName);
        await apiClient.logLogin();
      }
      notifyListeners();
      return verified;
    } catch (e) {
      errorMessage = 'Login failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Loads the up-to-5 most-recently-used usernames on this device, most
  /// recent first, for the login screen's quick-pick list.
  Future<void> loadRecentUsers() async {
    final prefs = await SharedPreferences.getInstance();
    recentUsers = prefs.getStringList('recent_users') ?? [];
    notifyListeners();
  }

  Future<void> _addRecentUser(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('recent_users') ?? [];
    existing.remove(name);
    existing.insert(0, name);
    final trimmed = existing.take(5).toList();
    await prefs.setStringList('recent_users', trimmed);
    recentUsers = trimmed;
  }

  Future<void> _persistSession(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_user', name);
  }

  /// Marks the current user as authenticated: persists the session so the
  /// next app open restores it automatically, and records the username for
  /// the login screen's quick-pick list. Shared by [login], [signup], and
  /// [restoreSession] so all three authentication paths stay in sync.
  Future<void> _onAuthenticated(String name) async {
    isLoggedIn = true;
    await _persistSession(name);
    await _addRecentUser(name);
    notifyListeners();
  }

  /// Restores a session persisted from a previous app open. Trusts the
  /// stored username without re-verifying a password (none is stored
  /// client-side) - [init] must be called with the same name first.
  Future<void> restoreSession(String userName) async {
    await _onAuthenticated(userName);
    // Fire-and-forget: a failed streak-tracking call shouldn't block
    // startup or undo an otherwise-valid restored session.
    unawaited(apiClient.logLogin().catchError((_) {}));
  }

  /// Creates a new account, then signs it in. Returns false (with
  /// [errorMessage] set) on failure - most commonly a 409 because the
  /// username is already taken.
  Future<bool> signup({
    required String name,
    String? password,
    String? grade,
  }) async {
    try {
      init(name);
      await apiClient.createUser(name: name, password: password, grade: grade);
      await _onAuthenticated(name);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Ends the current session: clears cached per-user data so a new user's
  /// screens never flash the previous user's data, and forgets the
  /// persisted session (but keeps the recent-users list - that's "who's
  /// used this browser," independent of who's currently signed in).
  Future<void> logout() async {
    isLoggedIn = false;
    levels = [];
    deckCards = [];
    englishLessons = [];
    chineseLessons = [];
    currentLevel = null;
    currentProgress = null;
    userStats = null;
    unlockables = [];
    leaderboard = [];
    challenges = [];
    errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_user');
    notifyListeners();
  }

  /// Load the user's real word deck from the backend, optionally scoped to
  /// a lesson's tags (see [ApiClient.getDeckCards]).
  Future<void> loadDeck({List<String>? tags}) async {
    try {
      deckCards = await apiClient.getDeckCards(tags: tags);
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Load the user's grade-filtered lessons for a subject ('EN' or 'CN').
  Future<void> loadLessons(String subject) async {
    try {
      final result = await apiClient.getLessons(subject);
      if (subject.toUpperCase() == 'EN') {
        englishLessons = result;
      } else {
        chineseLessons = result;
      }
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Submit one word's review outcome. Fire-and-forget from the study
  /// screen's perspective: a failed submission shouldn't block gameplay.
  Future<void> submitReview(int wordId, int quality) async {
    try {
      await apiClient.submitReview(wordId, quality);
    } catch (e) {
      errorMessage = e.toString();
    }
  }

  Future<void> loadLevels() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      levels = await apiClient.getLevelList();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLevelDetails(int levelId) async {
    isLoading = true;
    errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      currentLevel = await apiClient.getLevelDetails(levelId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  Future<Map<String, dynamic>?> completeLevel(int levelId, double accuracy) async {
    try {
      final result = await apiClient.completeLevelStudy(levelId, accuracy);

      // Reload levels to update progress
      await loadLevels();
      await loadUserStats();

      return result;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadUserStats() async {
    try {
      userStats = await apiClient.getUserStats();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadUnlockables() async {
    try {
      unlockables = await apiClient.getUnlockables();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> redeemUnlockable(int unlockableId) async {
    try {
      await apiClient.redeemUnlockable(unlockableId);
      await loadUnlockables();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createChallenge(String challengeeName, int levelId) async {
    try {
      await apiClient.createChallenge(challengeeName, levelId);
      await loadChallenges();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadLeaderboard({String filter = 'global'}) async {
    isLoading = true;
    errorMessage = null;
    currentLeaderboardFilter = filter;
    notifyListeners();

    try {
      leaderboard = await apiClient.getLeaderboard(filter: filter);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChallenges() async {
    try {
      challenges = await apiClient.getChallenges();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<bool> acceptChallenge(int challengeId) async {
    try {
      await apiClient.acceptChallenge(challengeId);
      await loadChallenges();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeChallenge(int challengeId, double accuracy) async {
    try {
      await apiClient.completeChallenge(challengeId, accuracy);
      await loadChallenges();
      await loadUserStats();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
