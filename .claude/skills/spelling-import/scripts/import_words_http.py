#!/usr/bin/env python3
"""Import a lesson-keyed spelling-words JSON file into a SpellBackend
deployment over its public HTTP API (e.g. the Fly.io production backend,
which has no SSH/direct-DB access from this environment).

Unlike scripts/import_words.py (direct DB access, local dev only), this
cannot set a lesson's spell_date - the /words/users/{name}/words/ route
has no such parameter and there is no HTTP route to set Tag.spell_date.
Any "date" field in the input JSON is ignored (printed as a note).

Input JSON shape: same as import_words.py - each lesson's value is either
a plain word list, or a {"date", "words"} object (the date is ignored here).

Usage:
    python3 import_words_http.py --json words.json --user ADMIN
    python3 import_words_http.py --json words.json --user ADMIN --assign-to HELLEN \
        --api-base https://spellbackend.fly.dev

Exit codes:
    0  success
    2  target user (or --assign-to user) does not exist
    3  could not reach the backend API
"""
import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import quote


def subject_from_tag(tag: str) -> str | None:
    parts = tag.split("::")
    return parts[3].upper() if len(parts) >= 4 else None


def detect_language(text: str) -> str:
    if re.search(r"[一-鿿]", text):
        return "chinese"
    if re.search(r"[぀-ヿ]", text):
        return "japanese"
    if re.search(r"[가-힯]", text):
        return "korean"
    if re.search(r"[A-Za-z\-' ]+", text):
        return "english"
    return "other"


def http_json(method: str, url: str, body: dict | list | None = None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"error": raw.decode("utf-8", errors="replace")}
    except urllib.error.URLError as e:
        print(f"ERROR: could not reach backend at {url}: {e.reason}")
        sys.exit(3)


def user_exists(api_base: str, name: str) -> bool:
    status, _ = http_json("GET", f"{api_base}/users/{quote(name)}/profile")
    return status == 200


def find_tag_id(api_base: str, tag: str):
    status, tags = http_json("GET", f"{api_base}/tags/all")
    if status != 200 or not isinstance(tags, list):
        return None
    for t in tags:
        if t.get("tag") == tag:
            return t.get("id")
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", required=True, help="Path to the lesson-keyed words JSON file")
    parser.add_argument("--user", required=True, help="Target user name. Use ADMIN for public words.")
    parser.add_argument("--assign-to", default=None, help="Also link each imported lesson's tag to this existing user")
    parser.add_argument("--api-base", default="https://spellbackend.fly.dev", help="SpellBackend base URL")
    args = parser.parse_args()

    api_base = args.api_base.rstrip("/")
    target_user = args.user.strip()
    is_public = target_user.upper() == "ADMIN"

    if not user_exists(api_base, target_user):
        print(f"NOT_FOUND: user '{target_user}' does not exist at {api_base}.")
        sys.exit(2)

    assign_to = args.assign_to.strip() if args.assign_to else None
    if assign_to and not user_exists(api_base, assign_to):
        print(f"NOT_FOUND: --assign-to user '{assign_to}' does not exist at {api_base}.")
        sys.exit(2)

    with open(args.json, "r", encoding="utf-8") as f:
        lessons = json.load(f)

    total_words = 0
    total_lessons = 0
    dates_skipped = []
    for tag, value in lessons.items():
        total_lessons += 1
        if isinstance(value, dict):
            spell_date = value.get("date") or None
            words = value.get("words", [])
        else:
            spell_date = None
            words = value
        if spell_date:
            dates_skipped.append((tag, spell_date))

        imported = 0
        for word_text in words:
            language = detect_language(word_text)
            if language == "english" and subject_from_tag(tag) == "CN":
                language = "chinese"
            body = {"text": word_text, "language": language}
            status, resp = http_json(
                "POST",
                f"{api_base}/words/users/{quote(target_user)}/words/?tag={quote(tag)}&is_public={'true' if is_public else 'false'}",
                body,
            )
            if status != 200 or (isinstance(resp, dict) and resp.get("error")):
                print(f"  WARN: failed to import '{word_text}' under '{tag}': {resp}")
                continue
            imported += 1
            total_words += 1

        assign_note = ""
        if assign_to:
            tag_id = find_tag_id(api_base, tag)
            if tag_id is not None:
                status, resp = http_json("POST", f"{api_base}/tags/user/{quote(assign_to)}/assign/{tag_id}")
                if status == 200:
                    assign_note = f", assigned to '{assign_to}'"
                else:
                    assign_note = f", FAILED to assign to '{assign_to}': {resp}"
            else:
                assign_note = f", WARN: could not find tag id for '{tag}' to assign"

        print(f"Lesson '{tag}': imported {imported}/{len(words)} words{assign_note}")

    print(f"DONE: {total_words} words across {total_lessons} lesson(s) imported for user '{target_user}' at {api_base}.")
    if dates_skipped:
        print("NOTE: spell_date is not settable over HTTP - these lesson dates were NOT recorded on this backend:")
        for tag, d in dates_skipped:
            print(f"  {tag}: {d}")


if __name__ == "__main__":
    main()
