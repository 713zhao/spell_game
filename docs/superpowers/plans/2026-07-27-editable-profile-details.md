# Editable Profile Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an editable "Profile Details" card (age, grade, school, email, phone, password) to FlutterSpell_Game's Profile tab, gated behind the existing Parent Mode toggle.

**Architecture:** Two new thin `ApiClient` methods call the backend's existing `GET`/`PUT /users/{name}/profile` endpoints. Two new pass-through `GameProvider` methods (mirroring the existing `loadUserStats`/`redeemUnlockable` pattern) expose them to the UI. `ProfileScreen` gets a new stateful section: read-only by default, switching to a `TextField` form when Parent Mode is on and Edit is tapped, with local validation before calling the provider.

**Tech Stack:** Flutter/Dart, `provider` package for state, `package:http` for network calls — no new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-26-editable-profile-details-design.md`

---

## Important context for whoever implements this

- Working directory for all steps below: `C:\ZJB\archive\spell\FlutterSpell_Game`
- Run tests with `flutter test`, analyze with `flutter analyze`, both from that directory.
- `GameProvider` is a concrete class (not abstract), but two test files do `implements GameProvider`, which requires them to override *every* public member. **Any new public field/method added to `GameProvider` in Task 2 must be mirrored in both `test/support/fake_game_provider.dart` and the `TestGameProvider` class embedded in `test/screens/home_screen_test.dart`, or the whole test suite fails to compile.** Task 3 handles this.
- The backend's `PUT /users/{name}/profile` (`SpellBackend/src/services/user_manager.py:42-57`) uppercases `name`, `school`, `grade`, and `email` if provided (pre-existing behavior, out of scope to change) — so a saved email like `foo@bar.com` comes back as `FOO@BAR.COM`. This is expected, not a bug to chase.
- Neither `ApiClient` nor the structurally-identical existing `GameProvider` methods (`loadUserStats`, `redeemUnlockable`, etc.) have dedicated unit tests anywhere in this repo — `ApiClient` calls the `http` package's top-level functions directly (not an injected/mockable client), and this codebase's established seam for testing this layer is a widget test against `ProfileScreen` using the `FakeGameProvider` test double. Tasks 1 and 2 follow that existing convention (verified via `flutter analyze` only); Task 4 onward is where real behavioral coverage comes from.

---

### Task 1: Add profile GET/PUT to ApiClient

**Files:**
- Modify: `lib/services/api_client.dart`

- [ ] **Step 1: Add the two methods**

Add this right after the existing `createUser` method (after the closing `}` on what is currently line 53, before the `getDeckCards` doc comment):

```dart
  /// Fetch the full account profile (age, grade, school, email, phone) -
  /// separate from [getUserStats], which only has game-relevant fields.
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/profile'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Invalid response format from getUserProfile');
    }
    throw Exception('Failed to load profile');
  }

  /// Update account profile fields. Only include keys that should change -
  /// the backend leaves omitted fields untouched.
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/$userName/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      String detail = 'Failed to update profile';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }

```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/services/api_client.dart`
Expected: no errors (pre-existing lint infos, if any, are fine).

- [ ] **Step 3: Commit**

```bash
git add lib/services/api_client.dart
git commit -m "feat: add profile GET/PUT to ApiClient"
```

---

### Task 2: Add profile load/update to GameProvider

**Files:**
- Modify: `lib/providers/game_provider.dart`

- [ ] **Step 1: Add the `userProfile` field**

Add this new field right after `UserStats? userStats;` (currently line 25):

```dart
  UserStats? userStats;
  Map<String, dynamic>? userProfile;
```

- [ ] **Step 2: Add the two methods**

Add this right after the existing `loadUserStats` method (after its closing `}`, currently ending at line 337, before `loadUnlockables`):

```dart
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

```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze lib/providers/game_provider.dart`
Expected: new errors only in files that `implements GameProvider` (handled in Task 3) - `game_provider.dart` itself should have no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/providers/game_provider.dart
git commit -m "feat: add profile load/update to GameProvider"
```

---

### Task 3: Keep the GameProvider test doubles compiling

