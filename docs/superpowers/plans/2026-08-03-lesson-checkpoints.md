# Lesson Checkpoints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split each lesson's word list into fixed 5-word checkpoints that unlock sequentially as their words hit the existing mastery bar, replacing today's binary locked/unlocked lesson gap with visible, mastery-driven progress steps — surfaced on both the World Map and Lesson Overview screen.

**Architecture:** Checkpoint membership and "current checkpoint" are computed on the fly from existing `ReviewState` data (ascending `word_id` order, chunks of 5) — nothing new is persisted for progression itself. The backend gains a `checkpoint_index`/`checkpoint_count` pair on `/lessons` (reusing already-fetched data) and an optional `checkpoint` filter on `/deck` (reusing the existing endpoint), plus a new `fail_count` column on `ReviewState` that biases `/deck`'s word ordering toward recently-struggling words. The Flutter client threads these through its existing models/screens with no new endpoints or screens.

**Tech Stack:** FastAPI + SQLModel + SQLite (SpellBackend), Flutter + Provider (FlutterSpell_Game), pytest, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-03-lesson-checkpoints-design.md`

---

## Task 1: Checkpoint chunking helper

**Files:**
- Create: `SpellBackend/src/services/checkpoints.py`
- Test: `SpellBackend/tests/test_checkpoints.py`

- [ ] **Step 1: Write the failing tests**

```python
from src.models.review_state import ReviewState
from src.services.checkpoints import chunk_word_ids, current_checkpoint_index


def test_chunk_word_ids_splits_into_fixed_size_groups_with_remainder_last():
    assert chunk_word_ids(list(range(1, 19))) == [
        [1, 2, 3, 4, 5],
        [6, 7, 8, 9, 10],
        [11, 12, 13, 14, 15],
        [16, 17, 18],
    ]


def test_chunk_word_ids_handles_empty_and_single_word():
    assert chunk_word_ids([]) == []
    assert chunk_word_ids([1]) == [[1]]


def test_chunk_word_ids_exact_multiple_of_chunk_size():
    assert chunk_word_ids([1, 2, 3, 4, 5, 6]) == [[1, 2, 3, 4, 5], [6]]


def test_current_checkpoint_index_stays_on_first_incomplete_chunk():
    chunks = [[1, 2, 3, 4, 5], [6, 7, 8, 9, 10]]
    state_by_word = {
        1: ReviewState(user_name="U", word_id=1, repetitions=5),
        2: ReviewState(user_name="U", word_id=2, repetitions=5),
        3: ReviewState(user_name="U", word_id=3, repetitions=3),  # not mastered
    }
    assert current_checkpoint_index(chunks, state_by_word) == 0


def test_current_checkpoint_index_advances_once_first_chunk_fully_mastered():
    chunks = [[1, 2], [3, 4]]
    state_by_word = {
        1: ReviewState(user_name="U", word_id=1, repetitions=5),
        2: ReviewState(user_name="U", word_id=2, repetitions=5),
    }
    assert current_checkpoint_index(chunks, state_by_word) == 1


def test_current_checkpoint_index_stays_on_last_chunk_when_all_mastered():
    chunks = [[1, 2], [3, 4]]
    state_by_word = {
        1: ReviewState(user_name="U", word_id=1, repetitions=5),
        2: ReviewState(user_name="U", word_id=2, repetitions=5),
        3: ReviewState(user_name="U", word_id=3, repetitions=5),
        4: ReviewState(user_name="U", word_id=4, repetitions=5),
    }
    assert current_checkpoint_index(chunks, state_by_word) == 1


def test_current_checkpoint_index_with_no_chunks_is_zero():
    assert current_checkpoint_index([], {}) == 0


def test_current_checkpoint_index_treats_missing_state_as_zero_repetitions():
    chunks = [[1, 2]]
    assert current_checkpoint_index(chunks, {}) == 0
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd SpellBackend
pytest tests/test_checkpoints.py -v
```

Expected: FAIL with `ModuleNotFoundError: No module named 'src.services.checkpoints'`.

- [ ] **Step 3: Write the implementation**

```python
from typing import Dict, List
from src.models.review_state import ReviewState

CHECKPOINT_SIZE = 5
MASTERY_REPS = 5


def chunk_word_ids(word_ids: List[int], chunk_size: int = CHECKPOINT_SIZE) -> List[List[int]]:
    """Splits word ids (already sorted by the caller, typically ascending by
    id) into fixed-size checkpoints, in order. The last chunk gets the
    remainder, so an 18-word lesson with chunk_size=5 becomes checkpoints of
    5, 5, 5, 3 words. Returns [] for an empty input."""
    return [word_ids[i:i + chunk_size] for i in range(0, len(word_ids), chunk_size)]


