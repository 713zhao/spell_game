# Lesson Mastery Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Raise the lesson-unlock threshold from 80% to 100% mastery (fixing the existing World-Map-checkmark/unlock mismatch as a side effect), and make mastery visible via a progress ring on World Map nodes and a mastery bar + explanation + per-word breakdown on the Lesson Overview screen.

**Architecture:** A two-line backend threshold change (no API shape change). Two frontend additions that both reuse data already flowing to the client — `LessonSummary.masteryPct` for the ring/bar, and the Lesson Overview screen's own `gameProvider.deckCards` (already fetched there) for the per-word list, once its fetch limit is corrected to cover the whole lesson instead of the default page size.

**Tech Stack:** FastAPI/SQLModel (backend), Flutter/Dart with the `provider` package (frontend) — no new dependencies.

**Spec:** `docs/superpowers/specs/2026-07-27-lesson-mastery-visibility-design.md`

---

## Important context for whoever implements this

- Backend working directory: `C:\ZJB\archive\spell\SpellBackend`. Run tests with `python -m pytest tests/ -v`, or a single file with `python -m pytest tests/test_lesson_manager.py -v`.
- Frontend working directory: `C:\ZJB\archive\spell\FlutterSpell_Game`. Run tests with `flutter test`, analyze with `flutter analyze`.
- This repo already has 7 known pre-existing, unrelated test failures (1 in `game_provider_test.dart`, 6 in `home_screen_test.dart`) from before this plan — don't try to fix them, just confirm your changes don't add to that count.
- **Two different, deliberate testing strategies are used in this plan** — read this before writing any test:
  - `journey_path.dart` (Task 2) takes `stages: List<StageData>` as a plain constructor argument with no `Provider`/global state involved — test it the normal way, exactly like the existing `test/widgets/journey_path_test.dart` already does (plain `pumpWidget`, no provider setup).
  - `lesson_overview_screen.dart` (Tasks 3-4) is different: like `home.dart`, it reads the **global singleton** `gameProvider` (`import '../main.dart' show gameProvider;`), not `Provider.of<GameProvider>(context)`/`Consumer`. This means the standard `FakeGameProvider` + `ChangeNotifierProvider.value` injection pattern used elsewhere in this test suite **would silently not work** here — the widget would ignore the injected fake and read the real global instead. (This is exactly why `home_screen_test.dart` has 6 failing/ineffective tests today — same root cause, pre-existing, out of scope to fix here.) Instead, tests for `lesson_overview_screen.dart` **directly set fields on the real global `gameProvider`** (e.g. `gameProvider.deckCards = [...]`) before pumping the widget, and reset it in `tearDown` so state doesn't leak between tests. `initState` will still fire a real, un-awaited `gameProvider.loadDeck(...)` network call in the background when the widget is pumped — this is safe to ignore in tests: on success it would overwrite `deckCards` with (in a test/CI environment) an empty or error result *after* your assertions already ran against a single `tester.pump()` (not `pumpAndSettle()`, which would hang waiting on it); on failure (the likely case with no reachable backend in a test run) `GameProvider.loadDeck`'s catch block only sets `errorMessage` and never touches `deckCards`, so your pre-set value survives untouched either way. **Never use `pumpAndSettle()` on this screen's tests** for the same reason `journey_path_test.dart` avoids it (an unresolvable in-flight future) — use `tester.pump()` plus a bounded extra `tester.pump(const Duration(milliseconds: ...))` if a transition/dialog needs a frame to settle.

---

### Task 1: Raise the backend unlock/star threshold to 100%

**Files:**
- Modify: `src/services/lesson_manager.py`
- Test: `tests/test_lesson_manager.py` (create)

- [ ] **Step 1: Write the failing tests**

Create `tests/test_lesson_manager.py`:

