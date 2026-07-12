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
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    await _soundService.setSoundEnabled(enabled);
    await _prefs.setBool('sound_enabled', enabled);
    notifyListeners();
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
    notifyListeners();

    try {
      currentLevel = await apiClient.getLevelDetails(levelId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
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
