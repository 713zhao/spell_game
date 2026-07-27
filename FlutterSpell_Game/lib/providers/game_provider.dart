import 'dart:async';
import 'dart:convert';
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
  Map<String, dynamic>? userProfile;
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
        await _savePassword(_userName, password);
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

    // Evict saved passwords for anyone who fell out of the trimmed list,
    // so storage doesn't grow unbounded for names no longer reachable
    // from the quick-pick list.
    final saved = _readSavedPasswords(prefs);
    saved.removeWhere((key, _) => !trimmed.contains(key));
    await prefs.setString('saved_passwords', jsonEncode(saved));
  }

  Map<String, String> _readSavedPasswords(SharedPreferences prefs) {
    final raw = prefs.getString('saved_passwords');
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as String));
  }

  Future<void> _savePassword(String name, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _readSavedPasswords(prefs);
    saved[name] = password;
    await prefs.setString('saved_passwords', jsonEncode(saved));
  }

  Future<String?> _getSavedPassword(String name) async {
    final prefs = await SharedPreferences.getInstance();
    return _readSavedPasswords(prefs)[name];
  }

  /// Attempts to log in [name] using a password saved locally from a
  /// previous successful login/signup (see [_savePassword]). Returns
  /// false without any network call if there's no saved password - the
  /// caller (the login screen's quick-pick) should fall back to asking
  /// for one manually. A saved-but-now-stale password (e.g. changed via
  /// the admin panel) is caught the same way a manually-typed wrong
  /// password is, via the real verification inside [login].
  Future<bool> loginQuick(String name) async {
    final saved = await _getSavedPassword(name);
    if (saved == null) return false;
    init(name);
    return await login(saved);
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
    // startup or undo an otherwise-valid restored session. The error is
    // intentionally swallowed here rather than surfaced via errorMessage.
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
      await ApiClient(
        userName: name,
      ).createUser(name: name, password: password, grade: grade);
      init(name);
      await _onAuthenticated(name);
      if (password != null && password.isNotEmpty) {
        await _savePassword(name, password);
      }
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Enters the app as a shared "Guest" identity when there's no session
  /// to restore, so Home works immediately instead of forcing a login.
  /// Guest is a fallback, not a remembered account: unlike [login]/[signup]/
  /// [restoreSession], this never touches `last_user`/`recent_users`, and
  /// leaves [isLoggedIn] false so the account button keeps inviting the
  /// user to sign in for real.
  Future<void> loginAsGuest() async {
    init('GUEST');
    // Explicit, not just relying on the default: guards against being
    // called as a fallback after a partially-failed restoreSession that
    // already flipped isLoggedIn to true before throwing.
    isLoggedIn = false;
    try {
      // Idempotent: the backend only needs a name to create a user, and
      // treats a repeat call as "already exists" - either way, GUEST ends
      // up present so the data-loading calls below don't 404.
      await apiClient.createUser(name: 'GUEST');
    } catch (_) {
      // Already exists, or a transient error - proceed regardless; if
      // GUEST truly isn't reachable server-side, the screens' own data
      // loads will surface that the same way any other backend hiccup
      // would.
    }
    notifyListeners();
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
  ///
  /// Clears [deckCards] synchronously before the awaited fetch so that any
  /// screen reading it mid-flight (e.g. Lesson Overview's word-detail grid)
  /// sees an empty/loading state instead of a previous lesson's stale cards
  /// while this one is still in flight.
  Future<void> loadDeck({List<String>? tags, int limit = 10}) async {
    deckCards = [];
    notifyListeners();
    try {
      deckCards = await apiClient.getDeckCards(tags: tags, limit: limit);
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

  Future<Map<String, dynamic>?> completeLevel(
    int levelId,
    double accuracy,
  ) async {
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

  /// Fetch the full account profile (age/grade/school/email/phone) shown
  /// on the Profile tab's editable "Profile Details" card.
  Future<void> loadUserProfile() async {
    try {
      userProfile = await apiClient.getUserProfile();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Save edited profile fields, then reload so [userProfile] reflects
  /// what the backend actually stored (e.g. its upper-casing of some
  /// fields). Returns success/failure instead of throwing, matching
  /// [redeemUnlockable]/[createChallenge]'s convention - callers check the
  /// bool and read [errorMessage] on failure.
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      await apiClient.updateUserProfile(data);
      await loadUserProfile();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
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