```python
import pytest
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool

from src.services.lesson_manager import LessonManager
from src.models.user import User
from src.models.tag import Tag
from src.models.word import SpellingWord
from src.models.link import WordTagLink
from src.models.review_state import ReviewState


@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    from src.models import user, tag, word, link, review_state  # noqa: F401
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


def _make_lesson(session, user, tag_str, grade, subject, word_texts, reps_by_word):
    """Creates a P{grade}::{subject}::{tag_str} tag with len(word_texts) words,
    each linked via WordTagLink, and a ReviewState for `user` giving each word
    `reps_by_word[i]` repetitions (0 if not listed). Returns the list of
    created word ids, in the same order as `word_texts`, so callers can
    target a specific word afterward without re-querying."""
    tag = Tag(tag=f"T::P{grade}::{subject}::{tag_str}", created_by="1")
    session.add(tag)
    session.commit()
    session.refresh(tag)

    word_ids = []
    for i, text in enumerate(word_texts):
        w = SpellingWord(text=text, language="english", created_by="1")
        session.add(w)
        session.commit()
        session.refresh(w)
        session.add(WordTagLink(word_id=w.id, tag_id=tag.id))
        reps = reps_by_word[i] if i < len(reps_by_word) else 0
        if reps:
            session.add(ReviewState(user_name=user.name, word_id=w.id, repetitions=reps))
        word_ids.append(w.id)
    session.commit()
    return word_ids


def test_lesson_at_80_percent_is_not_completed(session: Session):
    """4 of 5 words fully mastered (reps=5), 1 word untouched (reps=0) ->
    mastery_pct == 0.8, which must NOT unlock the next lesson or award 3 stars
    under the new 100%-required rule."""
    user = User(name="TESTUSER", grade="P1")
    session.add(user)
    session.commit()
    session.refresh(user)

    _make_lesson(session, user, "Week1", 1, "EN",
                 ["a", "b", "c", "d", "e"], [5, 5, 5, 5, 0])

    manager = LessonManager(session)
    lessons = manager.list_lessons_for_user(user, "EN")

    assert len(lessons) == 1
    assert lessons[0]["mastery_pct"] == 0.8
    assert lessons[0]["status"] == "current"
    assert lessons[0]["stars"] == 2


def test_lesson_at_100_percent_is_completed_with_3_stars(session: Session):
    """All words fully mastered -> mastery_pct == 1.0, status completed, 3 stars."""
    user = User(name="TESTUSER", grade="P1")
    session.add(user)
    session.commit()
    session.refresh(user)

    _make_lesson(session, user, "Week1", 1, "EN",
                 ["a", "b", "c", "d", "e"], [5, 5, 5, 5, 5])

    manager = LessonManager(session)
    lessons = manager.list_lessons_for_user(user, "EN")

    assert lessons[0]["mastery_pct"] == 1.0
    assert lessons[0]["status"] == "completed"
    assert lessons[0]["stars"] == 3


def test_second_lesson_unlocks_only_once_first_hits_100_percent(session: Session):
    """With two lessons, the second must stay 'locked' while the first is at
    80% (previously enough to unlock it), and become 'current' once the first
    reaches 100%."""
    user = User(name="TESTUSER", grade="P1")
    session.add(user)
    session.commit()
    session.refresh(user)

    week1_word_ids = _make_lesson(session, user, "Week1", 1, "EN",
                                   ["a", "b", "c", "d", "e"], [5, 5, 5, 5, 0])  # 80%
    _make_lesson(session, user, "Week2", 1, "EN",
                 ["f", "g"], [])  # untouched

    manager = LessonManager(session)
    lessons = manager.list_lessons_for_user(user, "EN")

    by_key = {l["lesson_key"]: l for l in lessons}
    assert by_key["Week1"]["status"] == "current"
    assert by_key["Week2"]["status"] == "locked"

    # Bump the 5th word ("e") in Week1 up to full mastery -> Week1 hits 100%.
    session.add(ReviewState(user_name=user.name, word_id=week1_word_ids[4], repetitions=5))
    session.commit()

    lessons2 = manager.list_lessons_for_user(user, "EN")
    by_key2 = {l["lesson_key"]: l for l in lessons2}
    assert by_key2["Week1"]["status"] == "completed"
    assert by_key2["Week2"]["status"] == "current"
```

- [ ] **Step 2: Run to verify the first two tests fail**

Run: `python -m pytest tests/test_lesson_manager.py -v`
Expected: `test_lesson_at_80_percent_is_not_completed` and `test_second_lesson_unlocks_only_once_first_hits_100_percent` FAIL (current code unlocks/completes at 0.8). `test_lesson_at_100_percent_is_completed_with_3_stars` should already PASS (1.0 satisfies both the old and new threshold) — that's expected, it's a sanity check, not evidence of a red step for that one.

- [ ] **Step 3: Raise the threshold**

In `src/services/lesson_manager.py`, change line 244 (`if mastery_pct >= 0.8:`) and the `stars` block at lines 252-256:

```python
            if mastery_pct >= 1.0:
                status = "completed"
            elif not first_incomplete_found:
                status = "current"
                first_incomplete_found = True
            else:
                status = "locked"

            stars = (
                3 if mastery_pct >= 1.0 else
                2 if mastery_pct >= 0.5 else
                1 if mastery_pct > 0 else 0
            )
```

- [ ] **Step 4: Run to verify all three pass**

