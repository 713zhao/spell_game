import 'package:flutter/material.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/services/api_client.dart';

/// A controllable GameProvider test double for widget tests that never
/// hits the network, following the same pattern as
/// test/screens/home_screen_test.dart's TestGameProvider. Test code sets
/// the `*Result` fields to control what login/signup report back, and
/// reads the `*Called`/`last*` fields to assert what was invoked.
class FakeGameProvider extends ChangeNotifier implements GameProvider {
  @override
  late ApiClient apiClient = ApiClient(userName: 'TestUser');

  @override
  List<Level> levels = [];

  @override
  List<DeckCard> deckCards = [];

  @override
  List<Word> get deckWords => deckCards.map((c) => c.word).toList();

  @override
  List<LessonSummary> englishLessons = [];

  @override
  List<LessonSummary> chineseLessons = [];

  @override
  bool isLoggedIn = false;

  @override
  List<String> recentUsers = [];

  @override
  Level? currentLevel;

  @override
  LevelProgress? currentProgress;

  @override
  UserStats? userStats;

  @override
  Map<String, dynamic>? userProfile;

  @override
  List<Unlockable> unlockables = [];

  @override
  List<LeaderboardEntry> leaderboard = [];

  @override
  List<Challenge> challenges = [];

  @override
  String currentLeaderboardFilter = 'global';

  @override
  bool isLoading = false;

  @override
  String? errorMessage;

  @override
  bool get soundEnabled => true;

  String _userName = 'TestUser';

  @override
  String get userName => _userName;

  // Test hooks.
  bool loggedOutCalled = false;
  bool signupCalled = false;
  bool signupResult = true;
  bool loginCalled = false;
  bool loginResult = true;
  String? lastLoginPassword;
  String? lastSignupName;

  @override
  void init(String userName) {
    _userName = userName;
  }

  @override
  Future<bool> login(String password) async {
    loginCalled = true;
    lastLoginPassword = password;
    isLoggedIn = loginResult;
    notifyListeners();
    return loginResult;
  }

  @override
  Future<bool> signup({
    required String name,
    String? password,
    String? grade,
  }) async {
    signupCalled = true;
    lastSignupName = name;
    if (signupResult) {
      _userName = name;
      isLoggedIn = true;
    } else {
      errorMessage = 'That username is already taken';
    }
    notifyListeners();
    return signupResult;
  }

  @override
  Future<void> logout() async {
    loggedOutCalled = true;
    isLoggedIn = false;
    notifyListeners();
  }

  @override
  Future<void> restoreSession(String userName) async {
    _userName = userName;
    isLoggedIn = true;
    notifyListeners();
  }

  @override
  Future<void> loadRecentUsers() async {
    notifyListeners();
  }

  bool loginAsGuestCalled = false;

  @override
  Future<void> loginAsGuest() async {
    loginAsGuestCalled = true;
    _userName = 'GUEST';
    isLoggedIn = false;
    notifyListeners();
  }

  bool loginQuickCalled = false;
  String? lastLoginQuickName;
  bool loginQuickResult = false;

  @override
  Future<bool> loginQuick(String name) async {
    loginQuickCalled = true;
    lastLoginQuickName = name;
    if (loginQuickResult) {
      _userName = name;
      isLoggedIn = true;
    }
    notifyListeners();
    return loginQuickResult;
  }

  @override
  Future<void> loadDeck({List<String>? tags}) async {}

  @override
  Future<void> loadLessons(String subject) async {}

  @override
  Future<void> submitReview(int wordId, int quality) async {}

  @override
  Future<void> loadLevels() async {}

  @override
  Future<void> loadLevelDetails(int levelId) async {}

  @override
  Future<Map<String, dynamic>?> completeLevel(int levelId, double accuracy) async => {};

  @override
  Future<void> loadUserStats() async {}

  @override
  Future<void> loadUnlockables() async {}

  @override
  Future<bool> redeemUnlockable(int unlockableId) async => true;

  @override
  Future<bool> createChallenge(String challengeeName, int levelId) async => true;

  @override
  Future<void> loadLeaderboard({String filter = 'global'}) async {}

  @override
  Future<void> loadChallenges() async {}

  @override
  Future<bool> acceptChallenge(int challengeId) async => true;

  @override
  Future<bool> completeChallenge(int challengeId, double accuracy) async => true;

  bool loadUserProfileCalled = false;

  @override
  Future<void> loadUserProfile() async {
    loadUserProfileCalled = true;
    notifyListeners();
  }

  bool updateProfileCalled = false;
  Map<String, dynamic>? lastUpdateProfileData;
  bool updateProfileResult = true;

  @override
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    updateProfileCalled = true;
    lastUpdateProfileData = data;
    if (updateProfileResult) {
      userProfile = {...(userProfile ?? {}), ...data};
    } else {
      errorMessage = 'Failed to update profile: simulated failure';
    }
    notifyListeners();
    return updateProfileResult;
  }

  @override
  Future<void> setSoundEnabled(bool enabled) async {}
}
