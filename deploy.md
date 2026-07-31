# Deployment Guide

Three independently-deployed pieces:

| Component        | Repo               | Hosting          | URL                             |
|-------------------|---------------------|-------------------|----------------------------------|
| Backend (API)      | `SpellBackend/`      | Fly.io            | https://spellbackend.fly.dev     |
| FlutterSpell        | `FlutterSpell/`       | Cloudflare Pages  | https://aispell.pages.dev        |
| FlutterSpell_Game   | `FlutterSpell_Game/`  | Cloudflare Pages  | https://aispellgame.pages.dev    |

Both frontends call the same backend and it already allows that (`allow_origins=["*"]` in `SpellBackend/main.py`).

## Backend (Fly.io)

Prerequisites: `flyctl auth login` once per machine.

```bash
cd SpellBackend
flyctl deploy
```

This builds `dockerfile` and rolls out to the `spellbackend` app (`fly.toml`). The app listens on port 8000 internally; Fly terminates TLS and serves it at the URL above.

**Database**: production data lives on the Fly volume mounted at `/database` (see `[mounts]` in `fly.toml`), separate from the `database/db.sqlite3` file baked into the image — deploys never touch production data directly.

**Schema changes**: `SQLModel.metadata.create_all()` (called from `database/init_db.py` on every startup) only creates *missing tables*, it never alters existing ones. If you add a column to a model, you must also add an additive `ALTER TABLE ... ADD COLUMN` guarded by a `PRAGMA table_info` check in `init_db()` (see the `label_type` / `spell_date` blocks there for the pattern) — otherwise the persisted production DB stays on the old schema and every request touching that column 500s, even though it works locally against a fresh dev DB. One-off `add_*_column.py` scripts in the repo root only fix your local `db.sqlite3`; they are not run against production.

**Logs**: `flyctl logs -a spellbackend --no-tail` (omit `--no-tail` to stream).

## Frontends (Cloudflare Pages via Wrangler)

Prerequisites: `wrangler login` once per machine.

Each app reads its backend URL from `API_BASE_URL` at build time via `--dart-define`. **The two apps build URLs differently and need different trailing-slash conventions** — get this wrong and every request 404s:

- `FlutterSpell` concatenates `${baseUrl}tags/...` → needs a **trailing slash**: `https://spellbackend.fly.dev/`
- `FlutterSpell_Game` concatenates `$baseUrl/users/...` → needs **no trailing slash**: `https://spellbackend.fly.dev`

```bash
# FlutterSpell -> aispell.pages.dev
cd FlutterSpell
flutter build web --release --dart-define=API_BASE_URL=https://spellbackend.fly.dev/
wrangler pages deploy build/web --project-name=aispell --branch=main

# FlutterSpell_Game -> aispellgame.pages.dev
cd FlutterSpell_Game
flutter build web --release --dart-define=API_BASE_URL=https://spellbackend.fly.dev
wrangler pages deploy build/web --project-name=aispellgame --branch=main
```

**Always deploy `build/web`, never the repo root or `web/`.** The source `web/index.html` template still contains the literal placeholder `<base href="$FLUTTER_BASE_HREF">` — only `flutter build web` substitutes it with a real value. Deploying the wrong folder produces a blank page (the browser can't resolve `flutter_bootstrap.js` relative to an invalid base href).

**Always pass `--branch=main`.** Cloudflare Pages only updates the production domain (`*.pages.dev`) for deployments on the project's configured production branch (`main` for both `aispell` and `aispellgame`). Wrangler infers the branch from the current git repo if you omit the flag — `FlutterSpell_Game`'s local checkout is on `master`, so an unflagged deploy silently lands as a **Preview** deployment (its own throwaway `*.aispellgame.pages.dev` URL) and the live production domain doesn't change. Verify with:

```bash
wrangler pages deployment list --project-name=aispellgame
```
and confirm the latest row shows `Environment = Production`.

## Verifying a deploy

```bash
# base href must be a real path, not the placeholder
curl -s https://aispellgame.pages.dev/ | grep base

# JS must come back as JS, not the SPA-fallback HTML page
curl -sI https://aispellgame.pages.dev/flutter_bootstrap.js | grep -i content-type

# backend smoke test
curl -s https://spellbackend.fly.dev/openapi.json -o /dev/null -w "%{http_code}\n"
curl -s https://spellbackend.fly.dev/tags/all -o /dev/null -w "%{http_code}\n"
```

For a real functional check, load the site in a browser (or headless Chromium), click "Login as Guest", and confirm the tag/word list populates with no console errors — a blank shell or empty dropdown after guest login usually means the backend call itself is failing (check `flyctl logs`), not a frontend build problem.

## Local development

`restart-dev.bat` (repo root) kills and restarts all three processes for local dev: backend on port 8090, `FlutterSpell` on 8081, `FlutterSpell_Game` on 8080, each pointed at the local backend via the same `--dart-define=API_BASE_URL` mechanism described above.
