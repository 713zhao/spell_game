# Avatar, Quick-Login & Kids-Style Login/Signup/Profile — Design

## Problem

Three gaps in the login/signup/account area implemented earlier this session:

1. Tapping a recently-used name on the login screen still requires typing the password every time, even though the whole point of the quick-pick list is fast re-entry on a shared family device.
2. The Profile screen's avatar is a plain white circle showing either a generic person emoji or an equipped cosmetic — no visual identity of its own.
3. Login, Signup, and Profile use plain Material widgets (default `TextField`, `DropdownButtonFormField`, flat buttons), while the rest of the app (Home, the Kingdom screens) has an established colorful, rounded, Duolingo-style visual language. These screens look visually disconnected from the rest of the app.

## A. Shared `UserAvatar` widget

New file: `lib/widgets/user_avatar.dart`.

```dart
class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  final String? cosmeticEmoji; // shown instead of the letter, if equipped

  const UserAvatar({
    super.key,
    required this.name,
    this.size = 56,
    this.cosmeticEmoji,
  });
}
```

- Background color is deterministically picked from a fixed palette based on a hash of `name`, so the same username always gets the same color across app opens and across every screen that shows it (login quick-pick, account button, profile header). Palette avoids red (already means "wrong answer" elsewhere in the app): green, blue, purple, orange, teal, pink.
- Shows `cosmeticEmoji` if provided and non-empty, otherwise the uppercase first letter of `name`.
- Replaces the avatar-drawing code currently duplicated (with slightly different logic) in `AccountAvatarButton` and the login screen's quick-pick chips, and the ad-hoc circle in Profile's header — all three become thin callers of this one widget.

## B. Auto-login with a locally-stored password

**Storage:** a new `SharedPreferences` string key `saved_passwords`, JSON-encoded `{username: password}`. Lives alongside the existing `recent_users` list and follows the same lifecycle: populated on successful login/signup, evicted in lockstep when `recent_users` trims to its 5-entry cap, and — like `recent_users` — **not** cleared on logout, since the point is fast re-entry after switching users on the same device.

**`GameProvider` changes:**
- `login(password)` and `signup(...)`, on success, additionally save the password used (signup: only if a non-empty password was actually provided — matches existing optional-password accounts).
- New `Future<bool> loginQuick(String name)`: looks up the stored password for `name`; if none exists, returns `false` immediately (no network call). If one exists, calls `init(name)` then the real `login(storedPassword)` and returns its result — so a stale/changed password is caught the same way a wrong manual entry is (network `verified: false`), not silently trusted.
- `_addRecentUser` (already trims `recent_users` to 5 on every login/signup) additionally deletes any `saved_passwords` entries for names that fell out of the trimmed list.

**Security note:** this stores the password in cleartext in the browser's local storage. That's consistent with the backend's existing plaintext-comparison auth (there is no password hashing anywhere in this system yet) — it extends the same trust model to the device rather than introducing a new category of exposure, but it's worth being explicit that this is not a hardened credential store.

## C. Login screen restyle

- Quick-pick avatars use `UserAvatar` (size ~64, colorful, soft shadow), replacing the current plain green circles.
- Tapping a quick-pick avatar now calls `loginQuick(name)` immediately instead of just revealing a password field:
  - Success → navigate straight to Home, same as today's manual flow.
  - Failure (no saved password, or it's stale) → falls back to today's behavior: reveal a password field for that user with a short "Enter your password to continue" prompt, so there's never a dead end.
- Manual-entry text fields (the "different username" fallback) get the same rounded/filled input style already established in `study.dart`'s sentence-fill exercise: `filled: true`, `DuolingoColors.neutralGray` fill, green focus border, fully rounded via `DuolingoSpacing.radiusButton`.
- "Log In" buttons become full-width rounded pill buttons in `DuolingoColors.primaryGreen`, matching Home/Kingdom screen buttons.
- "New here? Sign Up" becomes a more visually distinct call-to-action at the bottom (still a `TextButton`-style tap target, just restyled with the app's label typography/spacing) rather than a plain unstyled text link.

## D. Signup screen restyle

- Same input styling as Login (Section C).
- Grade picker changes from `DropdownButtonFormField` to a `Wrap` of six tappable rounded chips (P1–P6), visually matching the login screen's selected/unselected avatar-chip pattern (filled green + border when selected, neutral gray otherwise).
- "Create Account" becomes the same full-width green pill button style as Login's submit button.

## E. Profile screen

- The header's plain white circle (`Container` + `Text(stats?.equippedCosmetic ?? '👤')`) is replaced with `UserAvatar(name: username, size: 80, cosmeticEmoji: stats?.equippedCosmetic)`.
- No other structural change — stats grid, achievements, cosmetics grid, and settings section stay exactly as they are.

## Testing

- `UserAvatar`: widget test confirming the same name always produces the same background color across rebuilds, different names can produce different colors, and `cosmeticEmoji` takes precedence over the initial letter when provided.
- `GameProvider`: extend the existing session-management unit tests (`test/providers/game_provider_test.dart`) with a case proving `_addRecentUser`'s eviction also removes the evicted user's `saved_passwords` entry (fully testable without network, same pattern as the existing recent-users-capping test). `loginQuick`'s "no saved password → returns false without a network call" branch is also directly testable without mocking HTTP. The network-dependent success path (saving a password after a real verified login) is not unit-mocked, consistent with this codebase's existing testing conventions for `login()`/`signup()`.
- `LoginScreen`/`SignupScreen`: extend existing widget tests using the shared `FakeGameProvider`, adding cases for quick-login success (navigates straight to Home, no password field shown) and quick-login failure (falls back to showing the password field).
