# Login, Signup & Account Access — Design

## Problem

The app currently has no real login system. `main.dart` hardcodes `gameProvider.init('ERIC')` and `gameProvider.login('123')` at startup, and `MaterialApp.home` is hardcoded to `HomeScreen(userName: 'ERIC')`. There is no login screen, no signup screen, and the existing Profile screen's "Logout" button doesn't actually log out — it just navigates back to the same hardcoded-ERIC home. On a shared family device with multiple kid profiles (ERIC, HELLEN, and others), there is no way for the app itself to switch between them or for a new child to create their own account.

The backend already supports what's needed:
- `POST /users/` — create a user. Only `name` is required; `password`, `age`, `email`, `phone`, `school`, `grade` all default if omitted.
- `POST /users/{name}/verify-password` — form-encoded `password`, returns `{"verified": true|false}`.
- `POST /users/{name}/login` — records a login event (streak tracking).

This is entirely frontend work.

## Goals

1. A real login screen and signup screen.
2. A top-right circular button, present on every screen with its own app bar (except mid-session screens and Profile itself), that is the entry point into account access.
3. Session persistence so returning users aren't forced to log in every time the app opens.
4. Working logout / user-switching (fixing the existing broken Logout button along the way).

## Non-goals

- Password hashing or any other security hardening of the existing plaintext-comparison backend auth.
- A "forgot password" flow.
- Per-user cosmetic images on the avatar button (an initial letter is enough).
- Cross-device sync of the recent-users list — it's local `SharedPreferences` on one browser.

## A. Session & data layer

**New `SharedPreferences` keys:**
- `last_user` (String?) — the currently "remembered" username. Its presence means the app auto-restores that session on next open. Cleared on logout.
- `recent_users` (List\<String\>) — up to 5 previously-used names on this device, most-recent-first, deduplicated. Used for the login screen's quick-pick list. **Not** cleared on logout (it's "who's used this browser," independent of whether anyone is currently signed in).

**`GameProvider` additions** (`lib/providers/game_provider.dart`):
- `Future<void> restoreSession(String userName)` — calls the existing `init(userName)`, sets `isLoggedIn = true` directly (trusting the persisted session — no password is stored client-side, so this does not re-verify against the backend), fires `apiClient.logLogin()`, `notifyListeners()`.
- `Future<bool> signup({required String name, String? password, String? grade})` — calls a new `ApiClient.createUser(...)`. On success: `init(name)`, `isLoggedIn = true`, persists the session (see below), returns `true`. On failure (409 = name taken, or any other error): sets `errorMessage` to a specific message and returns `false` without mutating any session state.
- `Future<void> logout()` — sets `isLoggedIn = false`; resets all cached per-user data (`levels`, `deckCards`, `englishLessons`, `chineseLessons`, `userStats`, `unlockables`, `leaderboard`, `challenges`, `currentLevel`, `currentProgress`, `errorMessage`) to their empty/null defaults so a new user's screens never flash the previous user's data; clears `last_user` from `SharedPreferences` (leaves `recent_users` untouched); `notifyListeners()`.
- Existing `login(String password)` is extended: on `verified == true`, in addition to today's behavior, it also persists the session (`last_user`) and records the username into `recent_users`.
- Private helpers `_persistSession(String name)` and `_addRecentUser(String name)` back both `login()` and `signup()`'s success paths — `_addRecentUser` removes any existing occurrence of the name, inserts it at the front, and truncates the list to 5.

**`ApiClient` addition** (`lib/services/api_client.dart`):
- `Future<Map<String, dynamic>> createUser({required String name, String? password, String? grade})` — `POST /users/` with a JSON body of `{"name": ..., "password": ..., "grade": ...}` (omitting null fields). Throws an `Exception` with the backend's `detail` message on non-2xx (in particular, distinguishing 409 "already exists" so the signup screen can show a specific error).

**`AuthGate`** (new widget, `lib/screens/auth_gate.dart`): replaces `HomeScreen(userName: 'ERIC')` as `MaterialApp.home`. On `initState`, reads `last_user` from `SharedPreferences`:
- Present → `gameProvider.init(name)` then `gameProvider.restoreSession(name)`, then builds `HomeScreen(userName: name)`.
- Absent → builds the new `LoginScreen()`.
- While checking, shows a centered `CircularProgressIndicator`.