Run: `python -m pytest tests/test_lesson_manager.py -v`
Expected: 3 passed.

- [ ] **Step 5: Run the full backend suite**

Run: `python -m pytest tests/ -v`
Expected: no new failures beyond whatever pre-existing state the suite was already in (this file's tests are new and isolated; nothing else imports `lesson_manager.py`'s thresholds).

- [ ] **Step 6: Commit**

```bash
git add src/services/lesson_manager.py tests/test_lesson_manager.py
git commit -m "feat: require 100% mastery to unlock the next lesson"
```

---

### Task 2: Mastery ring on World Map lesson nodes

**Files:**
- Modify: `lib/widgets/journey_path.dart`
- Test: `test/widgets/journey_path_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/widgets/journey_path_test.dart` (inside `void main() { ... }`, after the existing three `testWidgets`):

```dart
  testWidgets('a partially-mastered current node shows a progress ring matching its progress',
      (tester) async {
    final stages = [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 0.6, stars: 1, isLocked: false),
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

    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, 0.6);
  });

  testWidgets('a locked node shows no progress ring', (tester) async {
    final stages = [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 1.0, stars: 3, isLocked: false),
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

    // Only the completed node (stage 1) should have a ring; the locked
    // node (stage 2) must not.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
```

- [ ] **Step 2: Run to verify both fail**

Run: `flutter test test/widgets/journey_path_test.dart`
Expected: FAIL — `CircularProgressIndicator` doesn't exist in the tree yet.

- [ ] **Step 3: Add the ring to `_LessonNode`**

In `lib/widgets/journey_path.dart`, update the `_LessonNode` instantiation (in `_buildItemWidgets`, currently around line 242-246) to pass `progress`:

```dart
        child: _LessonNode(
          state: state,
          progress: stage.progress,
          pulse: _pulseController,
          onTap: () => _handleNodeTap(index),
        ),
```

Update the `_LessonNode` class itself (currently lines 315-324) to accept and use it:

```dart
class _LessonNode extends StatelessWidget {
  final NodeState state;
  final double progress;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _LessonNode({
    required this.state,
    required this.progress,
    required this.pulse,
    required this.onTap,
  });
```

In `_LessonNode.build` (currently starting at line 326), wrap the existing `node` `Container` in a `Stack` that draws the ring behind it when the node isn't locked. Replace the `Widget node = Container(...)` block (currently lines 357-370) with:

```dart
    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 3),
        boxShadow: [
          BoxShadow(color: border, offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      alignment: Alignment.center,
      child: icon,
    );

    if (state != NodeState.locked) {
      node = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size + 10,
            height: size + 10,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: DuolingoColors.secondaryButtonGray.withOpacity(0.4),
              valueColor: const AlwaysStoppedAnimation<Color>(DuolingoColors.primaryGreen),
            ),
          ),
          node,
        ],
      );
    }
```

- [ ] **Step 4: Run to verify both pass**

Run: `flutter test test/widgets/journey_path_test.dart`
Expected: PASS (5 tests: the original 3 plus these 2).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/journey_path.dart test/widgets/journey_path_test.dart
git commit -m "feat: show a mastery progress ring on World Map lesson nodes"
```

---

### Task 3: Mastery bar + explanation on Lesson Overview

**Files:**
- Modify: `lib/screens/lesson_overview_screen.dart`
- Test: `test/screens/lesson_overview_screen_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

Create `test/screens/lesson_overview_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/main.dart' show gameProvider;
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/screens/lesson_overview_screen.dart';

LessonSummary _lesson({required double masteryPct, required int wordCount}) {
  return LessonSummary(
    lessonKey: 'Week1',
    displayName: 'Week 1',
    labelType: 'TEACHER',
    tags: const ['T::P1::EN::Week1'],
    skills: const [],
    wordCount: wordCount,
    masteryPct: masteryPct,
    stars: masteryPct >= 1.0 ? 3 : (masteryPct >= 0.5 ? 2 : (masteryPct > 0 ? 1 : 0)),
    status: masteryPct >= 1.0 ? 'completed' : 'current',
  );
}

Widget _screen(LessonSummary lesson) {
  return MaterialApp(
    home: LessonOverviewScreen(
      args: LessonOverviewArgs(lesson: lesson, subject: 'EN'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // lesson_overview_screen.dart reads the global `gameProvider` singleton
    // directly rather than via Provider injection - reset its consumed
    // fields before each test so state doesn't leak between tests.
    gameProvider.deckCards = [];
    gameProvider.errorMessage = null;
  });

  testWidgets('shows the mastery percentage and the 100% unlock hint',
      (tester) async {
    await tester.pumpWidget(_screen(_lesson(masteryPct: 0.73, wordCount: 12)));
    await tester.pump();

    expect(find.textContaining('73%'), findsOneWidget);
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('tapping the info icon explains the reset rule', (tester) async {
    await tester.pumpWidget(_screen(_lesson(masteryPct: 0.5, wordCount: 4)));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('a mistake resets that word to 0'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run to verify both fail**

Run: `flutter test test/screens/lesson_overview_screen_test.dart`
Expected: FAIL — no mastery text or info icon exist yet.

- [ ] **Step 3: Bump the deck fetch limit and add the mastery bar + info icon**

In `lib/screens/lesson_overview_screen.dart`, update `initState` (currently lines 79-84) to fetch the whole lesson's words, not just the default page of 10 (this also makes the existing `newWords`/estimated-time calculation below accurate for lessons with more than 10 words, which it wasn't before):

```dart
  @override
  void initState() {
    super.initState();
    gameProvider.addListener(_onChanged);
    gameProvider.loadDeck(
      tags: widget.args.lesson.tags,
      limit: widget.args.lesson.wordCount,
    );
  }