def current_checkpoint_index(
    chunks: List[List[int]],
    state_by_word: Dict[int, ReviewState],
    mastery_reps: int = MASTERY_REPS,
) -> int:
    """The user's current checkpoint = the first chunk containing any word
    below mastery_reps repetitions (a word with no ReviewState entry counts
    as 0 repetitions). If every chunk is fully mastered, or there are no
    chunks at all, returns the last valid index (0 when chunks is empty)."""
    for i, chunk in enumerate(chunks):
        if any(
            (state_by_word[wid].repetitions if wid in state_by_word else 0) < mastery_reps
            for wid in chunk
        ):
            return i
    return max(len(chunks) - 1, 0)
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd SpellBackend
pytest tests/test_checkpoints.py -v
```

Expected: PASS (8 passed).

- [ ] **Step 5: Commit**

```bash
git add SpellBackend/src/services/checkpoints.py SpellBackend/tests/test_checkpoints.py
git commit -m "feat: add checkpoint chunking helper for lesson word lists"
```

---

## Task 2: Lesson manager surfaces checkpoint_index / checkpoint_count

**Files:**
- Modify: `SpellBackend/src/services/lesson_manager.py:228-269`
- Test: `SpellBackend/tests/test_lesson_manager.py`

- [ ] **Step 1: Write the failing tests**

Append to `SpellBackend/tests/test_lesson_manager.py`:

```python
def test_checkpoint_fields_for_a_partially_mastered_lesson(session: Session):
    """18 words -> 4 checkpoints (5,5,5,3). First 5 words fully mastered,
    the 6th (first word of checkpoint 2) is not -> checkpoint_index == 1."""
    user = User(name="TESTUSER", grade="P1")
    session.add(user)
    session.commit()
    session.refresh(user)

    word_texts = [f"word{i}" for i in range(18)]
    reps = [5, 5, 5, 5, 5, 2] + [0] * 12
    _make_lesson(session, user, "Week1", 1, "EN", word_texts, reps)

    manager = LessonManager(session)
    lessons = manager.list_lessons_for_user(user, "EN")

    assert lessons[0]["checkpoint_count"] == 4
    assert lessons[0]["checkpoint_index"] == 1


def test_checkpoint_index_stays_on_last_chunk_when_lesson_fully_mastered(session: Session):
    user = User(name="TESTUSER", grade="P1")
    session.add(user)
    session.commit()
    session.refresh(user)

    _make_lesson(session, user, "Week1", 1, "EN",
                 ["a", "b", "c", "d", "e"], [5, 5, 5, 5, 5])

    manager = LessonManager(session)
    lessons = manager.list_lessons_for_user(user, "EN")

    assert lessons[0]["checkpoint_count"] == 1
    assert lessons[0]["checkpoint_index"] == 0
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd SpellBackend
pytest tests/test_lesson_manager.py -v -k checkpoint
```

Expected: FAIL with `KeyError: 'checkpoint_count'`.

- [ ] **Step 3: Implement**

In `SpellBackend/src/services/lesson_manager.py`, add the import near the top (after the existing `review_state` import):

```python
from src.models.review_state import ReviewState
from src.services.checkpoints import chunk_word_ids, current_checkpoint_index
```

Replace lines 228-243 (`mastery_pct = 0.0` through the blank line right before `if mastery_pct >= 1.0:` on line 244 — that line and everything after it stays as-is) with:

```python
            mastery_pct = 0.0
            state_by_word = {}
            if word_ids:
                states = self.session.exec(
                    select(ReviewState).where(
                        (ReviewState.user_name == user.name)
                        & (ReviewState.word_id.in_(word_ids))
                    )
                ).all()
                state_by_word = {s.word_id: s for s in states}
                total = 0.0
                for wid in word_ids:
                    st = state_by_word.get(wid)
                    reps = st.repetitions if st else 0
                    total += min(reps, self._MASTERY_REPS) / self._MASTERY_REPS
                mastery_pct = total / word_count

            checkpoint_chunks = chunk_word_ids(sorted(word_ids))
            checkpoint_count = len(checkpoint_chunks)
            checkpoint_index = current_checkpoint_index(checkpoint_chunks, state_by_word)

```

Then add the two new keys to the per-lesson result dict (originally lines 258-269):

```python
            result.append({
                "lesson_key": g["lesson_key"],
                "display_name": g["display_name"],
                "label_type": g["label_type"],
                "tags": g["tags"],
                "skills": g["skills"],
                "word_count": word_count,
                "mastery_pct": round(mastery_pct, 3),
                "stars": stars,
                "status": status,
                "spell_date": g["spell_date"],
                "checkpoint_index": checkpoint_index,
                "checkpoint_count": checkpoint_count,
            })
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd SpellBackend
pytest tests/test_lesson_manager.py -v
```

Expected: PASS (all tests in the file, including the 3 pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add SpellBackend/src/services/lesson_manager.py SpellBackend/tests/test_lesson_manager.py
git commit -m "feat: surface checkpoint_index/checkpoint_count on /lessons"
```

---

## Task 3: `ReviewState.fail_count` + scheduler increment + DB migration

**Files:**
- Modify: `SpellBackend/src/models/review_state.py`
- Modify: `SpellBackend/src/services/scheduler.py:22-24`
- Modify: `SpellBackend/database/init_db.py`
- Test: `SpellBackend/tests/test_scheduler.py` (new)

- [ ] **Step 1: Write the failing tests**

```python
from src.models.review_state import ReviewState
from src.services.scheduler import Scheduler


def test_update_sm2_increments_fail_count_on_a_miss():
    state = ReviewState(user_name="U", word_id=1, repetitions=3, fail_count=0)
    Scheduler.update_sm2(state, quality=1)
    assert state.repetitions == 0
    assert state.fail_count == 1


def test_update_sm2_does_not_increment_fail_count_on_success():
    state = ReviewState(user_name="U", word_id=1, repetitions=0, fail_count=2)
    Scheduler.update_sm2(state, quality=5)
    assert state.fail_count == 2


def test_update_sm2_accumulates_fail_count_across_repeated_misses():
    state = ReviewState(user_name="U", word_id=1, fail_count=0)
    Scheduler.update_sm2(state, quality=0)
    Scheduler.update_sm2(state, quality=5)
    Scheduler.update_sm2(state, quality=1)
    assert state.fail_count == 2
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd SpellBackend
pytest tests/test_scheduler.py -v
```