**Files:**
- Modify: `test/support/fake_game_provider.dart`
- Modify: `test/screens/home_screen_test.dart`

- [ ] **Step 1: Confirm the break**

Run: `flutter test`
Expected: compile errors in both files above, e.g. `Missing concrete implementations of 'GameProvider.userProfile', 'GameProvider.loadUserProfile', 'GameProvider.updateProfile'`.

- [ ] **Step 2: Add overrides to `FakeGameProvider`**

In `test/support/fake_game_provider.dart`, add this field right after `UserStats? userStats;` (currently line 43):

```dart
  @override
  UserStats? userStats;

  @override
  Map<String, dynamic>? userProfile;
```

Then add test hooks and method overrides at the end of the class, right before the final `Future<void> setSoundEnabled(bool enabled) async {}` override (currently lines 199-200), so the class still ends with that method:

```dart
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
```

(Note: `errorMessage` is already a plain mutable field on this class per its existing `@override String? errorMessage;` declaration - no getter/setter override needed.)

- [ ] **Step 3: Add no-op overrides to `TestGameProvider` in `home_screen_test.dart`**

In `test/screens/home_screen_test.dart`, add this field right after `UserStats? userStats;` (currently line 42):

```dart
  @override
  UserStats? userStats;

  @override
  Map<String, dynamic>? userProfile;
```

Then add these two method overrides right after the existing `loadUserStats` override (currently lines 111-112), before `loadUnlockables`:

```dart
  @override
  Future<void> loadUserStats() async {}

  @override
  Future<void> loadUserProfile() async {}

  @override
  Future<bool> updateProfile(Map<String, dynamic> data) async => true;

```

- [ ] **Step 4: Verify the suite compiles and passes**

Run: `flutter test`
Expected: all previously-passing tests pass again (no compile errors).

- [ ] **Step 5: Commit**

```bash
git add test/support/fake_game_provider.dart test/screens/home_screen_test.dart
git commit -m "test: add GameProvider profile members to test doubles"
```

---

### Task 4: Read-only Profile Details card

**Files:**
- Modify: `lib/screens/profile.dart`
- Test: `test/screens/profile_screen_test.dart` (create)

- [ ] **Step 1: Write the failing test**

