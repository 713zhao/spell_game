#!/usr/bin/env python3
"""Import a lesson-keyed spelling-words JSON file directly into the
SpellBackend sqlite database, using SpellBackend's own WordManager/User
code (not the HTTP API) so a per-lesson spell_date can be set - the
/words/users/{name}/words/ HTTP route has no spell_date parameter.

Must be run with SpellBackend's own venv Python so sqlmodel etc. are
importable, e.g.:

    SpellBackend/.venv/bin/python3 import_words.py --json words.json --user ADMIN

Input JSON shape (as produced by the spelling-import skill). Each lesson's
value is either a plain word list, or a {"date", "words"} object when a
spell date was found on the source sheet:
    {
      "SMSP::P1::Term4::CN::听写(十六)": {
        "date": "九月二十九日",
        "words": ["会", "打扫", ...]
      },
      "SMSP::P1::Term4::EN::Spelling 15": ["before", "line", ...]
    }

Usage:
    python3 import_words.py --json words.json --user ADMIN
    python3 import_words.py --json words.json --user ericzhao
    python3 import_words.py --json words.json --user ADMIN --assign-to HELLEN

`--assign-to` additionally links each imported lesson's tag to another
existing user (via TagManager.assign_tag_to_user), so e.g. a public/ADMIN
import can still show up in one student's own lesson list.

Exit codes:
    0  success
    2  target user (or --assign-to user) does not exist (reported to
       stdout, nothing imported)
"""
import argparse
import json
import os
import re
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path


def subject_from_tag(tag: str) -> str | None:
    """tag is [school]::[grade]::[term]::[subject]::[lesson] - subject is
    the 4th segment. Used to keep a romanized (pinyin-only) word in a CN
    lesson tagged as chinese rather than misdetected as english."""
    parts = tag.split("::")
    return parts[3].upper() if len(parts) >= 4 else None


def detect_language(text: str) -> str:
    """Mirrors WordManager.import_words_from_json's heuristic."""
    if re.search(r"[一-鿿]", text):
        return "chinese"
    if re.search(r"[぀-ヿ]", text):
        return "japanese"
    if re.search(r"[가-힯]", text):
        return "korean"
    if re.search(r"[A-Za-z\-' ]+", text):
        return "english"
    return "other"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--json", required=True, help="Path to the lesson-keyed words JSON file")
    parser.add_argument("--user", required=True, help="Target user name. Use ADMIN for public words.")
    parser.add_argument("--assign-to", default=None, help="Also link each imported lesson's tag to this existing user")
    parser.add_argument(
        "--spellbackend-dir",
        default=str(Path(__file__).resolve().parents[4] / "SpellBackend"),
        help="Path to the SpellBackend checkout (default: this repo's SpellBackend/)",
    )
    args = parser.parse_args()

    json_path = Path(args.json).resolve()  # resolve before chdir below
    backend_dir = Path(args.spellbackend_dir).resolve()
    sys.path.insert(0, str(backend_dir))
    os.chdir(backend_dir)  # src.db_session resolves the sqlite path relative to cwd

    from sqlmodel import select
    from sqlalchemy import func
    from src.db_session import get_session
    from src.models.user import User
    from src.models.tag import Tag
    from src.services.word_manager import WordManager
    from src.services.tag_manager import TagManager

    target_name = args.user.strip()
    is_public = target_name.upper() == "ADMIN"

    with get_session() as session:
        if is_public:
            user = session.exec(select(User).where(User.name == "ADMIN")).first()
            if not user:
                user = User(name="ADMIN")
                session.add(user)
                session.commit()
                session.refresh(user)
            target_name = "ADMIN"
        else:
            user = session.exec(select(User).where(func.upper(User.name) == target_name.upper())).first()
            if not user:
                print(f"NOT_FOUND: user '{target_name}' does not exist in the backend.")
                sys.exit(2)

        assign_to_user = None
        if args.assign_to:
            assign_name = args.assign_to.strip()
            assign_to_user = session.exec(select(User).where(func.upper(User.name) == assign_name.upper())).first()
            if not assign_to_user:
                print(f"NOT_FOUND: --assign-to user '{assign_name}' does not exist in the backend.")
                sys.exit(2)

        with open(json_path, "r", encoding="utf-8") as f:
            lessons = json.load(f)

        manager = WordManager(session)
        total_words = 0
        total_lessons = 0
        for tag, value in lessons.items():
            total_lessons += 1
            if isinstance(value, dict):
                spell_date = value.get("date") or None
                words = value.get("words", [])
            else:
                spell_date = None
                words = value

            imported = 0
            for word_text in words:
                language = detect_language(word_text)
                if language == "english" and subject_from_tag(tag) == "CN":
                    language = "chinese"
                from src.models.word import SpellingWord
                word = SpellingWord(text=word_text, language=language, created_by=str(user.id))
                with open(os.devnull, "w") as devnull, redirect_stdout(devnull), redirect_stderr(devnull):
                    manager.add_word(word, tag=tag, user_id=user.id, is_public=is_public, spell_date=spell_date)
                imported += 1
                total_words += 1
            date_note = f" (date: {spell_date})" if spell_date else " (no date found)"

            assign_note = ""
            if assign_to_user:
                tag_obj = session.exec(select(Tag).where(Tag.tag == tag)).first()
                if tag_obj:
                    TagManager.assign_tag_to_user(assign_to_user.id, tag_obj.id)
                    assign_note = f", assigned to '{assign_to_user.name}'"

            print(f"Lesson '{tag}': imported {imported}/{len(words)} words{date_note}{assign_note}")

        print(f"DONE: {total_words} words across {total_lessons} lesson(s) imported for user '{target_name}'.")


if __name__ == "__main__":
    main()
