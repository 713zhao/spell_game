# Login, Signup & Account Access Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the app's hardcoded-ERIC startup with a real login/signup flow: a top-right account button on every main screen, a login screen with a quick-pick list of recently-used names on this device, a signup screen, and working logout/user-switching.

**Architecture:** All frontend work — the backend (`POST /users/`, `POST /users/{name}/verify-password`) already supports this. `GameProvider` gains session methods (`login` extended, `signup`, `logout`, `restoreSession`) backed by two `SharedPreferences` keys (`last_user`, `recent_users`). A new `AuthGate` widget replaces the hardcoded `HomeScreen(userName: 'ERIC')` as the app's startup widget, silently restoring a persisted session or falling through to a new `LoginScreen`. A reusable `AccountAvatarButton` widget is added to 12 screens' app bars.

**Tech Stack:** Flutter web, `provider` package for state, `shared_preferences` for local persistence, existing `DuolingoColors`/`DuolingoTextStyles`/`DuolingoSpacing` design system.

Spec: `docs/superpowers/specs/2026-07-18-login-signup-account-access-design.md`

**Testing note:** `ApiClient` calls the `http` package's static functions directly (no injectable `http.Client`), and this codebase has no existing HTTP-mocking infrastructure. Consistent with that existing pattern, network-dependent paths (`ApiClient.createUser`, the verify-password branch of `login()`) are implemented but not unit-tested in isolation — they're covered by widget tests using a controllable fake `GameProvider` (never hitting real HTTP), same pattern as `test/screens/home_screen_test.dart`'s existing `TestGameProvider`. The parts that don't need real network — session persistence, recent-users list management, logout's state reset — are fully unit-tested against `SharedPreferences.setMockInitialValues()`.

---

### Task 1: `ApiClient.createUser`

**Files:**
- Modify: `FlutterSpell_Game/lib/services/api_client.dart`

- [ ] **Step 1: Add the method**

In `FlutterSpell_Game/lib/services/api_client.dart`, add this method to the `ApiClient` class (e.g. right after `logLogin()`):

```dart
  /// Creates a new account. Only [name] is required - the backend defaults
  /// everything else. Throws with the backend's error detail on failure,
  /// notably a 409 when the username is already taken.
  Future<void> createUser({
    required String name,
    String? password,
    String? grade,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        if (password != null && password.isNotEmpty) 'password': password,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to create account';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }
```