Create `test/screens/profile_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/screens/profile.dart';
import '../support/fake_game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(GameProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<GameProvider>.value(
        value: provider,
        child: const ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen Profile Details card', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows em-dashes when profile has not loaded yet',
        (tester) async {
      final provider = FakeGameProvider();
      provider.userProfile = null;

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Profile Details'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(5)); // age, grade, school, email, phone
    });

    testWidgets('shows profile values when loaded', (tester) async {
      final provider = FakeGameProvider();
      provider.userProfile = {
        'age': 6,
        'grade': 'P1',
        'school': 'SJIJ',
        'email': '',
        'phone': '87654321',
      };

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('6'), findsOneWidget);
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('SJIJ'), findsOneWidget);
      expect(find.text('87654321'), findsOneWidget);
      expect(find.text('—'), findsOneWidget); // empty email
    });
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: FAIL - `find.text('Profile Details')` finds nothing (the section doesn't exist yet).

- [ ] **Step 3: Add the read-only card to `profile.dart`**

Add this helper method to `_ProfileScreenState`, right after `_showLogoutDialog` (after its closing `}`, currently ending at line 108, before the `_calculateLevel` helper):

```dart
  Widget _buildProfileDetailsRow(String label, dynamic value) {
    final display =
        (value == null || value.toString().trim().isEmpty) ? '—' : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  Widget _buildProfileDetailsCard(GameProvider provider) {
    final profile = provider.userProfile;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileDetailsRow('Age', profile?['age']),
                  _buildProfileDetailsRow('Grade', profile?['grade']),
                  _buildProfileDetailsRow('School', profile?['school']),
                  _buildProfileDetailsRow('Email', profile?['email']),
                  _buildProfileDetailsRow('Phone', profile?['phone']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Wire it into `build()`**

In the `build()` method's `CustomScrollView`, insert a new sliver right after the header `SliverAppBar` closes (currently ending at line 206 with `),`) and before the `// Stats Grid Section` comment (currently line 208):

```dart
                // Profile Details Section
                SliverToBoxAdapter(
                  child: _buildProfileDetailsCard(provider),
                ),

                // Stats Grid Section
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/profile.dart test/screens/profile_screen_test.dart
git commit -m "feat: show read-only profile details card on Profile tab"
```

---

### Task 5: Load the profile on screen open

**Files:**
- Modify: `lib/screens/profile.dart`
- Test: `test/screens/profile_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the `group` in `test/screens/profile_screen_test.dart`:

```dart
    testWidgets('loads the profile when the screen opens', (tester) async {
      final provider = FakeGameProvider();

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      expect(provider.loadUserProfileCalled, true);
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: FAIL - `provider.loadUserProfileCalled` is `false`.

- [ ] **Step 3: Call it from `_loadProfileData`**

In `_loadProfileData()` (currently lines 42-49), add the call alongside the existing two:

```dart
  void _loadProfileData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GameProvider>();
      provider.loadUserStats();
      provider.loadUnlockables();
      provider.loadUserProfile();
    });
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile.dart test/screens/profile_screen_test.dart
git commit -m "feat: load profile details when the Profile tab opens"
```

---

### Task 6: Edit button gated by Parent Mode

**Files:**
- Modify: `lib/screens/profile.dart`
- Test: `test/screens/profile_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the `group`:

```dart
    testWidgets('Edit is blocked with a message when Parent Mode is off',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': false});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      expect(
        find.text('Enable Parent Mode in Settings to edit profile details.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Edit opens the form when Parent Mode is on', (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      expect(find.widgetWithText(TextField, 'Age'), findsOneWidget);
    });
```

- [ ] **Step 2: Run to verify both fail**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: FAIL - there's no "Edit" text/button yet.

- [ ] **Step 3: Add the Edit button and gating**

Add this state field to `_ProfileScreenState`, right after `bool _parentMode = false;` (currently line 23):

```dart
  bool _parentMode = false;
  bool _editingProfileDetails = false;
```

Add this method right after `_updateParentModeSetting` (after its closing `}`, currently ending at line 67, before `_equipCosmetic`):

```dart
  void _onEditProfileDetailsPressed() {
    if (!_parentMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable Parent Mode in Settings to edit profile details.'),
        ),
      );
      return;
    }
    setState(() => _editingProfileDetails = true);
  }
```

Update `_buildProfileDetailsCard` (from Task 4) to add the Edit button next to the title:

```dart
  Widget _buildProfileDetailsCard(GameProvider provider) {
    final profile = provider.userProfile;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile Details', style: Theme.of(context).textTheme.titleLarge),
              if (!_editingProfileDetails)
                TextButton.icon(
                  onPressed: _onEditProfileDetailsPressed,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileDetailsRow('Age', profile?['age']),
                  _buildProfileDetailsRow('Grade', profile?['grade']),
                  _buildProfileDetailsRow('School', profile?['school']),
                  _buildProfileDetailsRow('Email', profile?['email']),
                  _buildProfileDetailsRow('Phone', profile?['phone']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run to verify both pass**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: PASS (5 tests). Note: the second test only checks the form *opens*; it'll still show the read-only rows too until Task 7 makes the card actually switch views - that's fine, `findsOneWidget` for the Age `TextField` still passes once Step 3 below (Task 7) exists. If Task 7 hasn't landed yet in your working copy, this specific assertion will fail until then - that's expected and resolved by Task 7's step 3.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile.dart test/screens/profile_screen_test.dart
git commit -m "feat: gate profile-details editing behind Parent Mode"
```

---

### Task 7: Edit form with Cancel

**Files:**
- Modify: `lib/screens/profile.dart`
- Test: `test/screens/profile_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the `group`:

```dart
    testWidgets('Cancel discards changes and returns to read-only view',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '99');
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('6'), findsOneWidget); // original value still shown
      expect(provider.updateProfileCalled, false);
    });
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: FAIL - there's no Cancel button / edit form yet, so `find.widgetWithText(TextField, 'Age')` throws.

- [ ] **Step 3: Add the edit form**

Add these `TextEditingController` fields to `_ProfileScreenState`, right after `_editingProfileDetails` (added in Task 6):

```dart
  bool _editingProfileDetails = false;
  final _ageController = TextEditingController();
  final _gradeController = TextEditingController();
  final _schoolController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _ageError;
  String? _passwordError;
  bool _savingProfileDetails = false;
```

Add a `dispose()` override - this class doesn't have one yet, so add it right after `_loadProfileData` (after its closing `}`, currently ending at line 49, before `_updateSoundSetting`):

```dart
  @override
  void dispose() {
    _ageController.dispose();
    _gradeController.dispose();
    _schoolController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
```

Replace the `_onEditProfileDetailsPressed` method from Task 6 with this version that also fills the controllers:

```dart
  void _onEditProfileDetailsPressed() {
    if (!_parentMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable Parent Mode in Settings to edit profile details.'),
        ),
      );
      return;
    }
    final profile = context.read<GameProvider>().userProfile;
    _ageController.text = profile?['age']?.toString() ?? '';
    _gradeController.text = profile?['grade']?.toString() ?? '';
    _schoolController.text = profile?['school']?.toString() ?? '';
    _emailController.text = profile?['email']?.toString() ?? '';
    _phoneController.text = profile?['phone']?.toString() ?? '';
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _ageError = null;
      _passwordError = null;
      _editingProfileDetails = true;
    });
  }

  void _cancelEditingProfileDetails() {
    setState(() {
      _editingProfileDetails = false;
      _ageError = null;
      _passwordError = null;
    });
  }
```

Add the form-building method right after `_buildProfileDetailsCard` (after its closing `}`):

```dart
  Widget _buildProfileDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ageController,
          decoration: InputDecoration(
            labelText: 'Age',
            errorText: _ageError,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _gradeController,
          decoration: const InputDecoration(labelText: 'Grade', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _schoolController,
          decoration: const InputDecoration(labelText: 'School', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 20),
        const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _newPasswordController,
          decoration: InputDecoration(
            labelText: 'New Password',
            errorText: _passwordError,
            border: const OutlineInputBorder(),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmPasswordController,
          decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _savingProfileDetails ? null : _cancelEditingProfileDetails,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _savingProfileDetails ? null : () => _saveProfileDetails(context.read<GameProvider>()),
                child: _savingProfileDetails
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Placeholder wired up fully in the next task - Cancel/the form itself
  // don't need it yet, but the Save button above references it.
  Future<void> _saveProfileDetails(GameProvider provider) async {}
```

Update `_buildProfileDetailsCard` to switch between the read-only rows and the form:

```dart
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _editingProfileDetails
                  ? _buildProfileDetailsForm()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileDetailsRow('Age', profile?['age']),
                        _buildProfileDetailsRow('Grade', profile?['grade']),
                        _buildProfileDetailsRow('School', profile?['school']),
                        _buildProfileDetailsRow('Email', profile?['email']),
                        _buildProfileDetailsRow('Phone', profile?['phone']),
                      ],
                    ),
            ),
          ),
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/profile.dart test/screens/profile_screen_test.dart
git commit -m "feat: add editable profile-details form with Cancel"
```

---

### Task 8: Validation and Save

**Files:**
- Modify: `lib/screens/profile.dart`
- Test: `test/screens/profile_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to the `group`:

