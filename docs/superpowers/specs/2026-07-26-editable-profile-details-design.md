# Editable Profile Details (FlutterSpell_Game)

**Date:** 2026-07-26
**Status:** Approved
**App:** FlutterSpell_Game
**File:** `lib/screens/profile.dart`

## Problem

The Profile tab (`ProfileScreen`) shows game stats, achievements, cosmetics, and app settings, but no account details. There's no way to view or edit a user's age, grade, school, email, phone, or password from within the app — every fix so far (e.g. correcting HELLEN's grade) required calling the backend API directly.

## Scope

Add a "Profile Details" card to the existing Profile tab, between the avatar header and the Stats grid. No new screen, no new route.

**Fields:** Age, Grade, School, Email, Phone — shown read-only by default. Username is never editable (it's the login identifier used to look up the user server-side). A "Change Password" sub-section (New Password / Confirm Password) is included but kept separate from the main field list.

**Parent gating:** The app already has a "Parent Mode" toggle in Settings (`_parentMode`, a `SharedPreferences` bool, no PIN). The Edit button on the new card only enters edit mode when Parent Mode is on; otherwise tapping it shows a message pointing to the Settings toggle. This reuses the existing toggle as-is — no new gating mechanism.

## UX Flow

1. Card always shows current values (or em-dashes if the profile hasn't loaded yet / failed to load — this must not block the rest of the page).
2. Tap **Edit**:
   - Parent Mode off → `SnackBar`: "Enable Parent Mode in Settings to edit profile details." Stay in read-only mode.
   - Parent Mode on → fields become `TextField`s pre-filled with current values, plus the two password fields (empty), and the Edit button is replaced by **Save** / **Cancel**.
3. **Cancel** discards changes and returns to read-only mode showing the last-loaded values.
4. **Save** validates locally:
   - Age, if non-empty, must parse as an integer.
   - If either password field is non-empty, both must be non-empty and equal.
   - On validation failure: inline error text under the offending field(s), no network call.
5. On valid input, calls the backend, then:
   - Success → green `SnackBar`, exit edit mode, refresh displayed values from the response.
   - Failure (network/4xx/5xx) → red `SnackBar` with the error, **stay in edit mode** so input isn't lost.

## Data Flow

Reuses the backend's existing `GET /users/{name}/profile` and `PUT /users/{name}/profile` endpoints (already used by FlutterSpell's `user_account_page.dart`, and the ones used manually to fix HELLEN's grade this session). No backend changes.

**`ApiClient` (`lib/services/api_client.dart`)** — two new methods, following the existing method style in this file (plain `Map<String, dynamic>`, no new model class — matches how FlutterSpell's equivalent screen does it):
```dart
Future<Map<String, dynamic>> getUserProfile()
Future<void> updateUserProfile(Map<String, dynamic> data)
```

**`GameProvider` (`lib/providers/game_provider.dart`)** — new state + methods mirroring the existing `loadUserStats()` pattern:
```dart
Map<String, dynamic>? userProfile;
Future<void> loadUserProfile()
Future<bool> updateProfile(Map<String, dynamic> data) // returns success/failure, doesn't throw
```

`updateProfile` only sends non-empty fields (password included only when the user filled it in), matching the null-omission pattern already used in FlutterSpell's `_saveProfile()`.

**`ProfileScreen`** calls `provider.loadUserProfile()` once, alongside the existing `loadUserStats()`/`loadUnlockables()` calls in `_loadProfileData()`.

## Error Handling

- Profile load failure: card renders with em-dashes for each field, no error banner (non-fatal — stats/achievements/settings still work normally).
- Save failure: red `SnackBar`, edit mode preserved, no data loss.
- Age field: non-numeric input caught client-side before any network call.

## Out of Scope

- Real parent-mode security (PIN/password gate) — Parent Mode remains the existing unauthenticated toggle.
- Editing username.
- A dedicated full-screen editor (rejected in favor of inline card, per user preference).
- Any change to the backend profile endpoints.

## Verification Plan

- `flutter analyze` on changed files.
- `flutter build web --release`.
- Live headless-browser click-through (as used earlier this session): log in, open Profile tab, confirm read-only values match the backend, toggle Parent Mode, edit + save a field, confirm it persists via a fresh profile fetch.
