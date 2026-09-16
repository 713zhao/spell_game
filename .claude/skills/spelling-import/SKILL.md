---
name: spelling-import
description: Extract spelling word lists from a PDF or photo of a lesson worksheet and import them into the SpellBackend database. Use when the user gives you a spelling-list PDF/image and asks to add/import/upload the words, or generate a lesson word JSON.
---

# Spelling Word Import

Turn a lesson worksheet (PDF or photo) into lesson-tagged JSON, get the
user's confirmation, then import it directly into the SpellBackend sqlite
database (via SpellBackend's own WordManager code, not the HTTP API — the
HTTP route has no way to set a per-lesson spell date).

## Step 1 — Extract words from the input file

Read the PDF or image directly with the Read tool (it handles both) and
transcribe the spelling words yourself — do not write an OCR script for
this.

Group words by lesson. Each lesson becomes one JSON key using this exact
naming convention:

```
[school]::[grade]::[term]::[subject]::[lesson]
```

Examples: `SJIJ`, `P1`, `Term3`, `CN`, `听写(十一)` → `SJIJ::P1::Term3::CN::听写(十一)`.

If any of the five parts (school / grade / term / subject / lesson name)
can't be confidently read from the file or inferred from the conversation,
ask the user for the missing piece(s) — don't guess a school code or term
number.

The lesson may include both single words/phrases and full sentences (e.g.
dictation lines like "我在小安和月华中间。") — keep them as separate strings in
the same list, in the order they appear on the page.

Some Chinese dictation sheets print certain items as pinyin only, with no
character shown (harder/unseen words the student is meant to know without
a printed answer key). Do **not** guess the characters for these — write
the pinyin exactly as printed, lowercase, without tone marks, words
separated by spaces (e.g. "er tong jie", not "ér tóng jié" and not 儿童节).
The import script already keeps such entries tagged as `chinese` (based on
the tag's subject segment) rather than misdetecting them as English.

## Step 2 — Write the JSON and confirm with the user

Write one JSON object per lesson to a file under `output/` at the repo
root (create it if missing — it's gitignored, alongside `input/`). Look
for a spell date on the worksheet for each lesson (the date the dictation/
spelling exercise is scheduled or was administered — keep it exactly as
printed, including Chinese-numeral dates like "九月二十九日"; don't
normalize or reformat it). When a lesson has a date, use the
`{"date", "words"}` shape; when no date can be found on the sheet, use a
plain word list — do not invent a date:

```json
{
  "SJIJ::P1::Term3::CN::听写(十一)": {
    "date": "九月二十九日",
    "words": [
      "左", "右", "的", "回", "画画", "同学", "中间", "后面", "上下", "前面",
      "脸圆圆的", "我在小安和月华中间。"
    ]
  },
  "SJIJ::P1::Term3::CN::听写(十二)": ["包子", "一半", "肉"]
}
```

Show the full JSON to the user and ask them to confirm it's correct (or
tell you what to fix) before importing anything. Do not proceed to Step 3
until they explicitly confirm.

## Step 3 — Ask public or private

Ask the user (e.g. with AskUserQuestion): should these words be **public**
(visible to everyone, owned by ADMIN) or **private to a specific user**?

- Public → target user is `ADMIN`.
- Private → ask for the username.

Either way, also ask (or infer from context) whether the lesson should
additionally be assigned/labeled to one specific student account even when
public — e.g. "public as ADMIN but also show up in HELLEN's lessons". If
so, pass that user via `--assign-to` in Step 4.

## Step 4 — Verify the target user, then import

Run the helper script from this skill's `scripts/` directory using
SpellBackend's own venv Python (it needs `sqlmodel` etc. — the system
Python won't have it):

```bash
SpellBackend/.venv/bin/python3 .claude/skills/spelling-import/scripts/import_words.py \
  --json output/<file>.json --user <ADMIN-or-username> [--assign-to <username>]
```

The script writes straight to `SpellBackend/database/db.sqlite3` using
SpellBackend's own `WordManager`/`User` models (found via
`--spellbackend-dir`, which defaults to this repo's `SpellBackend/`), and
sets each lesson's Tag.spell_date from the JSON's `date` field when
present.

- For `ADMIN`, the script creates the ADMIN user if it doesn't exist yet
  (this is expected and not an error), and the words are visible to all
  users.
- For a private username, the script looks the user up (case-insensitive)
  first. If the user does not exist, it exits with code 2 and prints
  `NOT_FOUND: user '<name>' does not exist in the backend.` — relay this
  to the user and ask them for a correct username (or whether they'd like
  to create that user first) instead of importing anywhere else.

On success the script prints a per-lesson imported count (noting the date
used, or "no date found") and a final `DONE:` summary — report that back
to the user.

## Importing into the Fly.io production backend

This environment has no SSH/direct-DB access to the production Fly volume
(`spellbackend.fly.dev`'s `/database` mount) — attempting `flyctl ssh
console` for this is blocked by the auto-mode classifier as a production
action. Use the HTTP-based script instead, which imports over the public
API exactly like a real client would:

```bash
python3 .claude/skills/spelling-import/scripts/import_words_http.py \
  --json output/<file>.json --user <ADMIN-or-username> [--assign-to <username>] \
  [--api-base https://spellbackend.fly.dev]
```

This uses plain system Python (no venv/sqlmodel needed — it only makes
HTTP calls). It verifies the target (and `--assign-to`) user exist via
`GET /users/{name}/profile` the same way, but **cannot set spell_date** —
there is no HTTP route for it, so any `"date"` in the JSON is skipped and
reported at the end as a `NOTE:` listing which lessons didn't get a date
recorded on that backend. Mention this limitation to the user rather than
silently dropping the dates.

If the user needs spell_date set in production too, that requires either
a new backend endpoint (edit `SpellBackend/src/routes/words.py` or
`tags.py` to accept it, then deploy via the `deploy` skill) or an
explicitly user-approved SSH session — don't attempt SSH into production
without the user granting that permission first.