```dart
    testWidgets('non-numeric age shows an inline error and does not save',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), 'abc');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Age must be a number'), findsOneWidget);
      expect(provider.updateProfileCalled, false);
    });

    testWidgets('mismatched passwords show an inline error and do not save',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'New Password'), 'abc123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'different');
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(find.text('Passwords must match and not be empty'), findsOneWidget);
      expect(provider.updateProfileCalled, false);
    });

    testWidgets('valid edit saves only non-empty fields and shows success',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1', 'school': '', 'email': '', 'phone': ''};

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '7');
      await tester.enterText(find.widgetWithText(TextField, 'School'), 'SJIJ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(provider.updateProfileCalled, true);
      expect(provider.lastUpdateProfileData, {'age': 7, 'grade': 'P1', 'school': 'SJIJ'});
      expect(find.text('Profile updated successfully!'), findsOneWidget);
      expect(find.byType(TextField), findsNothing); // back to read-only
      expect(find.text('7'), findsOneWidget); // updated value now shown
      expect(find.text('SJIJ'), findsOneWidget);
    });

    testWidgets('failed save keeps the form open and shows an error',
        (tester) async {
      SharedPreferences.setMockInitialValues({'parent_mode': true});
      final provider = FakeGameProvider();
      provider.userProfile = {'age': 6, 'grade': 'P1'};
      provider.updateProfileResult = false;

      await tester.pumpWidget(createTestWidget(provider));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Edit'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Age'), '7');
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsWidgets); // still editing
      expect(find.textContaining('Failed to update profile'), findsOneWidget);
      // Entered text isn't rendered as a Text descendant, so check the
      // controller directly rather than find.text/widgetWithText.
      final ageField = tester.widget<TextField>(find.widgetWithText(TextField, 'Age'));
      expect(ageField.controller!.text, '7'); // input preserved
    });
```

