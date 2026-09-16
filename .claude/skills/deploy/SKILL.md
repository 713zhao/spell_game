---
name: deploy
description: Deploy the backend (SpellBackend to Fly.io) and/or the frontends (FlutterSpell, FlutterSpell_Game to Cloudflare Pages via Wrangler). Use when the user asks to deploy, ship, push to production, or release changes to spellbackend.fly.dev, aispell.pages.dev, or aispellgame.pages.dev.
---

# Deploy

Three independently-deployed pieces. Full reference lives in `deploy.md` at
the repo root — read it before deploying if any detail below is unclear or
if something doesn't match what you see in the repo (it may have drifted).

| Component         | Repo                  | Hosting           | URL                            |
|--------------------|------------------------|---------------------|---------------------------------|
| Backend (API)       | `SpellBackend/`         | Fly.io               | https://spellbackend.fly.dev    |
| FlutterSpell         | `FlutterSpell/`          | Cloudflare Pages    | https://aispell.pages.dev       |
| FlutterSpell_Game    | `FlutterSpell_Game/`     | Cloudflare Pages    | https://aispellgame.pages.dev   |

Ask the user which piece(s) to deploy if it isn't clear from context (e.g.
if they only changed backend files, default to just the backend).

## Before deploying

1. Run `git status` in the relevant sub-repo(s) and confirm there are no
   unexpected uncommitted changes. Deploys build from the working tree
   (`flyctl deploy`) or a fresh `flutter build` of it — not from a specific
   commit — so uncommitted local changes DO get deployed. Confirm with the
   user this is intended, or ask them to commit first.
2. If backend model changes touched a table, verify `database/init_db.py`
   has an additive `ALTER TABLE ... ADD COLUMN` guarded by `PRAGMA
   table_info` for any new column (see the `label_type` / `spell_date`
   blocks there for the pattern). `SQLModel.metadata.create_all()` only
   creates missing tables — it never alters existing ones. Skipping this
   means the production DB silently stays on the old schema and every
   request touching the new column 500s in prod despite working locally.

## Backend (Fly.io)

Prerequisites: `flyctl auth login` once per machine.

```bash
cd SpellBackend
flyctl deploy
```

Builds `dockerfile` and rolls out to the `spellbackend` app (`fly.toml`).
Production data lives on the Fly volume at `/database`, separate from the
`database/db.sqlite3` baked into the image — deploys never touch prod data
directly.

Logs: `flyctl logs -a spellbackend --no-tail` (drop `--no-tail` to stream).

## Frontends (Cloudflare Pages via Wrangler)

Prerequisites: `wrangler login` once per machine.

Each app reads its backend URL from `API_BASE_URL` at build time via
`--dart-define`. **The two apps need different trailing-slash conventions
— get this wrong and every request 404s:**

- `FlutterSpell` concatenates `${baseUrl}tags/...` → needs a **trailing
  slash**: `https://spellbackend.fly.dev/`
- `FlutterSpell_Game` concatenates `$baseUrl/users/...` → needs **no
  trailing slash**: `https://spellbackend.fly.dev`

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

**Always deploy `build/web`, never the repo root or `web/`.** The source
`web/index.html` template still has the literal placeholder
`<base href="$FLUTTER_BASE_HREF">` — only `flutter build web` substitutes a
real value. Deploying the wrong folder produces a blank page.

**Always pass `--branch=main`.** Cloudflare Pages only updates the
production domain for deployments on the project's configured production
branch (`main` for both projects). Wrangler infers the branch from the
current git repo if you omit the flag — both local checkouts are on
`master`, so an unflagged deploy silently lands as a throwaway Preview
deployment and production doesn't change. Verify with:

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

For a real functional check, load the site in a browser (or headless
Chromium), click "Login as Guest", and confirm the tag/word list populates
with no console errors — a blank shell or empty dropdown after guest login
usually means the backend call itself is failing (check `flyctl logs`), not
a frontend build problem.

Report back to the user which component(s) were deployed and the
verification results (HTTP codes / what the browser check showed).
