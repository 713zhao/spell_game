# Avatar, Quick-Login & Kids-Style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a colorful, deterministic per-user avatar shown everywhere identity appears (account button, login quick-pick, profile), make tapping a recent user's avatar log them in immediately using a locally-saved password, and restyle Login/Signup/Profile to match the app's existing Duolingo-style visual language.

**Architecture:** A new pure `avatarColorFor(name)` util backs a new `UserAvatar` widget, which replaces the ad-hoc avatar-drawing code duplicated in `AccountAvatarButton`, the login screen's quick-pick chips, and Profile's header. `GameProvider` gains a `saved_passwords` `SharedPreferences` map (username → password) populated on every successful `login`/`signup`, a new `loginQuick(name)` that tries a saved password before falling back to manual entry, and eviction of passwords in lockstep with the existing 5-entry `recent_users` cap. Login and Signup screens are restyled in place using the app's established `DuolingoColors`/`DuolingoTextStyles`/`DuolingoSpacing` tokens and the same rounded/filled input style already used in `study.dart`.

**Tech Stack:** Flutter web, `provider` package, `shared_preferences`, `dart:convert` for the password map, existing Duolingo design system.

Spec: `docs/superpowers/specs/2026-07-19-avatar-quick-login-kids-style-design.md`

**Testing note:** Following this codebase's existing convention (established in the earlier login/signup plan), network-dependent paths (the real HTTP call inside `login()`/`signup()`) aren't unit-mocked. What's fully testable without network - the `avatarColorFor` color logic, `loginQuick`'s no-saved-password branch, and password eviction alongside `recent_users` trimming - gets real unit tests. `LoginScreen`'s quick-login UI behavior is covered by widget tests against the existing `FakeGameProvider` test double.

---

### Task 1: `avatarColorFor` pure util

**Files:**
- Create: `FlutterSpell_Game/lib/utils/avatar_color.dart`
- Test: `FlutterSpell_Game/test/utils/avatar_color_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/utils/avatar_color_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/avatar_color.dart';

void main() {
  group('avatarColorFor', () {
    test('the same name always returns the same color', () {
      expect(avatarColorFor('ERIC'), avatarColorFor('ERIC'));
    });

    test('different names can return different colors', () {
      // Not guaranteed for every possible pair, but true for this one -
      // if the palette or hash algorithm ever changes, pick a new pair
      // that differs.
      expect(avatarColorFor('ERIC') == avatarColorFor('HELLEN'), isFalse);
    });

    test('is case-insensitive - the same name in different case matches',
        () {
      expect(avatarColorFor('eric'), avatarColorFor('ERIC'));
    });

    test('an empty name does not throw', () {
      expect(() => avatarColorFor(''), returnsNormally);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `FlutterSpell_Game/`): `flutter test test/utils/avatar_color_test.dart`
Expected: FAIL to compile — `lib/utils/avatar_color.dart` doesn't exist yet.

- [ ] **Step 3: Write the util**

Create `FlutterSpell_Game/lib/utils/avatar_color.dart`:

```dart
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';

/// Bright, kid-friendly avatar colors. Red is deliberately excluded - it
/// already means "wrong answer" throughout the study screens.
const List<Color> avatarColorPalette = [
  DuolingoColors.primaryGreen,
  DuolingoColors.informationBlue,
  DuolingoColors.specialPurple,
  DuolingoColors.streakOrange,
  DuolingoColors.treasureGold,
  Color(0xFF00B8A9), // teal
];

