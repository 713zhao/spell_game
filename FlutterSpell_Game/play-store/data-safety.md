# Data safety form answers (Play Console → App content → Data safety)

Verify against the real app before submitting; these are based on the code and the published privacy policy.

**Does the app collect or share user data?** Yes collected; **Shared with third parties: No** (TTS/AI features are processed by our own backend, spellbackend.fly.dev).
**Is all data encrypted in transit?** Yes (HTTPS).
**Can users request data deletion?** Yes — https://aispell.pages.dev/data-deletion.html

| Data type | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|
| Name / username (Personal info → Name or User IDs) | Yes | No | Account management, App functionality | Required |
| Email address (optional, entered at sign-up or in Profile) | Yes | No | Account management (password recovery) | Optional |
| Password (Personal info → Other / Auth credentials) | Yes | No | Account management | Required |
| App activity (scores, progress, words practiced) | Yes | No | App functionality, Personalization | Required |
| Device identifiers / location / contacts / photos / financial | No | – | – | – |

Phone numbers are no longer collected (field removed from Profile).

Password recovery: users tap *Forgot password?*, which opens a pre-filled email to 713.zhao@gmail.com; the password is reset manually on the backend. The user-initiated email is sent through their own mail app, not collected by us.

## Target audience & Families policy
- Target age groups: **5–8, 9–12** (add 13+ only if parents are also targeted). Selecting children makes the app subject to the **Families Policy**.
- Appeals to children: Yes.
- Required consequences: privacy policy must be accurate and cover children (the existing one does); no ads SDKs (none present); the app must not request unnecessary permissions (only INTERNET).
- Account creation by a child: add parental-consent language to the privacy policy (currently says "under 13 without parental consent").

## Ads: No
## App access: login required → give reviewers a test account
Test account already created on spellbackend.fly.dev: username `playreview` (password in git-ignored `play-store/test-account.txt`). Enter both under "App access". Delete it after approval if you like: `DELETE /users/playreview`.

## Content rating (IARC questionnaire) — expected answers
Category: Reference/Education/Utility. Violence: none · Sexual: none · Profanity: none · Controlled substances: none · Gambling: none · User-to-user communication: none (confirm leaderboard shows only usernames) · Shares location: no · Digital purchases: no. Expected rating: **Everyone / PEGI 3**.

## Other declarations
- Government app: No · Financial features: No · Health: No · News app: No
- COVID-19: not applicable
- Advertising ID: **No** (declare "doesn't use"; no ad SDK)