Expected: FAIL with `TypeError: __init__() got an unexpected keyword argument 'fail_count'` (the model field doesn't exist yet).

- [ ] **Step 3: Add the model field**

In `SpellBackend/src/models/review_state.py`, add after the existing `status` field:

```python
class ReviewState(SQLModel, table=True):
    user_name: str = Field(primary_key=True, foreign_key="user.name")
    word_id: int = Field(primary_key=True, foreign_key="spellingword.id")
    repetitions: int = 0
    interval_days: int = 0
    ease_factor: float = 2.5  # SM-2 default
    due_date: Optional[date] = None
    last_reviewed_at: Optional[datetime] = None
    status: Optional[str] = None  # new|learning|review
    fail_count: int = 0  # total misses ever; never reset, drives /deck priority
```

- [ ] **Step 4: Increment it in the scheduler**

In `SpellBackend/src/services/scheduler.py`, change the `quality < 3` branch (lines 22-24):

```python
        if quality < 3:
            state.repetitions = 0
            state.interval_days = 1
            state.fail_count += 1
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd SpellBackend
pytest tests/test_scheduler.py -v
```

Expected: PASS (3 passed).

- [ ] **Step 6: Add the additive DB migration**

In `SpellBackend/database/init_db.py`, add a new guarded block right after the existing `spell_date` migration block (after line 25, `conn.commit()`, and before `tag_count = conn.execute(...)`):

```python
        existing_review_state_columns = {row[1] for row in conn.execute("PRAGMA table_info(reviewstate);")}
        if "fail_count" not in existing_review_state_columns:
            conn.execute("ALTER TABLE reviewstate ADD COLUMN fail_count INTEGER DEFAULT 0;")
            conn.commit()
```

This follows the same pattern as the existing `label_type`/`spell_date` migrations immediately above it: `create_all` only creates missing *tables*, so an existing `reviewstate` table from before this change needs the column added explicitly. SQLite backfills existing rows with the `DEFAULT 0` value, so no separate `UPDATE` is needed (unlike the nullable `spell_date` column).

There's no automated test for this block — matching this file's existing convention, where the `label_type`/`spell_date` migrations also have no dedicated test. Verify manually once, after finishing Task 4 (which is when the new column starts being read/written by request handlers): start the backend locally (see Task 4's manual verification step) and confirm no errors on startup against an existing `database/db.sqlite3`.

- [ ] **Step 7: Commit**

```bash
git add SpellBackend/src/models/review_state.py SpellBackend/src/services/scheduler.py SpellBackend/database/init_db.py SpellBackend/tests/test_scheduler.py
git commit -m "feat: track fail_count on ReviewState for cross-session review priority"
```

---

## Task 4: DeckBuilder — deterministic ordering, checkpoint scoping, fail_count priority

**Files:**
- Modify: `SpellBackend/src/services/word_manager.py:74`
- Modify: `SpellBackend/src/services/deck_builder.py`
- Modify: `SpellBackend/src/routes/study.py`
- Test: `SpellBackend/tests/test_deck_builder.py`

- [ ] **Step 1: Write the failing tests**

Append to `SpellBackend/tests/test_deck_builder.py`:

```python
def test_words_by_tag_are_returned_in_ascending_id_order(session: Session):
    """Chunking into checkpoints depends on a stable word order; the
    underlying query previously had no ORDER BY, so this locks down
    ascending word_id as that stable order."""
    user = User(name="TESTUSER", grade="P3")
    session.add(user)
    session.commit()
    session.refresh(user)

    tag = Tag(tag="TEST::P3::EN::Week1", created_by="admin")
    session.add(tag)
    session.commit()
    session.refresh(tag)

    ids = []
    for text in ["zebra", "apple", "mango"]:
        w = SpellingWord(text=text, language="english")
        session.add(w)
        session.commit()
        session.refresh(w)
        session.add(WordTagLink(word_id=w.id, tag_id=tag.id))
        ids.append(w.id)
    session.commit()

    builder = DeckBuilder(session)
    cards, _ = builder.build_daily_deck("TESTUSER", limit=10, tag="TEST::P3::EN::Week1")

    assert [c["word_id"] for c in cards] == sorted(ids)


def test_checkpoint_param_scopes_deck_to_that_chunk_only(session: Session):
    user = User(name="TESTUSER", grade="P3")
    session.add(user)
    session.commit()
    session.refresh(user)

    tag = Tag(tag="TEST::P3::EN::Week1", created_by="admin")
    session.add(tag)
    session.commit()
    session.refresh(tag)

    ids = []
    for i in range(7):
        w = SpellingWord(text=f"word{i}", language="english")
        session.add(w)
        session.commit()
        session.refresh(w)
        session.add(WordTagLink(word_id=w.id, tag_id=tag.id))
        ids.append(w.id)
    session.commit()

    builder = DeckBuilder(session)
    cards, _ = builder.build_daily_deck(
        "TESTUSER", limit=10, tag="TEST::P3::EN::Week1", checkpoint=1
    )

    # Checkpoint 1 (0-indexed) is the second chunk of 5 words -> only the
    # 6th and 7th words (2 of them, since there are only 7 total).
    assert sorted(c["word_id"] for c in cards) == sorted(ids[5:7])


def test_deck_prioritizes_words_with_higher_fail_count(session: Session):
    """Within the same due-status tier, a word that's failed more should
    come back before one that's failed less, so it resurfaces sooner."""
    user = User(name="TESTUSER", grade="P3")
    session.add(user)
    session.commit()
    session.refresh(user)

    tag = Tag(tag="TEST::P3::EN::Week1", created_by="admin")
    session.add(tag)
    session.commit()
    session.refresh(tag)

    today = Scheduler.today_sg()
    words = []
    for text in ["low_fail", "high_fail"]:
        w = SpellingWord(text=text, language="english")
        session.add(w)
        session.commit()
        session.refresh(w)
        session.add(WordTagLink(word_id=w.id, tag_id=tag.id))
        words.append(w)
    session.commit()

    session.add(ReviewState(
        user_name="TESTUSER", word_id=words[0].id, repetitions=1,
        due_date=today, fail_count=1,
    ))
    session.add(ReviewState(
        user_name="TESTUSER", word_id=words[1].id, repetitions=1,
        due_date=today, fail_count=4,
    ))
    session.commit()

    builder = DeckBuilder(session)
    cards, _ = builder.build_daily_deck("TESTUSER", limit=10, tag="TEST::P3::EN::Week1")

    assert [c["text"] for c in cards] == ["high_fail", "low_fail"]
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd SpellBackend
pytest tests/test_deck_builder.py -v
```

Expected: the ordering test may pass or fail depending on SQLite's incidental row order (flaky/undefined today); the checkpoint test FAILs with `TypeError: build_daily_deck() got an unexpected keyword argument 'checkpoint'`; the fail_count test FAILs on the final assertion (order unchanged from today's due-date/ease_factor-only sort).

- [ ] **Step 3: Fix word ordering**

In `SpellBackend/src/services/word_manager.py`, change line 74:

```python
        return self.session.exec(
            select(SpellingWord).where(SpellingWord.id.in_(word_ids)).order_by(SpellingWord.id)
        ).all()
```

- [ ] **Step 4: Add checkpoint scoping and fail_count priority to DeckBuilder**

In `SpellBackend/src/services/deck_builder.py`, add the import at the top:

```python
from src.services.checkpoints import chunk_word_ids
```

Change the method signature (line 16):

```python
    def build_daily_deck(self, user_name: str, limit: int = 10, tag: str = None, checkpoint: int = None) -> Tuple[List[Dict], str]:
```

Right after the existing tag/no-tag word-fetch branch (lines 31-35: `if tag is None: ... else: ...`), insert:

```python
        if checkpoint is not None and tag is not None:
            sorted_ids = sorted(w.id for w in words)
            chunks = chunk_word_ids(sorted_ids)
            if 0 <= checkpoint < len(chunks):
                allowed_ids = set(chunks[checkpoint])
                words = [w for w in words if w.id in allowed_ids]
```

Change the two sort calls (lines 68-69) to sort by `fail_count` descending first:

```python
        overdue.sort(key=lambda item: (-item[1].fail_count, (item[1].due_date or today), item[1].ease_factor, item[0].id))
        not_due_yet.sort(key=lambda item: (-item[1].fail_count, (item[1].due_date or today), item[1].ease_factor, item[0].id))
```

- [ ] **Step 5: Pass the new param through the route**

In `SpellBackend/src/routes/study.py`, change `get_daily_deck`:

```python
@router.get("/{name}/deck")
def get_daily_deck(name: str, limit: int = 10, tag: str = None, checkpoint: int = None):
    with get_session() as session:
        print(f"Fetching daily deck for user: {name} with limit: {limit} and tag: {tag}")
        manager = UserManager(session)
        user_profile = manager.get_user_profile(name)
        print(f"User found: {user_profile is not None}")
        if not user_profile:
            raise HTTPException(status_code=404, detail="User not found")
        builder = DeckBuilder(session)
        cards, empty_reason = builder.build_daily_deck(name, limit=limit, tag=tag, checkpoint=checkpoint)
        return {
            "date": Scheduler.today_sg().isoformat(),
            "cards": cards,
            "empty_reason": empty_reason or None
        }
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd SpellBackend
pytest tests/test_deck_builder.py -v
```

Expected: PASS (all tests in the file, including pre-existing ones).

- [ ] **Step 7: Run the full backend test suite**

```bash
cd SpellBackend
pytest -v
```

Expected: PASS (no regressions in `test_lesson_manager.py`, `test_scheduler.py`, `test_checkpoints.py`, or any pre-existing file).

- [ ] **Step 8: Commit**

```bash
git add SpellBackend/src/services/word_manager.py SpellBackend/src/services/deck_builder.py SpellBackend/src/routes/study.py SpellBackend/tests/test_deck_builder.py
git commit -m "feat: scope /deck to a checkpoint and prioritize by fail_count"
```

---

## Task 5: Client models gain checkpoint fields

**Files:**
- Modify: `FlutterSpell_Game/lib/models/game_models.dart:161-198` (`LessonSummary`)
- Modify: `FlutterSpell_Game/lib/models/stage_data.dart` (`StageData`)
- Test: `FlutterSpell_Game/test/models/game_models_test.dart` (new)

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';

void main() {
  group('LessonSummary.fromJson checkpoint fields', () {
    test('parses checkpoint_index and checkpoint_count when present', () {
      final lesson = LessonSummary.fromJson({
        'lesson_key': 'Week1',
        'display_name': 'Week 1',
        'label_type': 'TEACHER',
        'tags': ['T::P1::EN::Week1'],
        'skills': [],
        'word_count': 12,
        'mastery_pct': 0.5,
        'stars': 2,
        'status': 'current',
        'checkpoint_index': 1,
        'checkpoint_count': 3,
      });

      expect(lesson.checkpointIndex, 1);
      expect(lesson.checkpointCount, 3);
    });

    test('defaults checkpoint fields from word_count when the backend omits them', () {
      final lesson = LessonSummary.fromJson({
        'lesson_key': 'Week1',
        'display_name': 'Week 1',
        'label_type': 'TEACHER',
        'tags': ['T::P1::EN::Week1'],
        'skills': [],
        'word_count': 12,
        'mastery_pct': 0.5,
        'stars': 2,
        'status': 'current',
      });

      expect(lesson.checkpointIndex, 0);
      expect(lesson.checkpointCount, 3); // ceil(12 / 5)
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd FlutterSpell_Game
flutter test test/models/game_models_test.dart
```

Expected: FAIL — `The getter 'checkpointIndex' isn't defined for the type 'LessonSummary'.`

- [ ] **Step 3: Implement `LessonSummary` changes**

In `FlutterSpell_Game/lib/models/game_models.dart`, replace the `LessonSummary` class (lines 161-198) with:

```dart
class LessonSummary {
  final String lessonKey;
  final String displayName;
  final String labelType; // TEACHER | MOE
  final List<String> tags;
  final List<String> skills;
  final int wordCount;
  final double masteryPct;
  final int stars;
  final String status; // completed | current | locked
  final String? spellDate; // raw text, e.g. "七月十四日"; null when unset
  final int checkpointIndex; // 0-based index of the current unlocked checkpoint
  final int checkpointCount; // total checkpoints in this lesson (words / 5, rounded up)

  LessonSummary({
    required this.lessonKey,
    required this.displayName,
    required this.labelType,
    required this.tags,
    required this.skills,
    required this.wordCount,
    required this.masteryPct,
    required this.stars,
    required this.status,
    this.spellDate,
    this.checkpointIndex = 0,
    this.checkpointCount = 0,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) {
    final wordCount = json['word_count'] as int;
    return LessonSummary(
      lessonKey: json['lesson_key'] as String,
      displayName: json['display_name'] as String,
      labelType: json['label_type'] as String? ?? 'TEACHER',
      tags: (json['tags'] as List).cast<String>(),
      skills: (json['skills'] as List).cast<String>(),
      wordCount: wordCount,
      masteryPct: (json['mastery_pct'] as num).toDouble(),
      stars: json['stars'] as int,
      status: json['status'] as String,
      spellDate: json['spell_date'] as String?,
      checkpointIndex: json['checkpoint_index'] as int? ?? 0,
      checkpointCount:
          json['checkpoint_count'] as int? ?? (wordCount / 5).ceil(),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd FlutterSpell_Game
flutter test test/models/game_models_test.dart
```

Expected: PASS (2 passed).

- [ ] **Step 5: Add matching fields to `StageData`**

In `FlutterSpell_Game/lib/models/stage_data.dart`, replace the `StageData` class (lines 1-18) with:

```dart
/// One lesson node's data within a kingdom's journey path.
class StageData {
  final int stageNumber;
  final String title;
  final double progress; // 0.0 to 1.0
  final int stars; // 0 to 3
  bool isLocked;
  final String? spellDate; // raw text, e.g. "七月十四日"; null when unset
  final int checkpointIndex; // 0-based index of the current unlocked checkpoint
  final int checkpointCount; // total checkpoints; <= 1 means no indicator is shown

  StageData({
    required this.stageNumber,
    required this.title,
    required this.progress,
    required this.stars,
    required this.isLocked,
    this.spellDate,
    this.checkpointIndex = 0,
    this.checkpointCount = 0,
  });
}
```

Default values keep `FlutterSpell_Game/lib/data/chinese_stages.dart`'s mock stages (which don't set these) compiling unchanged, with `checkpointCount` defaulting to 0 so no indicator renders for them.

- [ ] **Step 6: Run the full model/widget test suite for regressions**

```bash
cd FlutterSpell_Game
flutter test test/models/
```

Expected: PASS (no regressions in `stage_data_test.dart` or `chinese_stages_test.dart`).

- [ ] **Step 7: Commit**

```bash
git add FlutterSpell_Game/lib/models/game_models.dart FlutterSpell_Game/lib/models/stage_data.dart FlutterSpell_Game/test/models/game_models_test.dart
git commit -m "feat: add checkpointIndex/checkpointCount to LessonSummary and StageData"
```

---

## Task 6: Thread `checkpoint` through ApiClient and GameProvider

**Files:**
- Modify: `FlutterSpell_Game/lib/services/api_client.dart:93-119`
- Modify: `FlutterSpell_Game/lib/providers/game_provider.dart:250-260`
- Modify: `FlutterSpell_Game/test/support/fake_game_provider.dart:161`

This is a thin, one-parameter passthrough with no branching logic. The codebase has no existing pattern for mocking `http.get` or asserting on `ApiClient` call arguments (verified: no `api_client_test.dart`, no mock-http package in `pubspec.yaml`), so — consistent with how the existing `limit`/`tags` params on the same methods are handled — this task is implementation + static analysis, not TDD. The actual observable behavior this enables (checkpoint-scoped word grid, checkpoint-scoped study session) is covered by Tasks 7 and 9's widget tests.

- [ ] **Step 1: Update `ApiClient.getDeckCards`**

In `FlutterSpell_Game/lib/services/api_client.dart`, replace lines 93-99:

```dart
  Future<List<DeckCard>> getDeckCards({List<String>? tags, int limit = 10, int? checkpoint}) async {
    final tagParam = (tags != null && tags.isNotEmpty)
        ? '&tag=${Uri.encodeComponent(tags.join(","))}'
        : '';
    final checkpointParam = checkpoint != null ? '&checkpoint=$checkpoint' : '';
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/deck?limit=$limit$tagParam$checkpointParam'),
    );
```

- [ ] **Step 2: Update `GameProvider.loadDeck`**

In `FlutterSpell_Game/lib/providers/game_provider.dart`, replace lines 250-260:

```dart
  Future<void> loadDeck({List<String>? tags, int limit = 10, int? checkpoint}) async {
    deckCards = [];
    notifyListeners();
    try {
      deckCards = await apiClient.getDeckCards(
        tags: tags,
        limit: limit,
        checkpoint: checkpoint,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }
```

- [ ] **Step 3: Update the matching override in the test double**

`FakeGameProvider implements GameProvider`, so its `loadDeck` override must accept the same named parameters or the project fails to compile. In `FlutterSpell_Game/test/support/fake_game_provider.dart`, replace line 161:

```dart
  @override
  Future<void> loadDeck({List<String>? tags, int limit = 10, int? checkpoint}) async {}
```

- [ ] **Step 4: Verify with static analysis and the existing suite**

```bash
cd FlutterSpell_Game
flutter analyze
flutter test
```

Expected: `flutter analyze` reports no new issues; `flutter test` passes with no regressions (this confirms `FakeGameProvider` still satisfies the `GameProvider` interface and every existing caller of `loadDeck`/`getDeckCards` still compiles with the new optional param).

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/lib/services/api_client.dart FlutterSpell_Game/lib/providers/game_provider.dart FlutterSpell_Game/test/support/fake_game_provider.dart
git commit -m "feat: thread an optional checkpoint filter through the deck-loading API"
```

---

## Task 7: Lesson Overview — checkpoint-sectioned word grid

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`
- Modify: `FlutterSpell_Game/test/screens/lesson_overview_screen_test.dart`

- [ ] **Step 1: Extend the test file's `_lesson` helper and write the failing tests**

In `FlutterSpell_Game/test/screens/lesson_overview_screen_test.dart`, replace the `_lesson` helper (lines 21-35) with:

```dart
LessonSummary _lesson({
  required double masteryPct,
  required int wordCount,
  int checkpointIndex = 0,
  int checkpointCount = 0,
}) {
  return LessonSummary(
    lessonKey: 'Week1',
    displayName: 'Week 1',
    labelType: 'TEACHER',
    tags: const ['T::P1::EN::Week1'],
    skills: const [],
    wordCount: wordCount,
    masteryPct: masteryPct,
    stars: masteryPct >= 1.0
        ? 3
        : (masteryPct >= 0.5 ? 2 : (masteryPct > 0 ? 1 : 0)),
    status: masteryPct >= 1.0 ? 'completed' : 'current',
    checkpointIndex: checkpointIndex,
    checkpointCount: checkpointCount,
  );
}
```

Then add these two `testWidgets` inside `main()`, alongside the existing ones:

```dart
  testWidgets(
    'word grid is grouped into checkpoint sections with headers',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_screen(_lesson(
        masteryPct: 0.3,
        wordCount: 7,
        checkpointIndex: 1,
        checkpointCount: 2,
      )));
      await tester.pump();

      gameProvider.deckCards = [
        for (var i = 1; i <= 7; i++)
          DeckCard(
            word: Word(id: i, text: 'word$i', language: 'english'),
            repetitions: i <= 5 ? 5 : 0,
            status: i <= 5 ? 'review' : 'new',
          ),
      ];
      gameProvider.notifyListeners();
      await tester.pump();

      await tester.tap(find.textContaining('word-by-word'));
      await tester.pump();

      expect(find.text('Checkpoint 1'), findsOneWidget);
      expect(find.text('Checkpoint 2'), findsOneWidget);
    },
  );

  testWidgets(
    'chips in a checkpoint beyond the current one show locked styling regardless of mastery tier',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(_screen(_lesson(
        masteryPct: 0.7,
        wordCount: 7,
        checkpointIndex: 0,
        checkpointCount: 2,
      )));
      await tester.pump();

      gameProvider.deckCards = [
        for (var i = 1; i <= 7; i++)
          DeckCard(
            word: Word(id: i, text: 'word$i', language: 'english'),
            repetitions: 5, // fully mastered, but words 6-7 are in checkpoint 2
            status: 'review',
          ),
      ];
      gameProvider.notifyListeners();
      await tester.pump();

      await tester.tap(find.textContaining('word-by-word'));
      await tester.pump();

      // word6 is in checkpoint 2 (index 1), beyond currentCheckpoint (0) ->
      // rendered locked-grey even though repetitions=5 would normally be green.
      expect(_chipColorFor(tester, 'word6'), DuolingoColors.secondaryButtonGray);
      // word1 is in checkpoint 1 (index 0), the current one -> real mastery color.
      expect(_chipColorFor(tester, 'word1'), DuolingoColors.primaryGreen);
    },
  );
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd FlutterSpell_Game
flutter test test/screens/lesson_overview_screen_test.dart
```

Expected: FAIL — `Checkpoint 1`/`Checkpoint 2` not found (grid is currently a flat, unsectioned `Wrap`).

- [ ] **Step 3: Implement the checkpoint-sectioned grid**

In `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`, add `import 'dart:math' show min;` to the top imports, then replace `_buildWordDetailGrid` (lines 127-158) with:

```dart
  static const int _checkpointSize = 5;

  Widget _buildWordDetailGrid() {
    if (gameProvider.deckCards.isEmpty) {
      // An empty deck means either the fetch hasn't resolved yet, or it
      // resolved as a failure - loadDeck's catch branch only sets
      // errorMessage, it never touches deckCards. Distinguish the two so a
      // failed fetch doesn't show "Loading..." forever.
      final failed = gameProvider.errorMessage != null;
      return Padding(
        padding: EdgeInsets.only(top: DuolingoSpacing.sm),
        child: Text(
          failed ? "Couldn't load word details" : 'Loading word details...',
          style: DuolingoTextStyles.label.copyWith(
            color: DuolingoColors.bodyText,
            fontSize: 11,
          ),
        ),
      );
    }

    final sorted = List<DeckCard>.from(gameProvider.deckCards)
      ..sort((a, b) => a.word.id.compareTo(b.word.id));
    final chunks = <List<DeckCard>>[];
    for (var i = 0; i < sorted.length; i += _checkpointSize) {
      chunks.add(sorted.sublist(i, min(i + _checkpointSize, sorted.length)));
    }
    final currentCheckpoint = widget.args.lesson.checkpointIndex;

    return Padding(
      padding: EdgeInsets.only(top: DuolingoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < chunks.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: DuolingoSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Checkpoint ${i + 1}',
                    style: DuolingoTextStyles.label.copyWith(
                      color: DuolingoColors.bodyText,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: chunks[i].map((card) {
                      final locked = i > currentCheckpoint;
                      return _MasteryChip(
                        text: card.word.text,
                        color: locked
                            ? DuolingoColors.secondaryButtonGray
                            : _masteryChipColor(card.repetitions),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd FlutterSpell_Game
flutter test test/screens/lesson_overview_screen_test.dart
```

Expected: PASS (all tests in the file, including the 5 pre-existing ones).

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/lib/screens/lesson_overview_screen.dart FlutterSpell_Game/test/screens/lesson_overview_screen_test.dart
git commit -m "feat: group the Lesson Overview word grid into checkpoint sections"
```

---

## Task 8: Scope the study session to the current checkpoint

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart:50-64` (`StudySessionArgs`), `:413-419` (Start Adventure button)
- Modify: `FlutterSpell_Game/lib/screens/study.dart:160`

No dedicated automated test: `StudySessionArgs` is a plain arguments bag passed via `Navigator.pushReplacementNamed`, and this repo's existing tests never intercept navigation arguments or `ApiClient` call parameters (see Task 6's rationale) — the pre-existing `skills` field on the same class has no dedicated test either. Correctness here is a one-line field threaded through three call sites, verified by `flutter analyze` (which would flag a missing/mistyped named argument) plus the manual smoke test in this plan's final verification step.

- [ ] **Step 1: Add `checkpoint` to `StudySessionArgs`**

In `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`, replace lines 50-64:

```dart
/// Navigation arguments for the '/study' route.
class StudySessionArgs {
  final List<String> tags;
  final String lessonKey;
  final String displayName;
  final String subject;
  final List<String> skills;
  final int? checkpoint;

  const StudySessionArgs({
    required this.tags,
    required this.lessonKey,
    required this.displayName,
    required this.subject,
    this.skills = const [],
    this.checkpoint,
  });
}
```

- [ ] **Step 2: Pass the lesson's current checkpoint when starting a session**

In the same file, replace the `StudySessionArgs(...)` construction inside the Start Adventure `onTap` (lines 413-419):

```dart
                    arguments: StudySessionArgs(
                      tags: lesson.tags,
                      lessonKey: lesson.lessonKey,
                      displayName: lesson.displayName,
                      subject: widget.args.subject,
                      skills: lesson.skills,
                      checkpoint: lesson.checkpointIndex,
                    ),
```

- [ ] **Step 3: Scope the deck fetch in `study.dart`**

In `FlutterSpell_Game/lib/screens/study.dart`, replace line 160:

```dart
      await gameProvider.loadDeck(
        tags: widget.args.tags,
        checkpoint: widget.args.checkpoint,
      );
```

- [ ] **Step 4: Verify with static analysis and the existing suite**

```bash
cd FlutterSpell_Game
flutter analyze
flutter test
```

Expected: no new `flutter analyze` issues; `flutter test` passes with no regressions.

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/lib/screens/lesson_overview_screen.dart FlutterSpell_Game/lib/screens/study.dart
git commit -m "feat: scope study sessions to the lesson's current checkpoint"
```

---

## Task 9: World Map — checkpoint indicator on lesson nodes

**Files:**
- Modify: `FlutterSpell_Game/lib/widgets/journey_path.dart:263-294`
- Modify: `FlutterSpell_Game/lib/screens/english_castle_screen.dart:60-67`
- Modify: `FlutterSpell_Game/lib/screens/chinese_kingdom_screen.dart:60-67`
- Test: `FlutterSpell_Game/test/widgets/journey_path_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `FlutterSpell_Game/test/widgets/journey_path_test.dart`, inside `main()`:

```dart
  testWidgets(
      'shows a checkpoint indicator for an unlocked lesson with multiple checkpoints',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Stage 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
      StageData(stageNumber: 2, title: 'Stage 2', progress: 0.0, stars: 0, isLocked: true),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyPath(
            stages: stages,
            kingdomEmoji: '🏰',
            kingdomLabel: 'Castle',
            gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
            allowSkipLock: true,
            onSelectLesson: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Checkpoint 2/3'), findsOneWidget);
  });

  testWidgets(
      'shows no checkpoint indicator for a locked node or a single-checkpoint lesson',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Stage 1',
        progress: 1.0,
        stars: 3,
        isLocked: false,
        checkpointIndex: 0,
        checkpointCount: 1,
      ),
      StageData(
        stageNumber: 2,
        title: 'Stage 2',
        progress: 0.0,
        stars: 0,
        isLocked: true,
        checkpointIndex: 2,
        checkpointCount: 4,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JourneyPath(
            stages: stages,
            kingdomEmoji: '🏰',
            kingdomLabel: 'Castle',
            gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
            allowSkipLock: true,
            onSelectLesson: (_) {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Checkpoint'), findsNothing);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd FlutterSpell_Game
flutter test test/widgets/journey_path_test.dart
```

Expected: FAIL — `Checkpoint 2/3` not found (no indicator is rendered today).

- [ ] **Step 3: Implement the indicator**

In `FlutterSpell_Game/lib/widgets/journey_path.dart`, in the label `Column` (lines 267-292), add a new child right after the `spellDate` conditional block:

```dart
            if (stage.spellDate != null && stage.spellDate!.isNotEmpty)
              Text(
                stage.spellDate!,
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 11,
                  color: DuolingoColors.bodyText.withOpacity(
                    state == NodeState.locked ? 0.4 : 0.8,
                  ),
                ),
              ),
            if (stage.checkpointCount > 1 && state != NodeState.locked)
              Text(
                'Checkpoint ${stage.checkpointIndex + 1}/${stage.checkpointCount}',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 10,
                  color: DuolingoColors.bodyText.withOpacity(0.8),
                ),
              ),
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd FlutterSpell_Game
flutter test test/widgets/journey_path_test.dart
```

Expected: PASS (all tests in the file, including the 5 pre-existing ones).

- [ ] **Step 5: Wire checkpoint data through both kingdom screens**

In `FlutterSpell_Game/lib/screens/english_castle_screen.dart`, add two fields to the `StageData(...)` construction (lines 60-67):

```dart
          StageData(
            stageNumber: i + 1,
            title: _lessons[i].displayName,
            progress: _lessons[i].masteryPct,
            stars: _lessons[i].stars,
            isLocked: _lessons[i].status == 'locked',
            spellDate: _lessons[i].spellDate,
            checkpointIndex: _lessons[i].checkpointIndex,
            checkpointCount: _lessons[i].checkpointCount,
          ),
```

Make the identical change in `FlutterSpell_Game/lib/screens/chinese_kingdom_screen.dart` (same lines 60-67).

- [ ] **Step 6: Run the full frontend test suite**

```bash
cd FlutterSpell_Game
flutter analyze
flutter test
```

Expected: no new `flutter analyze` issues; `flutter test` passes with no regressions anywhere in the suite.

- [ ] **Step 7: Commit**

```bash
git add FlutterSpell_Game/lib/widgets/journey_path.dart FlutterSpell_Game/lib/screens/english_castle_screen.dart FlutterSpell_Game/lib/screens/chinese_kingdom_screen.dart FlutterSpell_Game/test/widgets/journey_path_test.dart
git commit -m "feat: show a checkpoint indicator on World Map lesson nodes"
```

---

## Final Verification (manual, after all tasks)

- [ ] Start the backend and both frontends via `restart-dev.bat` (repo root) against the real local `database/db.sqlite3`, confirming the `fail_count` migration (Task 3) applies cleanly to the existing database on startup with no errors in the backend console.
- [ ] In FlutterSpell_Game (Chrome, port 8080): open a lesson with more than 5 words, expand "Show word-by-word progress" on Lesson Overview, and confirm the grid is split into "Checkpoint 1", "Checkpoint 2", etc., with chunks beyond the current checkpoint shown grey regardless of any prior mastery data.
- [ ] Start a study session on that lesson and confirm only the current checkpoint's words appear (checkpoint 1 = first 5 words by id).
- [ ] Answer all of checkpoint 1's words correctly enough to hit 5-in-a-row each (or seed `ReviewState` rows directly for speed), reload the Lesson Overview screen, and confirm checkpoint 2 is now the current checkpoint — both in the word grid and in a freshly-started study session.
- [ ] On the World Map, confirm the lesson's node shows a "Checkpoint N/M" label that matches the Lesson Overview screen, and that a fully-locked lesson (not yet reached) shows no checkpoint label.
- [ ] Deliberately fail the same word a few times in a row (quality 0/1), then in a later session confirm it appears earlier in the practice queue than a word with a lower `fail_count`.