- [ ] **Step 2: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/services/api_client.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_client.dart
git commit -m "feat: add ApiClient.createUser for signup"
```

---

### Task 2: `GameProvider` session methods

**Files:**
- Modify: `FlutterSpell_Game/lib/providers/game_provider.dart`
- Modify: `FlutterSpell_Game/test/screens/home_screen_test.dart` (its `TestGameProvider` fake must implement every `GameProvider` method to keep compiling)
- Test: `FlutterSpell_Game/test/providers/game_provider_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/providers/game_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameProvider session management', () {
    test('restoreSession sets isLoggedIn and persists last_user + recent_users',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.restoreSession('ERIC');

      expect(provider.isLoggedIn, true);
      expect(provider.userName, 'ERIC');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_user'), 'ERIC');
      expect(prefs.getStringList('recent_users'), ['ERIC']);
    });

    test('restoreSession moves an already-recent user to the front without duplicating',
        () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['HELLEN', 'ERIC'],
      });
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.restoreSession('ERIC');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_users'), ['ERIC', 'HELLEN']);
    });

    test('recent_users is capped at 5, dropping the oldest', () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['A', 'B', 'C', 'D', 'E'],
      });
      final provider = GameProvider();
      provider.init('F');

      await provider.restoreSession('F');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_users'), ['F', 'A', 'B', 'C', 'D']);
    });

    test('loadRecentUsers populates recentUsers from storage', () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['ERIC', 'HELLEN'],
      });
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.loadRecentUsers();

      expect(provider.recentUsers, ['ERIC', 'HELLEN']);
    });

    test('logout clears session and cached data but keeps recent_users',
        () async {
      SharedPreferences.setMockInitialValues({
        'last_user': 'ERIC',
        'recent_users': ['ERIC'],
      });
      final provider = GameProvider();
      provider.init('ERIC');
      provider.isLoggedIn = true;
      provider.userStats = UserStats(totalPoints: 100, currentStreak: 5);
      provider.errorMessage = 'stale error';

      await provider.logout();

      expect(provider.isLoggedIn, false);
      expect(provider.userStats, isNull);
      expect(provider.errorMessage, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_user'), isNull);
      expect(prefs.getStringList('recent_users'), ['ERIC']);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `FlutterSpell_Game/`): `flutter test test/providers/game_provider_test.dart`
Expected: FAIL to compile — `restoreSession`, `loadRecentUsers`, `recentUsers`, and `logout` don't exist yet on `GameProvider`.

- [ ] **Step 3: Add `dart:async` import and the `recentUsers` field**

In `FlutterSpell_Game/lib/providers/game_provider.dart`, change the top imports from:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../services/api_client.dart';
import '../services/sound_service.dart';
```

to:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';
import '../services/api_client.dart';
import '../services/sound_service.dart';
```

Then add a new field next to the other lists (right after `bool isLoggedIn = false;`):

```dart
  bool isLoggedIn = false;
  List<String> recentUsers = [];
```

- [ ] **Step 4: Replace `login()` and add the new session methods**

Change the existing `login()` method from:

```dart
  /// Login with password verification, then record the login event.
  Future<bool> login(String password) async {
    try {
      isLoggedIn = await apiClient.verifyPassword(password);
      if (isLoggedIn) {
        await apiClient.logLogin();
      }
      notifyListeners();
      return isLoggedIn;
    } catch (e) {
      errorMessage = 'Login failed: $e';
      notifyListeners();
      return false;
    }
  }
```

to:

```dart
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/providers/game_provider_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 6: Update `TestGameProvider` in `home_screen_test.dart` so the suite still compiles**

`test/screens/home_screen_test.dart` defines `class TestGameProvider extends ChangeNotifier implements GameProvider`, which must override every member of `GameProvider` - it will now fail to compile because `recentUsers`, `loadRecentUsers`, `signup`, `logout`, and `restoreSession` don't exist on it yet.

In `FlutterSpell_Game/test/screens/home_screen_test.dart`, find:

```dart
  @override
  bool isLoggedIn = false;
```

and change it to:

```dart
  @override
  bool isLoggedIn = false;

  @override
  List<String> recentUsers = [];
```

Then find:

```dart
  @override
  Future<bool> login(String password) async => true;
```

and add these three methods right after it:

```dart
  @override
  Future<bool> login(String password) async => true;

  @override
  Future<bool> signup({required String name, String? password, String? grade}) async => true;

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession(String userName) async {}

  @override
  Future<void> loadRecentUsers() async {}
```

- [ ] **Step 7: Run the full frontend test suite to confirm no new compile errors**

Run (from `FlutterSpell_Game/`): `flutter test test/screens/home_screen_test.dart`
Expected: compiles and runs (same pass/fail counts as before this task - this step is only checking for compile errors, not fixing pre-existing failures).

- [ ] **Step 8: Commit**

```bash
git add lib/providers/game_provider.dart test/providers/game_provider_test.dart test/screens/home_screen_test.dart
git commit -m "feat: add session persistence, signup, logout to GameProvider"
```

---

### Task 3: Shared test double for widget tests

**Files:**
- Create: `FlutterSpell_Game/test/support/fake_game_provider.dart`

- [ ] **Step 1: Create the fake**

Create `FlutterSpell_Game/test/support/fake_game_provider.dart`:

```dart
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

  @override
  Future<void> setSoundEnabled(bool enabled) async {}
}
```

- [ ] **Step 2: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze test/support/fake_game_provider.dart --no-fatal-infos`
Expected: no `error` lines. (An error here almost always means `GameProvider`'s public interface changed since Task 2 - cross-check every `@override` against the real class.)

- [ ] **Step 3: Commit**

```bash
git add test/support/fake_game_provider.dart
git commit -m "test: add shared FakeGameProvider test double"
```

---

### Task 4: `AccountAvatarButton` widget

**Files:**
- Create: `FlutterSpell_Game/lib/widgets/account_avatar_button.dart`
- Test: `FlutterSpell_Game/test/widgets/account_avatar_button_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/widgets/account_avatar_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: Scaffold(
          appBar: AppBar(actions: const [AccountAvatarButton()]),
        ),
      ),
      routes: {
        '/login': (context) => const Scaffold(body: Text('Login Screen')),
        '/profile': (context) => const Scaffold(body: Text('Profile Screen')),
      },
    );
  }

  testWidgets('logged out shows a sign-in icon that opens /login',
      (tester) async {
    final provider = FakeGameProvider();
    provider.isLoggedIn = false;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Login Screen'), findsOneWidget);
  });

  testWidgets('logged in shows the username initial', (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.text('E'), findsOneWidget);
  });

  testWidgets(
      'tapping the logged-in avatar shows View Profile and Switch User',
      (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pumpAndSettle();

    expect(find.text('View Profile'), findsOneWidget);
    expect(find.text('Switch User'), findsOneWidget);
  });

  testWidgets('Switch User logs out and navigates to /login', (tester) async {
    final provider = FakeGameProvider();
    provider.init('ERIC');
    provider.isLoggedIn = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch User'));
    await tester.pumpAndSettle();

    expect(provider.loggedOutCalled, true);
    expect(find.text('Login Screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widgets/account_avatar_button_test.dart`
Expected: FAIL to compile — `lib/widgets/account_avatar_button.dart` doesn't exist yet.

- [ ] **Step 3: Write the widget**

Create `FlutterSpell_Game/lib/widgets/account_avatar_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

/// Top-right account entry point, added to every screen's app bar except
/// mid-session screens (study, boss battle) and Profile itself. Logged
/// out: a plain sign-in icon that opens the login screen. Logged in: a
/// circle with the username's first letter that opens a small menu
/// (View Profile / Switch User).
class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({super.key});

  static const double _size = DuolingoSpacing.miniTouchTarget;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    if (!provider.isLoggedIn) {
      return Padding(
        padding: EdgeInsets.only(right: DuolingoSpacing.md),
        child: IconButton(
          icon: Container(
            width: _size,
            height: _size,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: DuolingoColors.neutralGray,
            ),
            child: const Icon(
              Icons.person_outline,
              color: DuolingoColors.bodyText,
            ),
          ),
          tooltip: 'Sign in',
          onPressed: () => Navigator.of(context).pushNamed('/login'),
        ),
      );
    }

    final initial =
        provider.userName.isNotEmpty ? provider.userName[0].toUpperCase() : '?';

    return Padding(
      padding: EdgeInsets.only(right: DuolingoSpacing.md),
      child: GestureDetector(
        onTap: () => _showAccountMenu(context),
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DuolingoColors.primaryGreen,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.backgroundWhite,
              fontSize: 18,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final selection = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'profile', child: Text('View Profile')),
        PopupMenuItem(value: 'switch', child: Text('Switch User')),
      ],
    );

    if (!context.mounted) return;
    if (selection == 'profile') {
      Navigator.of(context).pushNamed('/profile');
    } else if (selection == 'switch') {
      await context.read<GameProvider>().logout();
      if (!context.mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/account_avatar_button_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/account_avatar_button.dart test/widgets/account_avatar_button_test.dart
git commit -m "feat: add AccountAvatarButton widget"
```

---

### Task 5: `LoginScreen`

**Files:**
- Create: `FlutterSpell_Game/lib/screens/login_screen.dart`
- Test: `FlutterSpell_Game/test/screens/login_screen_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/screens/login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/login_screen.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const LoginScreen(),
      ),
      routes: {
        '/home': (context) => const Scaffold(body: Text('Home Screen')),
        '/signup': (context) => const Scaffold(body: Text('Signup Screen')),
      },
    );
  }

  testWidgets('shows quick-pick chips for recent users', (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC', 'HELLEN'];

    await tester.pumpWidget(wrap(provider));
    await tester.pump();

    expect(find.text('ERIC'), findsOneWidget);
    expect(find.text('HELLEN'), findsOneWidget);
  });

  testWidgets('manual entry toggle shows username and password fields',
      (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC'];

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('Not you? Use a different username'));
    await tester.pump();

    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
  });

  testWidgets('New here? Sign Up navigates to /signup', (tester) async {
    final provider = FakeGameProvider();

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('New here? Sign Up'));
    await tester.pumpAndSettle();

    expect(find.text('Signup Screen'), findsOneWidget);
  });

  testWidgets('correct login navigates to /home', (tester) async {
    final provider = FakeGameProvider();
    provider.loginResult = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), '123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('wrong password shows inline error and does not navigate',
      (tester) async {
    final provider = FakeGameProvider();
    provider.loginResult = false;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'wrong');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password'), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: FAIL to compile — `lib/screens/login_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the screen**

Create `FlutterSpell_Game/lib/screens/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedRecentUser;
  bool _useManualEntry = false;
  bool _isSubmitting = false;
  String? _errorText;

  final _usernameController = TextEditingController();
  final _manualPasswordController = TextEditingController();
  final _quickPickPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadRecentUsers();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _manualPasswordController.dispose();
    _quickPickPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(String name, String password) async {
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a username');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final provider = context.read<GameProvider>();
    provider.init(name);
    final ok = await provider.login(password);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      setState(() => _errorText = 'Incorrect username or password');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recentUsers = context.watch<GameProvider>().recentUsers;
    final showQuickPick = recentUsers.isNotEmpty && !_useManualEntry;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Log In', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showQuickPick) ...[
              Text("Who's playing?", style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              Wrap(
                spacing: DuolingoSpacing.lg,
                runSpacing: DuolingoSpacing.lg,
                children: recentUsers.map((name) {
                  final selected = _selectedRecentUser == name;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedRecentUser = name;
                      _errorText = null;
                    }),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? DuolingoColors.primaryGreen
                                : DuolingoColors.neutralGray,
                            border: selected
                                ? Border.all(
                                    color: DuolingoColors.primaryGreenLight,
                                    width: 3)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: DuolingoTextStyles.cardTitle.copyWith(
                              color: selected
                                  ? DuolingoColors.backgroundWhite
                                  : DuolingoColors.darkText,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        SizedBox(height: DuolingoSpacing.xs),
                        Text(name, style: DuolingoTextStyles.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (_selectedRecentUser != null) ...[
                SizedBox(height: DuolingoSpacing.xl),
                TextField(
                  controller: _quickPickPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password for $_selectedRecentUser',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                  ),
                  onSubmitted: (_) => _submit(
                    _selectedRecentUser!,
                    _quickPickPasswordController.text,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.lg),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submit(
                            _selectedRecentUser!,
                            _quickPickPasswordController.text,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.primaryGreen,
                    padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Log In'),
                ),
              ],
              SizedBox(height: DuolingoSpacing.lg),
              TextButton(
                onPressed: () => setState(() {
                  _useManualEntry = true;
                  _selectedRecentUser = null;
                  _errorText = null;
                }),
                child: const Text('Not you? Use a different username'),
              ),
            ] else ...[
              Text('Log In', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _manualPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
                onSubmitted: (_) => _submit(
                  _usernameController.text.trim(),
                  _manualPasswordController.text,
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(
                          _usernameController.text.trim(),
                          _manualPasswordController.text,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DuolingoColors.primaryGreen,
                  padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log In'),
              ),
              if (recentUsers.isNotEmpty) ...[
                SizedBox(height: DuolingoSpacing.lg),
                TextButton(
                  onPressed: () => setState(() {
                    _useManualEntry = false;
                    _errorText = null;
                  }),
                  child: const Text('Back to profile picker'),
                ),
              ],
            ],
            if (_errorText != null) ...[
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                _errorText!,
                style:
                    DuolingoTextStyles.body.copyWith(color: DuolingoColors.mistakeRed),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: DuolingoSpacing.xxl),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: const Text('New here? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/login_screen.dart test/screens/login_screen_test.dart
git commit -m "feat: add LoginScreen with quick-pick recent users"
```

---

### Task 6: `SignupScreen`

**Files:**
- Create: `FlutterSpell_Game/lib/screens/signup_screen.dart`
- Test: `FlutterSpell_Game/test/screens/signup_screen_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/screens/signup_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/signup_screen.dart';
import '../support/fake_game_provider.dart';

void main() {
  Widget wrap(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const SignupScreen(),
      ),
      routes: {
        '/home': (context) => const Scaffold(body: Text('Home Screen')),
      },
    );
  }

  testWidgets('successful signup navigates to /home', (tester) async {
    final provider = FakeGameProvider();
    provider.signupResult = true;

    await tester.pumpWidget(wrap(provider));
    await tester.enterText(
        find.widgetWithText(TextField, 'Username'), 'NEWKID');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(provider.signupCalled, true);
    expect(provider.lastSignupName, 'NEWKID');
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets('duplicate username shows inline error and does not navigate',
      (tester) async {
    final provider = FakeGameProvider();
    provider.signupResult = false;

    await tester.pumpWidget(wrap(provider));
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ERIC');
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    expect(find.text('That username is already taken'), findsOneWidget);
    expect(find.text('Home Screen'), findsNothing);
  });

  testWidgets('empty username shows validation error without calling signup',
      (tester) async {
    final provider = FakeGameProvider();

    await tester.pumpWidget(wrap(provider));
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(find.text('Enter a username'), findsOneWidget);
    expect(provider.signupCalled, false);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/screens/signup_screen_test.dart`
Expected: FAIL to compile — `lib/screens/signup_screen.dart` doesn't exist yet.

- [ ] **Step 3: Write the screen**

Create `FlutterSpell_Game/lib/screens/signup_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedGrade;
  bool _isSubmitting = false;
  String? _errorText;

  static const _grades = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a username');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final ok = await context.read<GameProvider>().signup(
          name: name,
          password:
              _passwordController.text.isEmpty ? null : _passwordController.text,
          grade: _selectedGrade,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      setState(() {
        _errorText =
            context.read<GameProvider>().errorMessage ?? 'Could not create account';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Sign Up', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'Grade (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedGrade = value),
            ),
            SizedBox(height: DuolingoSpacing.xl),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: DuolingoColors.primaryGreen,
                padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account'),
            ),
            if (_errorText != null) ...[
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                _errorText!,
                style:
                    DuolingoTextStyles.body.copyWith(color: DuolingoColors.mistakeRed),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/screens/signup_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/signup_screen.dart test/screens/signup_screen_test.dart
git commit -m "feat: add SignupScreen"
```

---

### Task 7: `AuthGate` and `main.dart` wiring

**Files:**
- Create: `FlutterSpell_Game/lib/screens/auth_gate.dart`
- Modify: `FlutterSpell_Game/lib/main.dart`
- Modify: `FlutterSpell_Game/test/widget_test.dart`

- [ ] **Step 1: Write `AuthGate`**

Create `FlutterSpell_Game/lib/screens/auth_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show gameProvider;
import 'home.dart';
import 'login_screen.dart';

/// Startup gate: silently restores a previously-persisted session (see
/// GameProvider.restoreSession) if one exists on this device, otherwise
/// shows the login screen. Replaces the old hardcoded-ERIC startup.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _restoredUser;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUser = prefs.getString('last_user');
    if (lastUser != null && lastUser.isNotEmpty) {
      gameProvider.init(lastUser);
      await gameProvider.restoreSession(lastUser);
      _restoredUser = lastUser;
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoredUser != null) {
      return HomeScreen(userName: _restoredUser!);
    }
    return const LoginScreen();
  }
}
```

- [ ] **Step 2: Wire it into `main.dart`**

In `FlutterSpell_Game/lib/main.dart`, add three imports alongside the existing screen imports:

```dart
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
```

Change:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  gameProvider.init('ERIC');
  // Login to backend (fire-and-forget; screens react via notifyListeners)
  gameProvider.login('123');
  runApp(const MyApp());
}
```

to:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}
```

Change:

```dart
        home: const HomeScreen(userName: 'ERIC'),
```

to:

```dart
        home: const AuthGate(),
```

Change:

```dart
            case '/':
            case '/home':
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(userName: 'ERIC'),
              );
```

to:

```dart
            case '/':
            case '/home':
              return MaterialPageRoute(
                builder: (context) => HomeScreen(userName: gameProvider.userName),
              );
            case '/login':
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            case '/signup':
              return MaterialPageRoute(
                builder: (context) => const SignupScreen(),
              );
```

- [ ] **Step 3: Update the smoke test**

In `FlutterSpell_Game/test/widget_test.dart`, change:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spell_game/main.dart';

void main() {
  testWidgets('Spell Adventure app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Verify that the app displays home screen UI
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spell_game/main.dart';

void main() {
  testWidgets('Spell Adventure app smoke test', (WidgetTester tester) async {
    // A persisted session means AuthGate goes straight to Home instead of
    // showing the login screen.
    SharedPreferences.setMockInitialValues({'last_user': 'ERIC'});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app displays home screen UI
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
```

- [ ] **Step 4: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/main.dart lib/screens/auth_gate.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 5: Run the smoke test**

Run: `flutter test test/widget_test.dart`
Expected: this test was already failing before this plan (pre-existing, unrelated to this feature - see the plan's testing note). This step is a sanity check, not a required pass - report the actual result rather than assuming.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/screens/auth_gate.dart test/widget_test.dart
git commit -m "feat: replace hardcoded-ERIC startup with AuthGate"
```

---

### Task 8: Wire `AccountAvatarButton` into 12 screens

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/home.dart`
- Modify: `FlutterSpell_Game/lib/screens/world_map_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/chinese_kingdom_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/english_castle_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/review_cave_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/treasure_island_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/boss_arena_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/backpack_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/progress_screen.dart`
- Modify: `FlutterSpell_Game/lib/screens/rewards_shop.dart`
- Modify: `FlutterSpell_Game/lib/screens/leaderboard.dart`
- Modify: `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`

Every file gets the same two changes: add `import '../widgets/account_avatar_button.dart';` right after the first import line, and add `actions: const [AccountAvatarButton()],` to the `AppBar(...)` call. No test for this task - it's a mechanical, visually-verified change (see Task 10's manual check).

- [ ] **Step 1: `home.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import '../design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        centerTitle: true,
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        centerTitle: true,
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 2: `world_map_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 3: `chinese_kingdom_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Chinese Kingdom', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Chinese Kingdom', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 4: `english_castle_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('English Kingdom', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('English Kingdom', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 5: `review_cave_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Review Cave', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Review Cave', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 6: `treasure_island_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import '../widgets/celebration.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import '../widgets/celebration.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: const Text('Treasure Island'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: const Text('Treasure Island'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 7: `boss_arena_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Boss Arena', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Boss Arena', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 8: `backpack_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Backpack', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Backpack', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 9: `progress_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: Text('Progress', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
```

to:

```dart
      appBar: AppBar(
        title: Text('Progress', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 10: `rewards_shop.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import 'package:provider/provider.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: const Text('Rewards Shop'),
        centerTitle: true,
      ),
```

to:

```dart
      appBar: AppBar(
        title: const Text('Rewards Shop'),
        centerTitle: true,
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 11: `leaderboard.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import 'package:provider/provider.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
        bottom: TabBar(
```

to:

```dart
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
        actions: const [AccountAvatarButton()],
        bottom: TabBar(
```

- [ ] **Step 12: `lesson_overview_screen.dart`**

Add the import - change:

```dart
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
```

to:

```dart
import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import '../design_system/design_system.dart';
```

Add the action - change:

```dart
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
```

to:

```dart
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
```

- [ ] **Step 13: Verify everything compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze --no-fatal-infos`
Expected: no `error` lines anywhere in the project. (If any of the exact old-string snippets above didn't match a file's current content because it drifted since this plan was written, re-check that file directly rather than skipping it.)

- [ ] **Step 14: Commit**

```bash
git add lib/screens/home.dart lib/screens/world_map_screen.dart lib/screens/chinese_kingdom_screen.dart lib/screens/english_castle_screen.dart lib/screens/review_cave_screen.dart lib/screens/treasure_island_screen.dart lib/screens/boss_arena_screen.dart lib/screens/backpack_screen.dart lib/screens/progress_screen.dart lib/screens/rewards_shop.dart lib/screens/leaderboard.dart lib/screens/lesson_overview_screen.dart
git commit -m "feat: add AccountAvatarButton to every main screen's app bar"
```

---

### Task 9: Fix Profile screen's broken Logout button

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/profile.dart`

- [ ] **Step 1: Fix `_showLogoutDialog`**

In `FlutterSpell_Game/lib/screens/profile.dart`, change:

```dart
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacementNamed('/');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
```

to:

```dart
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<GameProvider>().logout();
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
```

(`GameProvider` and `provider` are already imported in this file for the rest of the screen's `Consumer<GameProvider>` usage.)

- [ ] **Step 2: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/screens/profile.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/profile.dart
git commit -m "fix: make the Profile screen's Logout button actually log out"
```

---

### Task 10: Full verification, build, and manual test

**Files:** none (test/build/manual verification only)

- [ ] **Step 1: Run the full frontend test suite**

Run (from `FlutterSpell_Game/`): `flutter test`
Expected: all new tests from Tasks 2-6 pass (5 + 4 + 5 + 3 = 17 new tests). The known pre-existing failures (`home_screen_test.dart` and `widget_test.dart`, unrelated to this feature per the plan's testing note) may still fail - compare the failure count/names against a `git stash`-free baseline if unsure whether a failure is new.

- [ ] **Step 2: Full analyzer pass**

Run: `flutter analyze --no-fatal-infos`
Expected: no `error` lines anywhere in the project.

- [ ] **Step 3: Rebuild and redeploy the web app**

Run (from `FlutterSpell_Game/`): `flutter build web --release --dart-define=API_BASE_URL=<current backend LAN URL>` (check what's currently running - `netstat`/prior session context for the live IP:port).
Expected: `√ Built build\web`

- [ ] **Step 4: Manually verify - first-time login (no persisted session)**

In a private/incognito browser tab (so no `last_user` is persisted from a previous test), open the app. Confirm the Login screen appears (not Home). Confirm there's no quick-pick row if this browser has never logged in before, just the username/password form and "New here? Sign Up" link.

- [ ] **Step 5: Manually verify - signup**

Tap "New here? Sign Up". Create a new account (a throwaway test name, a password, pick a grade). Confirm it navigates to Home afterward, and the top-right circle shows that name's first letter.

- [ ] **Step 6: Manually verify - session persistence**

Refresh the page (or close and reopen the tab). Confirm it goes straight to Home as the same user, without showing the login screen again.

- [ ] **Step 7: Manually verify - Switch User**

Tap the top-right circle. Confirm the popup shows "View Profile" and "Switch User". Tap "Switch User". Confirm it navigates to the Login screen, and the account just used now appears as a quick-pick chip. Tap that chip, enter its password, confirm login succeeds and returns to Home.

- [ ] **Step 8: Manually verify - wrong password**

From the Login screen, try logging in with an intentionally wrong password (either via a quick-pick chip or manual entry). Confirm an inline "Incorrect username or password" error appears and the screen does not navigate away.

- [ ] **Step 9: Manually verify - Profile screen Logout**

Log in, navigate to Profile (via the circle's "View Profile" or the bottom nav), tap "Logout" at the bottom of the Profile screen, confirm the dialog, confirm it actually navigates to the Login screen (not back to the same Home as before).

- [ ] **Step 10: Manually verify - avatar button present across screens**

Visit World Map, both Kingdoms, Review Cave, Treasure Island, Boss Arena, Backpack, Progress, Rewards Shop, Leaderboard, and a Lesson Overview screen. Confirm the top-right circle appears on every one of them. Confirm it does NOT appear during an active Study session or Boss Battle.

- [ ] **Step 11: Report results**

Summarize what passed and what (if anything) didn't, with specifics (which step, what was observed) rather than a bare "it works."

---

## Self-Review Notes

- **Spec coverage:** Section A (session/data layer) - Tasks 1, 2, 7. Section B (Login screen) - Task 5. Section C (Signup screen) - Task 6. Section D (avatar button) - Tasks 4, 8. Section E (Profile logout fix) - Task 9. Testing section - Tasks 2, 3, 4, 5, 6 plus the honesty note about network-dependent paths not being unit-mocked, matching the codebase's existing (lack of) HTTP-mocking convention.
- **Placeholder scan:** no TBD/TODO; every code-bearing step shows complete before/after code, not descriptions.
- **Type consistency:** `GameProvider.signup({required String name, String? password, String? grade})` (Task 2) matches its call sites in `LoginScreen`/`SignupScreen` (Tasks 5-6) and its stub in `FakeGameProvider` (Task 3). `ApiClient.createUser({required String name, String? password, String? grade})` (Task 1) matches `GameProvider.signup`'s call to it (Task 2). `recentUsers` (field name, not a method) defined in Task 2 matches usage in `LoginScreen` (Task 5) and `FakeGameProvider` (Task 3). Route names (`/login`, `/signup`, `/home`, `/profile`) are consistent across `main.dart` (Task 7), `AccountAvatarButton` (Task 4), `LoginScreen`/`SignupScreen` (Tasks 5-6), and `profile.dart` (Task 9).
