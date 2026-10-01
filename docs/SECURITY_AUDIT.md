# Security audit — SpellBackend, FlutterSpell, FlutterSpell_Game

Branch: `security-hardening` (all three repos). Status: **Fixed** = in this branch, **Open** = needs a decision or an out-of-repo action.

## Critical

| # | Risk | Where | Status |
|---|------|-------|--------|
| C1 | **Unauthenticated arbitrary SQL**: `POST /execute_query` ran any query (incl. `DROP`/`UPDATE`) | `admin_routes.py` | Fixed — endpoint removed (its template didn't exist anyway) |
| C2 | **No authentication on any user route**: anyone could read/modify/delete any child's profile, points, history, tags, or call `DELETE /users/{name}` | all routers | Fixed — HMAC-signed bearer tokens issued at login/sign-up; `AuthMiddleware` requires one and checks the user in the path/query/body matches the token |
| C3 | **Plaintext passwords** in the DB, logged in clear (`print(... provided/stored ...)`), and stored in browser `localStorage` (`saved_passwords`) by the Game app | `users.py`, `game_provider.dart`, `spell_api_service.dart` | Fixed — PBKDF2-SHA256 hashes (existing rows migrated at startup, legacy rows upgraded on login); logging removed; apps store a token instead of a password |
| C4 | **Hard-coded Gemini API key** in source (and git history) | `gemini_service.py` | Fixed in code (env var only). **Open:** the key is in git history — it is reported revoked; confirm, and rotate any key that was ever live |
| C5 | **Unauthenticated `/admin/backup`** (triggers Drive upload) | `main.py` | Fixed — admin Basic auth |
| C6 | **SQL injection** via `table_name` / column names in every `/admin/table/...` route | `admin_routes.py` | Fixed — table must exist in `sqlite_master`, columns checked against `PRAGMA table_info`, identifiers quoted |

## High

| # | Risk | Status |
|---|------|--------|
| H1 | **Mass assignment**: sign-up and `PUT /profile` accepted `total_points`, `coins`, `gems`, `id`… so a client could give itself unlimited currency | Fixed — sign-up uses a strict model; profile update whitelists `password, age, email, phone, school, grade` |
| H2 | `POST /users/` and profile responses returned the stored password | Fixed — password never returned |
| H3 | **Login brute force** (no throttling; kids' short passwords) | Fixed — 10 attempts / 5 min per IP+user (429); constant-time compares; same reply for unknown user vs wrong password |
| H4 | **Challenges**: anyone could accept/complete any challenge, and complete it repeatedly to farm points | Fixed — only the challengee accepts; only participants complete; winner must be a participant; completes once |
| H5 | CORS `allow_origins=["*"]` + `allow_credentials=True` | Fixed — only `*.aispell.pages.dev`, `*.aispellgame.pages.dev`, localhost (+ `CORS_ORIGINS`); credentials off |
| H6 | Admin console CSRF (Basic-auth creds are auto-sent by browsers) | Fixed — cross-origin state-changing admin requests rejected |
| H7 | Docker image copied `.env`, `.git`, `.venv`, local DB snapshots (real user data) | Fixed — `.dockerignore` |
| H8 | Vulnerable dependencies: `starlette 0.46.2`, `python-multipart 0.0.6` (known CVEs, DoS) | Fixed — `starlette 0.52.1`, `python-multipart 0.0.32` |
| H9 | Dead `admin.py` with hard-coded admin token `secret-admin-token` | Fixed — deleted |
| H10 | `GET /login-history/` dumped every user's login history | Fixed — removed (use `/admin`) |

## Medium / Low

| # | Risk | Status |
|---|------|--------|
| M1 | Cost abuse of Gemini / Google TTS by anonymous callers | Mitigated — AI endpoints need a token; AI + TTS rate limited; TTS text ≤ 500 chars; image upload ≤ 8 MB and type-checked; `words` ≤ 50 |
| M2 | Exception text leaked to clients (`str(e)`) | Fixed in AI/TTS/words routes |
| M3 | `echo=True` SQL logging (PII + passwords in logs) | Fixed |
| M4 | `/docs`, `/openapi.json` exposed in prod | Fixed — off unless `ENABLE_DOCS=true` |
| M5 | No security headers | Fixed — API (`nosniff`, `DENY`, HSTS, no-referrer, admin CSP/no-store) and both Pages sites (`web/_headers`) |
| M6 | Unpinned CDN script (hanzi-writer) | Fixed — exact version + SRI hash |
| M7 | Admin CSV import unbounded; temp-file/format issues | Fixed — 10 MB cap, columns validated |
| M8 | Debug `print`s of passwords in FlutterSpell | Fixed |

## Open — needs your decision

1. **Passwordless accounts** (`GUEST`, and any user created without a password) can be logged into by anyone who knows the name. That is the product's "quick login" design; the token only scopes damage to that one account. Consider requiring a password for every non-Guest account.
2. **Client-authoritative game economy**: `POST /users/{name}/points/add`, minigame/boss/streak endpoints trust the client, so a signed-in child can grant *themselves* points. Fixing it means computing rewards server-side.
3. **No parent/child roles**: "Parent Mode" is a client-side toggle; any token can call the same endpoints. Add a role claim if parents need real separation.
4. **Global content writes** (`POST /words/`, `PUT /words/{id}/quiz`, tag spell-date) are open to any signed-in user.
5. **Leaderboard** is public and shows names, school and grade of (child) users — consider pseudonyms / opt-in.
6. **PII at rest**: email/phone/school are stored unencrypted in SQLite (Fly volume). Volume snapshots/backups to Google Drive contain them.
7. FlutterSpell stores users' own AI provider keys in browser storage (`ai_service.dart`) — inherent to calling providers client-side.
8. Container runs as root; rate limiter is in-memory (single Fly machine).

## Deploy checklist
`flyctl secrets set -a spellbackend ADMIN_USERNAME=… ADMIN_PASSWORD=… AUTH_SECRET=$(openssl rand -hex 32) Gemini_key=…`, deploy the backend **and** both frontends together (old frontends have no token and will get 401s), and note that existing passwords are hashed on first start (take a DB backup first).