```

Add a helper method to `_LessonOverviewScreenState`, right after `_onChanged` (after its closing `}`, before `dispose`):

```dart
  void _showResetRuleInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How mastery works'),
        content: const Text(
          'Each word needs 5 correct answers in a row. '
          'A mistake resets that word to 0 - that\'s why it can '
          'feel like starting over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
```

In `build()`, insert a mastery card right after the "Info row: words + time" block (after its closing `SizedBox(height: DuolingoSpacing.xl),` at what's currently line 198, before the "// Rewards" comment):

```dart
              // Mastery
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  color: DuolingoColors.neutralGray,
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mastery: ${(lesson.masteryPct * 100).round()}%',
                          style: DuolingoTextStyles.label.copyWith(
                            color: DuolingoColors.darkText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: _showResetRuleInfo,
                          child: const Icon(Icons.info_outline, size: 18),
                        ),
                      ],
                    ),
                    SizedBox(height: DuolingoSpacing.xs),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: lesson.masteryPct.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: DuolingoColors.backgroundWhite,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            DuolingoColors.primaryGreen),
                      ),
                    ),
                    SizedBox(height: DuolingoSpacing.xs),
                    Text(
                      '100% needed to unlock the next lesson',
                      style: DuolingoTextStyles.label.copyWith(
                        color: DuolingoColors.bodyText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),

```

- [ ] **Step 4: Run to verify both pass**

Run: `flutter test test/screens/lesson_overview_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/lesson_overview_screen.dart test/screens/lesson_overview_screen_test.dart
git commit -m "feat: show mastery bar and reset-rule explanation on Lesson Overview"
```

---

### Task 4: Tap-to-expand per-word progress grid

**Files:**
- Modify: `lib/screens/lesson_overview_screen.dart`
- Test: `test/screens/lesson_overview_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Add to `test/screens/lesson_overview_screen_test.dart` (inside `main()`, after the existing two tests). This needs `DeckCard`/`Word` - add `import 'package:spell_game/models/game_models.dart';` if not already present (it already is, for `LessonSummary`).

```dart
  testWidgets('word detail is hidden until expanded, then shows mastery-colored chips',
      (tester) async {
    gameProvider.deckCards = [
      DeckCard(word: Word(id: 1, text: 'apple', language: 'english'), repetitions: 5, status: 'review'),
      DeckCard(word: Word(id: 2, text: 'banana', language: 'english'), repetitions: 2, status: 'learning'),
      DeckCard(word: Word(id: 3, text: 'cherry', language: 'english'), repetitions: 0, status: 'new'),
    ];

    await tester.pumpWidget(_screen(_lesson(masteryPct: 0.4, wordCount: 3)));
    await tester.pump();

    expect(find.text('apple'), findsNothing);

    await tester.tap(find.textContaining('word-by-word'));
    await tester.pump();

    expect(find.text('apple'), findsOneWidget);
    expect(find.text('banana'), findsOneWidget);
    expect(find.text('cherry'), findsOneWidget);
  });

  testWidgets('collapsing word detail hides the chips again', (tester) async {
    gameProvider.deckCards = [
      DeckCard(word: Word(id: 1, text: 'apple', language: 'english'), repetitions: 5, status: 'review'),
    ];

    await tester.pumpWidget(_screen(_lesson(masteryPct: 1.0, wordCount: 1)));
    await tester.pump();

    await tester.tap(find.textContaining('word-by-word'));
    await tester.pump();
    expect(find.text('apple'), findsOneWidget);

    await tester.tap(find.textContaining('word-by-word'));
    await tester.pump();
    expect(find.text('apple'), findsNothing);
  });
```

- [ ] **Step 2: Run to verify both fail**

Run: `flutter test test/screens/lesson_overview_screen_test.dart`
Expected: FAIL — no "word-by-word" toggle exists yet.

- [ ] **Step 3: Add the toggle and chip grid**

Add a state field to `_LessonOverviewScreenState`, right after the class declaration's opening (before `initState`):

```dart
class _LessonOverviewScreenState extends State<LessonOverviewScreen> {
  bool _showWordDetail = false;

  @override
  void initState() {
```

Add a chip-color helper and the grid-building method right after `_showResetRuleInfo` (after its closing `}`, before `dispose`):

```dart
  Color _masteryChipColor(int repetitions) {
    if (repetitions >= 5) return DuolingoColors.primaryGreen;
    if (repetitions >= 1) return const Color(0xFFFFC107);
    return DuolingoColors.secondaryButtonGray;
  }

  Widget _buildWordDetailGrid() {
    if (gameProvider.deckCards.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: DuolingoSpacing.sm),
        child: Text(
          'Loading word details...',
          style: DuolingoTextStyles.label
              .copyWith(color: DuolingoColors.bodyText, fontSize: 11),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: DuolingoSpacing.sm),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: gameProvider.deckCards.map((card) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _masteryChipColor(card.repetitions),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              card.word.text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          );
        }).toList(),
      ),
    );
  }
```

In `build()`, add the toggle text and conditional grid right after the "100% needed to unlock the next lesson" `Text` widget added in Task 3 (inside the same mastery `Container`'s `Column`, as its last child before the closing `],`):

```dart
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showWordDetail = !_showWordDetail),
                      child: Padding(
                        padding: EdgeInsets.only(top: DuolingoSpacing.xs),
                        child: Text(
                          _showWordDetail
                              ? 'Hide word-by-word progress \u25b4'
                              : 'Show word-by-word progress \u25be',
                          style: DuolingoTextStyles.label.copyWith(
                            color: DuolingoColors.informationBlue,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    if (_showWordDetail) _buildWordDetailGrid(),
```

- [ ] **Step 4: Run to verify all pass**

Run: `flutter test test/screens/lesson_overview_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full frontend suite**

Run: `flutter test`
Expected: no new failures beyond the 7 pre-existing/unrelated ones.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/lesson_overview_screen.dart test/screens/lesson_overview_screen_test.dart
git commit -m "feat: add tap-to-expand per-word mastery grid to Lesson Overview"
```

---

### Task 5: Manual verification

**Files:** none (verification only)

- [ ] **Step 1: Analyze both projects**

Run (from `SpellBackend`): confirm no Python syntax/import errors introduced (no dedicated lint step in this repo beyond the tests themselves).
Run (from `FlutterSpell_Game`): `flutter analyze`
Expected: no new errors.

- [ ] **Step 2: Deploy the backend threshold change**

From `SpellBackend`: commit is already made in Task 1. Deploy per this repo's established process (`flyctl deploy`), then verify:

```bash
curl -s "https://spellbackend.fly.dev/lessons/<a real user with a partially-mastered lesson>?subject=EN"
```
Expected: a lesson previously at e.g. 80-99% mastery now shows `"status": "current"` (not `"completed"`) and `"stars": 2` (not 3).

- [ ] **Step 3: Build and serve the frontend locally**

```bash
cd FlutterSpell_Game
flutter build web --release --dart-define=API_BASE_URL=https://spellbackend.fly.dev
cd build/web
python -m http.server 8097
```

- [ ] **Step 4: Click through it live**

Log in as a real user with at least one partially-studied lesson (e.g. ERIC or HELLEN). Confirm:
- World Map: a lesson node with partial progress shows a visible ring around it; a locked node shows no ring; a fully-mastered node's ring is full and still shows its checkmark.
- Lesson Overview: opening a partially-mastered lesson shows "Mastery: N%" with a matching bar fill and "100% needed to unlock the next lesson."
- Tapping the (i) icon shows the reset-rule explanation dialog.
- Tapping "Show word-by-word progress" reveals colored word chips (green/yellow/grey) matching each word's actual state; tapping again hides them.
- Stop the local server afterward (`taskkill //F //PID <pid>` for whatever's bound to port 8097).

- [ ] **Step 5: Report back**

No commit for this task — verification only. Report pass/fail and any visual issues before considering this plan done.
