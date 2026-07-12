import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../services/api_client.dart';

class GameProvider extends ChangeNotifier {
  late ApiClient apiClient;

  List<Level> levels = [];
  Level? currentLevel;
  LevelProgress? currentProgress;
  UserStats? userStats;
  List<Unlockable> unlockables = [];

  bool isLoading = false;
  String? errorMessage;

  void init(String userName) {
    apiClient = ApiClient(userName: userName);
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
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