- [ ] **Step 2: Run to verify all four fail**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: FAIL - `_saveProfileDetails` is currently a no-op, so nothing in these tests happens.

- [ ] **Step 3: Implement `_saveProfileDetails`**

Replace the placeholder `_saveProfileDetails` from Task 7 with:

```dart
  Future<void> _saveProfileDetails(GameProvider provider) async {
    setState(() {
      _ageError = null;
      _passwordError = null;
    });

    final ageText = _ageController.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null) {
        setState(() => _ageError = 'Age must be a number');
        return;
      }
    }

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;
    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      if (newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword) {
        setState(() => _passwordError = 'Passwords must match and not be empty');
        return;
      }
    }

    final data = <String, dynamic>{
      if (ageText.isNotEmpty) 'age': age,
      if (_gradeController.text.trim().isNotEmpty) 'grade': _gradeController.text.trim(),
      if (_schoolController.text.trim().isNotEmpty) 'school': _schoolController.text.trim(),
      if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
      if (_phoneController.text.trim().isNotEmpty) 'phone': _phoneController.text.trim(),
      if (newPassword.isNotEmpty) 'password': newPassword,
    };

    setState(() => _savingProfileDetails = true);
    final success = await provider.updateProfile(data);
    if (!mounted) return;
    setState(() => _savingProfileDetails = false);

    if (success) {
      setState(() => _editingProfileDetails = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: ${provider.errorMessage}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
```

- [ ] **Step 4: Run to verify all pass**

Run: `flutter test test/screens/profile_screen_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS (every test in the project, not just this file).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/profile.dart test/screens/profile_screen_test.dart
git commit -m "feat: validate and save profile details"
```

---

### Task 9: Manual verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: no new errors (pre-existing lint infos elsewhere in the repo are fine).

- [ ] **Step 2: Build for web**

Run: `flutter build web --release --dart-define=API_BASE_URL=https://spellbackend.fly.dev`
Expected: `√ Built build\web`.

- [ ] **Step 3: Serve and click through it live**

```bash
cd build/web
python -m http.server 8095
```

In a browser (or headless Chromium, as used earlier this session), log in as ERIC or HELLEN, open the Profile tab, and confirm:
- The Profile Details card shows real values (or `—` for empty ones) matching `curl https://spellbackend.fly.dev/users/<name>/profile`.
- With Parent Mode off (Settings tab), tapping Edit shows the snackbar and no text fields appear.
- Turning Parent Mode on, then Edit, shows the form pre-filled with current values.
- Changing a field and saving shows the green success snackbar, and the card reflects the new value after returning to read-only.
- Stop the local server afterward (`taskkill //F //PID <pid>` for whatever process is bound to port 8095, same as done earlier this session).

- [ ] **Step 4: Report back**

No commit for this task - it's verification only. Report the outcome (pass/fail, screenshots if anything looks off) before considering the feature done.