`main()` simplifies to just `WidgetsFlutterBinding.ensureInitialized(); runApp(const MyApp());` — the unconditional `init('ERIC')` / `login('123')` calls are removed; `AuthGate` now owns startup.

`main.dart`'s `onGenerateRoute` cases for `/` and `/home` stop hardcoding `HomeScreen(userName: 'ERIC')` and use `HomeScreen(userName: gameProvider.userName)` instead — necessary now that more than one user's session can be active. Two new routes are added: `/login` → `LoginScreen()`, `/signup` → `SignupScreen()`.

## B. Login screen (`lib/screens/login_screen.dart`, route `/login`)

- If `recent_users` is non-empty: shows a row of tappable circles (first-letter avatar + name label) for each. Tapping one reveals a password field beneath it and a "Log In" button, with the username fixed to that selection.
- A "Not you? Use a different username" link/toggle reveals a plain username + password text-entry form instead (covers first-time-on-this-device logins, or logging in as an existing-but-not-recent account).
- A "New here? Sign Up" link at the bottom navigates to `/signup`.
- On submit: `gameProvider.init(name)` then `gameProvider.login(password)`. If it returns `false`, show an inline "Incorrect username or password" error (the existing `login()` only sets `errorMessage` on thrown exceptions, not on a plain `verified: false` result, so the screen checks the return value itself rather than relying solely on `errorMessage`). On success: `Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false)` so the back button can't return to the login screen.

## C. Signup screen (`lib/screens/signup_screen.dart`, route `/signup`)

Minimal form: Username (required text field), Password (optional, obscured text field), Grade (optional dropdown: P1–P6, or blank). "Create Account" button calls `gameProvider.signup(...)`. On success, same navigation as login (`pushNamedAndRemoveUntil('/home', ...)`). On failure, shows `gameProvider.errorMessage` inline (e.g. "That username is already taken" for a 409).

## D. Top-right circle button (`lib/widgets/account_avatar_button.dart`, new)

A reusable widget added to `actions: [...]` on the `AppBar` of every screen that has one, **except**: `study.dart`, `boss_battle_screen.dart` (active-session screens — an account switcher here is a distracting mis-tap risk mid-exercise/mid-battle), and `profile.dart` (already is the destination). That's 12 screens: `home.dart`, `world_map_screen.dart`, `chinese_kingdom_screen.dart`, `english_castle_screen.dart`, `review_cave_screen.dart`, `treasure_island_screen.dart`, `boss_arena_screen.dart`, `backpack_screen.dart`, `progress_screen.dart`, `rewards_shop.dart`, `leaderboard.dart`, `lesson_overview_screen.dart`.

Rendering (reads `gameProvider.isLoggedIn` / `gameProvider.userName` directly, no new state):
- **Logged out**: a circle with a plain outline person icon. Tap → `Navigator.pushNamed(context, '/login')`.
- **Logged in**: a circle showing the username's first letter (uppercase). Tap → `showMenu` popup with two items:
  - **"View Profile"** → `Navigator.pushNamed(context, '/profile')`.
  - **"Switch User"** → `gameProvider.logout()` then `Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false)`.

## E. Fixing the existing Profile screen Logout button

`profile.dart`'s `_showLogoutDialog()` currently calls `Navigator.of(context).pushReplacementNamed('/')`, which is a no-op with respect to actually ending the session (still the same hardcoded user). It's updated to call `context.read<GameProvider>().logout()` then `Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false)` — the same real logout used by the new "Switch User" menu item.

## Testing

- `GameProvider.logout()`/`signup()`/`restoreSession()` — unit-testable via a fake/mocked `ApiClient` and `SharedPreferences.setMockInitialValues()`, following existing provider test patterns if any exist, or `flutter_test`'s standard widget-independent unit test style.
- `AccountAvatarButton` — widget test for both logged-in (shows initial, popup menu items present) and logged-out (shows icon, direct navigation) states.
- `LoginScreen` / `SignupScreen` — widget tests for the happy path (valid submit navigates to Home) and the error path (wrong password / duplicate username shows inline error, does not navigate).