/// Deterministically picks an avatar background color for [name] from
/// [avatarColorPalette], so the same username always gets the same color
/// everywhere it's shown (account button, login quick-pick, profile).
Color avatarColorFor(String name) {
  if (name.isEmpty) return DuolingoColors.neutralGray;
  final upper = name.toUpperCase();
  final hash = upper.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return avatarColorPalette[hash % avatarColorPalette.length];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/utils/avatar_color_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/utils/avatar_color.dart test/utils/avatar_color_test.dart
git commit -m "feat: add deterministic per-user avatar color util"
```

---

### Task 2: `UserAvatar` widget

**Files:**
- Create: `FlutterSpell_Game/lib/widgets/user_avatar.dart`
- Test: `FlutterSpell_Game/test/widgets/user_avatar_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

Create `FlutterSpell_Game/test/widgets/user_avatar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/widgets/user_avatar.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the uppercase first letter when no cosmetic is set',
      (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: 'eric')));

    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('shows the cosmetic emoji instead of the letter when provided',
      (tester) async {
    await tester.pumpWidget(
      wrap(const UserAvatar(name: 'ERIC', cosmeticEmoji: '🦄')),
    );

    expect(find.text('🦄'), findsOneWidget);
    expect(find.text('E'), findsNothing);
  });

  testWidgets('shows a fallback "?" for an empty name', (tester) async {
    await tester.pumpWidget(wrap(const UserAvatar(name: '')));

    expect(find.text('?'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `FlutterSpell_Game/`): `flutter test test/widgets/user_avatar_test.dart`
Expected: FAIL to compile — `lib/widgets/user_avatar.dart` doesn't exist yet.

- [ ] **Step 3: Write the widget**

Create `FlutterSpell_Game/lib/widgets/user_avatar.dart`:

```dart
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../utils/avatar_color.dart';

/// A colorful circular avatar shown wherever a user's identity appears
/// (top-right account button, login quick-pick, profile header). The
/// background color is deterministic per username (see [avatarColorFor]),
/// so the same person always gets the same color everywhere. Shows
/// [cosmeticEmoji] instead of the initial letter when one is equipped.
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? cosmeticEmoji;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.cosmeticEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = cosmeticEmoji;
    final showEmoji = emoji != null && emoji.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarColorFor(name),
      ),
      alignment: Alignment.center,
      child: Text(
        showEmoji ? emoji : (name.isNotEmpty ? name[0].toUpperCase() : '?'),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.bold,
          color: DuolingoColors.backgroundWhite,
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widgets/user_avatar_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/user_avatar.dart test/widgets/user_avatar_test.dart
git commit -m "feat: add UserAvatar widget"
```

---

### Task 3: `AccountAvatarButton` uses `UserAvatar`

**Files:**
- Modify: `FlutterSpell_Game/lib/widgets/account_avatar_button.dart`

No test changes needed - `test/widgets/account_avatar_button_test.dart`'s existing 4 tests already assert `find.text('E')` for a logged-in `ERIC`, which still holds true with `UserAvatar` (no `cosmeticEmoji` is passed here, so it falls back to the initial letter exactly as the old inline code did).

- [ ] **Step 1: Replace the avatar-drawing code with `UserAvatar`**

In `FlutterSpell_Game/lib/widgets/account_avatar_button.dart`, replace the entire file content with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import 'user_avatar.dart';

/// Top-right account entry point, added to every screen's app bar except
/// mid-session screens (study, boss battle) and Profile itself. Logged
/// out: a plain sign-in icon that opens the login screen. Logged in: a
/// colorful avatar (see UserAvatar) that opens a small menu (View Profile
/// / Switch User).
class AccountAvatarButton extends StatelessWidget {
  const AccountAvatarButton({super.key});

  static const double _size = DuolingoSpacing.miniTouchTarget;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

    return Padding(
      padding: EdgeInsets.only(right: DuolingoSpacing.md),
      child: provider.isLoggedIn
          ? _buildLoggedInCircle(context, provider)
          : _buildLoggedOutButton(context),
    );
  }

  Widget _buildLoggedOutButton(BuildContext context) {
    return IconButton(
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
    );
  }

  Widget _buildLoggedInCircle(BuildContext context, GameProvider provider) {
    return GestureDetector(
      onTap: () => _showAccountMenu(context),
      child: UserAvatar(name: provider.userName, size: _size),
    );
  }

  Future<void> _showAccountMenu(BuildContext context) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final box = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset(0, box.size.height), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final selection = await showMenu<String>(
      context: context,
      position: position,
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

- [ ] **Step 2: Run the existing tests to confirm nothing broke**

Run (from `FlutterSpell_Game/`): `flutter test test/widgets/account_avatar_button_test.dart`
Expected: PASS (4 tests, unchanged)

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/widgets/account_avatar_button.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/account_avatar_button.dart
git commit -m "refactor: AccountAvatarButton uses the shared UserAvatar widget"
```

---

### Task 4: `GameProvider` — saved passwords and quick login

**Files:**
- Modify: `FlutterSpell_Game/lib/providers/game_provider.dart`
- Modify: `FlutterSpell_Game/test/support/fake_game_provider.dart`
- Modify: `FlutterSpell_Game/test/screens/home_screen_test.dart` (its `TestGameProvider` fake)
- Modify: `FlutterSpell_Game/test/providers/game_provider_test.dart`

- [ ] **Step 1: Write the failing tests**

In `FlutterSpell_Game/test/providers/game_provider_test.dart`, add `import 'dart:convert';` right after the existing `import 'package:flutter_test/flutter_test.dart';` line, then add these two tests inside the existing `group('GameProvider session management', () { ... })` block (anywhere among the existing tests - e.g. right before the closing `});` of the group):

```dart
    test('loginQuick returns false and does not touch identity when there is no saved password',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GameProvider();
      provider.init('ERIC');

      final result = await provider.loginQuick('HELLEN');

      expect(result, false);
      expect(provider.userName, 'ERIC');
    });

    test('recent-user eviction also removes the evicted name\'s saved password',
        () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['A', 'B', 'C', 'D', 'E'],
        'saved_passwords': '{"A":"pwA","B":"pwB","C":"pwC","D":"pwD","E":"pwE"}',
      });
      final provider = GameProvider();
      provider.init('F');

      await provider.restoreSession('F');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_users'), ['F', 'A', 'B', 'C', 'D']);
      final saved =
          jsonDecode(prefs.getString('saved_passwords')!) as Map<String, dynamic>;
      expect(saved.containsKey('E'), false);
      expect(saved.containsKey('A'), true);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run (from `FlutterSpell_Game/`): `flutter test test/providers/game_provider_test.dart`
Expected: FAIL to compile — `loginQuick` doesn't exist on `GameProvider` yet.

- [ ] **Step 3: Add `dart:convert` import**

In `FlutterSpell_Game/lib/providers/game_provider.dart`, change the top imports from:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
```

to:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
```

- [ ] **Step 4: Add password storage helpers and wire them into `login`/`signup`/`_addRecentUser`**

In `FlutterSpell_Game/lib/providers/game_provider.dart`, change the existing `login()` method from:

```dart
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
```

to:

```dart
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
```

Change `_addRecentUser` from:

```dart
  Future<void> _addRecentUser(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('recent_users') ?? [];
    existing.remove(name);
    existing.insert(0, name);
    final trimmed = existing.take(5).toList();
    await prefs.setStringList('recent_users', trimmed);
    recentUsers = trimmed;
  }
```

to:

```dart
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
```

Change `signup()` from:

```dart
  Future<bool> signup({
    required String name,
    String? password,
    String? grade,
  }) async {
    try {
      await ApiClient(userName: name)
          .createUser(name: name, password: password, grade: grade);
      init(name);
      await _onAuthenticated(name);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
```

to:

```dart
  Future<bool> signup({
    required String name,
    String? password,
    String? grade,
  }) async {
    try {
      await ApiClient(userName: name)
          .createUser(name: name, password: password, grade: grade);
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/providers/game_provider_test.dart`
Expected: PASS (8 tests: the 6 from before this plan plus the 2 new ones - the 1 known pre-existing `audioplayers`-related failure noted in the earlier login/signup plan is unrelated and unaffected).

- [ ] **Step 6: Update `FakeGameProvider`**

In `FlutterSpell_Game/test/support/fake_game_provider.dart`, find:

```dart
  bool loginAsGuestCalled = false;

  @override
  Future<void> loginAsGuest() async {
    loginAsGuestCalled = true;
    _userName = 'GUEST';
    isLoggedIn = false;
    notifyListeners();
  }
```

and add the following right after it:

```dart
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
```

- [ ] **Step 7: Update `TestGameProvider` in `home_screen_test.dart`**

In `FlutterSpell_Game/test/screens/home_screen_test.dart`, find:

```dart
  @override
  Future<void> loginAsGuest() async {}
```

and add right after it:

```dart
  @override
  Future<bool> loginQuick(String name) async => false;
```

- [ ] **Step 8: Verify everything compiles and the wider suite still passes**

Run: `flutter analyze lib/providers/game_provider.dart test/support/fake_game_provider.dart test/screens/home_screen_test.dart --no-fatal-infos`
Expected: no `error` lines.

Run: `flutter test test/support test/screens/home_screen_test.dart`
Expected: compiles; `home_screen_test.dart`'s pass/fail counts unchanged from before this task (2 pass / 6 fail is the known pre-existing baseline).

- [ ] **Step 9: Commit**

```bash
git add lib/providers/game_provider.dart test/providers/game_provider_test.dart test/support/fake_game_provider.dart test/screens/home_screen_test.dart
git commit -m "feat: save passwords locally and add GameProvider.loginQuick"
```

---

### Task 5: `LoginScreen` restyle and quick-login wiring

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/login_screen.dart`
- Modify: `FlutterSpell_Game/test/screens/login_screen_test.dart` (add 2 new tests; the existing 5 are unaffected and stay as-is)

- [ ] **Step 1: Write the two new failing tests**

In `FlutterSpell_Game/test/screens/login_screen_test.dart`, add these two tests inside `void main() { ... }`, anywhere among the existing `testWidgets` calls (e.g. right before the final closing `}` of `main`):

```dart
  testWidgets(
      'tapping a quick-pick avatar with a saved password logs in immediately',
      (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC'];
    provider.loginQuickResult = true;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('ERIC'));
    await tester.pumpAndSettle();

    expect(provider.loginQuickCalled, true);
    expect(provider.lastLoginQuickName, 'ERIC');
    expect(find.text('Home Screen'), findsOneWidget);
  });

  testWidgets(
      'tapping a quick-pick avatar with no saved password falls back to a password field',
      (tester) async {
    final provider = FakeGameProvider();
    provider.recentUsers = ['ERIC'];
    provider.loginQuickResult = false;

    await tester.pumpWidget(wrap(provider));
    await tester.pump();
    await tester.tap(find.text('ERIC'));
    await tester.pumpAndSettle();

    expect(provider.loginQuickCalled, true);
    expect(find.text('Home Screen'), findsNothing);
    expect(find.widgetWithText(TextField, 'Password for ERIC'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify the two new ones fail**

Run (from `FlutterSpell_Game/`): `flutter test test/screens/login_screen_test.dart`
Expected: the 5 existing tests still PASS; the 2 new ones FAIL (tapping the avatar currently only selects it and shows a password field immediately - `loginQuickCalled` never becomes true, and today's UI shows the password field regardless of a "saved password" concept that doesn't exist yet).

- [ ] **Step 3: Restyle the screen and wire quick-login**

Replace the entire content of `FlutterSpell_Game/lib/screens/login_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/user_avatar.dart';

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

  /// Tapping a quick-pick avatar tries to log in immediately using a
  /// locally-saved password (see GameProvider.loginQuick). If there's no
  /// saved password, or it's stale, this falls back to showing a
  /// password field for that user instead of a dead end.
  Future<void> _quickLogin(String name) async {
    setState(() {
      _selectedRecentUser = name;
      _isSubmitting = true;
      _errorText = null;
    });
    final ok = await context.read<GameProvider>().loginQuick(name);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: DuolingoColors.neutralGray,
      contentPadding: EdgeInsets.all(DuolingoSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide:
            const BorderSide(color: DuolingoColors.informationBlue, width: 2),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: DuolingoColors.primaryGreen,
        padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        ),
        elevation: 0,
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: DuolingoTextStyles.cardTitle.copyWith(color: Colors.white),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recentUsers = context.watch<GameProvider>().recentUsers;
    final showQuickPick = recentUsers.isNotEmpty && !_useManualEntry;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('🐕', style: TextStyle(fontSize: 64))),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              'Welcome Back!',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.pageTitle,
            ),
            SizedBox(height: DuolingoSpacing.xxl),
            if (showQuickPick) ...[
              Text("Who's playing?", style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              Wrap(
                spacing: DuolingoSpacing.lg,
                runSpacing: DuolingoSpacing.lg,
                children: recentUsers.map((name) {
                  final selected = _selectedRecentUser == name;
                  return GestureDetector(
                    onTap: () => _quickLogin(name),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: DuolingoColors.primaryGreen, width: 3)
                                : null,
                            boxShadow: DuolingoShadows.cardShadow,
                          ),
                          child: UserAvatar(name: name, size: 64),
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
                Text(
                  'Enter your password to continue',
                  style: DuolingoTextStyles.body,
                ),
                SizedBox(height: DuolingoSpacing.sm),
                TextField(
                  controller: _quickPickPasswordController,
                  obscureText: true,
                  decoration: _inputDecoration('Password for $_selectedRecentUser'),
                  onSubmitted: (_) => _submit(
                    _selectedRecentUser!,
                    _quickPickPasswordController.text,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.lg),
                _primaryButton(
                  label: 'Log In',
                  onPressed: _isSubmitting
                      ? null
                      : () => _submit(
                            _selectedRecentUser!,
                            _quickPickPasswordController.text,
                          ),
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
              Text('Enter your details', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration('Username'),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _manualPasswordController,
                obscureText: true,
                decoration: _inputDecoration('Password'),
                onSubmitted: (_) => _submit(
                  _usernameController.text.trim(),
                  _manualPasswordController.text,
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              _primaryButton(
                label: 'Log In',
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(
                          _usernameController.text.trim(),
                          _manualPasswordController.text,
                        ),
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
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/signup'),
                child: Text(
                  'New here? Sign Up',
                  style: DuolingoTextStyles.cardTitle
                      .copyWith(color: DuolingoColors.informationBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify everything passes**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS (7 tests - the 5 original plus the 2 new quick-login ones)

- [ ] **Step 5: Verify it compiles**

Run: `flutter analyze lib/screens/login_screen.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/login_screen.dart test/screens/login_screen_test.dart
git commit -m "feat: restyle LoginScreen and wire avatar-tap quick login"
```

---

### Task 6: `SignupScreen` restyle

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/signup_screen.dart`

No test changes needed - `test/screens/signup_screen_test.dart`'s existing 3 tests only interact with the username field, password field, and "Create Account" button, none of which change identity or behavior here (only the grade picker's widget type and general visual styling change).

- [ ] **Step 1: Restyle the screen**

Replace the entire content of `FlutterSpell_Game/lib/screens/signup_screen.dart` with:

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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: DuolingoColors.neutralGray,
      contentPadding: EdgeInsets.all(DuolingoSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide:
            const BorderSide(color: DuolingoColors.informationBlue, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('🎒', style: TextStyle(fontSize: 64))),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              'Create Your Account',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.pageTitle,
            ),
            SizedBox(height: DuolingoSpacing.xxl),
            TextField(
              controller: _usernameController,
              decoration: _inputDecoration('Username'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration('Password (optional)'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            Text('Grade (optional)', style: DuolingoTextStyles.sectionTitle),
            SizedBox(height: DuolingoSpacing.sm),
            Wrap(
              spacing: DuolingoSpacing.sm,
              runSpacing: DuolingoSpacing.sm,
              children: _grades.map((grade) {
                final selected = _selectedGrade == grade;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedGrade = selected ? null : grade,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DuolingoSpacing.lg,
                      vertical: DuolingoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? DuolingoColors.primaryGreen
                          : DuolingoColors.neutralGray,
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    child: Text(
                      grade,
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: selected
                            ? DuolingoColors.backgroundWhite
                            : DuolingoColors.darkText,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Create Account',
                      style:
                          DuolingoTextStyles.cardTitle.copyWith(color: Colors.white),
                    ),
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

- [ ] **Step 2: Run tests to verify nothing broke**

Run (from `FlutterSpell_Game/`): `flutter test test/screens/signup_screen_test.dart`
Expected: PASS (3 tests, unchanged)

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/screens/signup_screen.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/signup_screen.dart
git commit -m "feat: restyle SignupScreen with tappable grade chips"
```

---

### Task 7: `ProfileScreen` avatar

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/profile.dart`

No test file exists for `ProfileScreen` currently, so no test changes.

- [ ] **Step 1: Add the import**

In `FlutterSpell_Game/lib/screens/profile.dart`, find the top imports (they include `import '../services/sound_service.dart';` as the last one) and add this import right after it:

```dart
import '../widgets/user_avatar.dart';
```

- [ ] **Step 2: Swap the header avatar**

In `FlutterSpell_Game/lib/screens/profile.dart`, find:

```dart
                          // Avatar/Cosmetic Display
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                stats?.equippedCosmetic ?? '👤',
                                style: const TextStyle(fontSize: 50),
                              ),
                            ),
                          ),
```

and change it to:

```dart
                          // Avatar
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: UserAvatar(
                              name: username,
                              size: 80,
                              cosmeticEmoji: stats?.equippedCosmetic,
                            ),
                          ),
```

(`username` is already defined earlier in this `build` method as `final username = stats?.username ?? 'Player';` - no new variable needed.)

- [ ] **Step 3: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/screens/profile.dart --no-fatal-infos`
Expected: no `error` lines.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/profile.dart
git commit -m "feat: show UserAvatar on the Profile screen header"
```

---

### Task 8: Full verification, build, and manual test

**Files:** none (test/build/manual verification only)

- [ ] **Step 1: Run the full frontend test suite**

Run (from `FlutterSpell_Game/`): `flutter test`
Expected: all new tests from Tasks 1-6 pass (4 + 3 + 2 + 2 = 11 new tests, plus Task 3's 4 existing avatar-button tests and Task 6's 3 existing signup tests confirmed unaffected). The known pre-existing failures (1 in `game_provider_test.dart`, 6 in `home_screen_test.dart`) are unrelated to this plan - compare the failure count/names against what they were before this plan if unsure.

- [ ] **Step 2: Full analyzer pass**

Run: `flutter analyze --no-fatal-infos`
Expected: no `error` lines anywhere in the project.

- [ ] **Step 3: Rebuild and redeploy the web app**

Run (from `FlutterSpell_Game/`): `flutter build web --release --dart-define=API_BASE_URL=<current backend LAN URL>` (check what's currently running - the IP has changed several times this session, verify with `curl` or `ipconfig` first).
Expected: `√ Built build\web`

- [ ] **Step 4: Manually verify - avatars are colorful and consistent**

Log in as two different users (e.g. ERIC and HELLEN). Confirm each gets their own distinct, consistent color on: the top-right account button, the login screen's quick-pick chips, and the Profile screen header. Confirm the same user always shows the same color across all three places and across repeated logins.

- [ ] **Step 5: Manually verify - quick login**

Log in as a user with a real password (entering it manually the first time). Switch User (or log out), and confirm that user's avatar now appears in the quick-pick list. Tap it - confirm it logs in immediately with **no password prompt** and lands on Home. Then simulate a stale password (e.g. via the backend admin panel, change that user's password), tap the same avatar again, and confirm it falls back to showing a password field with "Enter your password to continue" rather than silently failing or crashing.

- [ ] **Step 6: Manually verify - kids-style visuals**

Visit Login, Signup, and Profile. Confirm they visually match the rest of the app (rounded buttons, colorful accents, filled input fields) rather than looking like plain default Material forms. On Signup, confirm the grade picker is a row of tappable chips (not a dropdown) and that tapping one selects it (green) and tapping it again deselects it.

- [ ] **Step 7: Confirm no regressions**

Run through Home, both Kingdoms, and a full study session once to confirm nothing about the surrounding app broke.

- [ ] **Step 8: Report results**

Summarize what passed and what (if anything) didn't, with specifics (which screen/user was used, what was observed) rather than a bare "it works."

---

## Self-Review Notes

- **Spec coverage:** Section A (shared `UserAvatar`) - Tasks 1, 2, 3, 7. Section B (quick login) - Task 4. Section C (Login restyle) - Task 5. Section D (Signup restyle) - Task 6. Section E (Profile avatar) - Task 7. Testing section - Tasks 1, 2, 4, 5 cover exactly what the spec calls out as unit/widget-testable; the network-dependent password-saving-on-real-login path is explicitly left untested, consistent with the spec's stated convention.
- **Placeholder scan:** no TBD/TODO; every code step shows complete before/after code.
- **Type consistency:** `avatarColorFor(String name) -> Color` (Task 1) is used identically by `UserAvatar` (Task 2). `UserAvatar({required String name, double size = 56, String? cosmeticEmoji})` (Task 2) is constructed identically in `AccountAvatarButton` (Task 3, no `cosmeticEmoji`), `LoginScreen` (Task 5, no `cosmeticEmoji`, `size: 64`), and `ProfileScreen` (Task 7, `size: 80`, `cosmeticEmoji: stats?.equippedCosmetic`). `GameProvider.loginQuick(String name) -> Future<bool>` (Task 4) matches its call site in `LoginScreen._quickLogin` (Task 5) and its stub in `FakeGameProvider`/`TestGameProvider` (Task 4). `saved_passwords` key name and JSON shape (`Map<String, String>`) are used consistently across `_savePassword`/`_getSavedPassword`/`_readSavedPasswords`/`_addRecentUser`'s eviction logic (all in Task 4).
