# Study Exercises Easy Wins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a typed Sentence Fill-in exercise and a Meaning Matching quiz exercise (both powered by `back_card`/`quiz` data already sitting unused in the database), and make Chinese handwriting practice gated by the lesson's `write` skill tag instead of SRS mastery so it's actually reachable in a single study session.

**Architecture:** One backend field (`quiz`) starts flowing through the existing deck endpoint. Two new pure Dart parsing functions turn that raw data into exercise content. `study.dart`'s exercise-type ladder and queue-construction logic route to two new `ExerciseType` values when that content is available, falling back to today's behavior otherwise. A small `correctAnswer` field on `_Exercise` (plus a `_targetAnswer` getter) lets grading and answer-highlighting work for an exercise whose correct answer isn't the word's own spelling.

**Tech Stack:** FastAPI + SQLModel (backend), Flutter web + `flutter_test` (frontend).

Spec: `docs/superpowers/specs/2026-07-15-study-exercises-easy-wins-design.md`

---

### Task 1: Backend — send `quiz` through the deck endpoint

**Files:**
- Modify: `SpellBackend/src/services/deck_builder.py`
- Test: `SpellBackend/tests/test_deck_builder.py` (new file)

- [x] **Step 1: Write the failing test**

Create `SpellBackend/tests/test_deck_builder.py`:

```python
import pytest
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool
from src.services.deck_builder import DeckBuilder
from src.models.user import User
from src.models.word import SpellingWord
from src.models.tag import Tag
from src.models.link import UserTagsLink, WordTagLink


@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session


def _make_user_with_word(session: Session, quiz: str | None):
    user = User(name="TESTUSER", grade="P3")
    session.add(user)
    session.commit()
    session.refresh(user)

    tag = Tag(tag="TEST::P3::EN::Week1", created_by="admin")
    session.add(tag)
    session.commit()
    session.refresh(tag)

    word = SpellingWord(text="apple", language="english", quiz=quiz)
    session.add(word)
    session.commit()
    session.refresh(word)

    session.add(UserTagsLink(user_id=user.id, tag_id=tag.id))
    session.add(WordTagLink(word_id=word.id, tag_id=tag.id))
    session.commit()
    return user, word


def test_build_daily_deck_includes_quiz_field(session: Session):
    quiz_json = '{"question":"What is an apple?","options":["A fruit","A car"],"correct":0}'
    _make_user_with_word(session, quiz_json)

    builder = DeckBuilder(session)
    cards, empty_reason = builder.build_daily_deck("TESTUSER", limit=10)

    assert empty_reason == ""
    assert len(cards) == 1
    assert cards[0]["quiz"] == quiz_json


def test_build_daily_deck_quiz_field_defaults_to_none(session: Session):
    _make_user_with_word(session, None)

    builder = DeckBuilder(session)
    cards, _ = builder.build_daily_deck("TESTUSER", limit=10)

    assert cards[0]["quiz"] is None
```

- [x] **Step 2: Run test to verify it fails**

Run (from `SpellBackend/`): `python -m pytest tests/test_deck_builder.py -v`
Expected: FAIL — `KeyError: 'quiz'` on the assertion, since the card dict doesn't have a `"quiz"` key yet.

- [x] **Step 3: Add the `quiz` field to both card-building loops**

In `SpellBackend/src/services/deck_builder.py`, the overdue-words loop currently reads:

```python
        for w, st in overdue:
            if len(cards) >= limit:
                break
            cards.append({
                "word_id": w.id,
                "text": w.text,
                "language": w.language,
                "back_card": w.back_card,
                "state": {
                    "repetitions": st.repetitions,
                    "interval_days": st.interval_days,
                    "ease_factor": st.ease_factor,
                    "due_date": (st.due_date or today).isoformat(),
                }
            })
```

Change the `"back_card": w.back_card,` line to also include `quiz`:

```python
                "back_card": w.back_card,
                "quiz": w.quiz,
```

And the new-words loop currently reads:

```python
        if len(cards) < limit:
            for w, _ in new_words:
                if len(cards) >= limit:
                    break
                cards.append({
                    "word_id": w.id,
                    "text": w.text,
                    "language": w.language,
                    "back_card": w.back_card,
                    "state": {
                        "repetitions": 0,
                        "interval_days": 0,
                        "ease_factor": 2.5,
                        "due_date": today.isoformat(),
                        "status": "new"
                    }
                })
```

Same change — add `"quiz": w.quiz,` right after `"back_card": w.back_card,`.

- [x] **Step 4: Run test to verify it passes**

Run: `python -m pytest tests/test_deck_builder.py -v`
Expected: PASS (2 tests)

- [x] **Step 5: Commit**

```bash
git add src/services/deck_builder.py tests/test_deck_builder.py
git commit -m "feat: include quiz field in daily deck cards"
```

---

### Task 2: Frontend — `Word` model carries `backCard`/`quiz`, `api_client` parses them

**Files:**
- Modify: `FlutterSpell_Game/lib/models/game_models.dart`
- Modify: `FlutterSpell_Game/lib/services/api_client.dart`

- [x] **Step 1: Add the two optional fields to `Word`**

In `FlutterSpell_Game/lib/models/game_models.dart`, the `Word` class currently reads:

```dart
@JsonSerializable()
class Word {
  final int id;
  final String text;
  final String language;

  Word({
    required this.id,
    required this.text,
    required this.language,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
  Map<String, dynamic> toJson() => _$WordToJson(this);
}
```

Change it to:

```dart
@JsonSerializable()
class Word {
  final int id;
  final String text;
  final String language;
  final String? backCard;
  final String? quiz;

  Word({
    required this.id,
    required this.text,
    required this.language,
    this.backCard,
    this.quiz,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
  Map<String, dynamic> toJson() => _$WordToJson(this);
}
```

`backCard`/`quiz` are optional named parameters, so the generated `_$WordFromJson`/`_$WordToJson` in `game_models.g.dart` (which doesn't know about these two fields) keeps compiling unchanged — it just won't populate them when parsing `Level.words` JSON from the levels endpoint, which is fine since that endpoint doesn't send this data anyway.

- [x] **Step 2: Pass the fields through in `getDeckCards()`**

In `FlutterSpell_Game/lib/services/api_client.dart`, `getDeckCards()` currently builds each card's `Word` as:

```dart
        return DeckCard(
          word: Word(
            id: c['word_id'] as int,
            text: c['text'] as String,
            language: (c['language'] ?? 'english') as String,
          ),
          repetitions: (state['repetitions'] ?? 0) as int,
          status: (state['status'] ?? 'new') as String,
        );
```

Change the `Word(...)` construction to:

```dart
        return DeckCard(
          word: Word(
            id: c['word_id'] as int,
            text: c['text'] as String,
            language: (c['language'] ?? 'english') as String,
            backCard: c['back_card'] as String?,
            quiz: c['quiz'] as String?,
          ),
          repetitions: (state['repetitions'] ?? 0) as int,
          status: (state['status'] ?? 'new') as String,
        );
```

- [x] **Step 3: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/models/game_models.dart lib/services/api_client.dart --no-fatal-infos`
Expected: no `error` lines (info/style lints are fine).

- [x] **Step 4: Commit**

```bash
git add lib/models/game_models.dart lib/services/api_client.dart
git commit -m "feat: carry back_card/quiz through Word and the deck API client"
```

---

### Task 3: Frontend — exercise content parser (Sentence Fill-in + Meaning Matching data)

**Files:**
- Create: `FlutterSpell_Game/lib/utils/exercise_content_parser.dart`
- Test: `FlutterSpell_Game/test/utils/exercise_content_parser_test.dart`

- [x] **Step 1: Write the failing test**

Create `FlutterSpell_Game/test/utils/exercise_content_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/utils/exercise_content_parser.dart';

void main() {
  group('parseSentenceBlank', () {
    test('blanks the target word out of the Example sentence', () {
      final word = Word(
        id: 1,
        text: 'photosynthesis',
        language: 'english',
        backCard: 'memorization tip: tip text\n'
            'Explanation: some explanation\n'
            'Similar words: a, b, c\n'
            'Example: Photosynthesis is essential for life on Earth.',
      );

      final blanked = parseSentenceBlank(word);

      expect(blanked, '_____ is essential for life on Earth.');
    });

    test('returns null when there is no back_card', () {
      final word = Word(id: 1, text: 'apple', language: 'english');
      expect(parseSentenceBlank(word), isNull);
    });

    test('returns null when there is no Example line', () {
      final word = Word(
        id: 1,
        text: 'apple',
        language: 'english',
        backCard: 'memorization tip: tip text\nExplanation: some text',
      );
      expect(parseSentenceBlank(word), isNull);
    });

    test('returns null when the word is not present in the example sentence', () {
      final word = Word(
        id: 1,
        text: 'apple',
        language: 'english',
        backCard: 'Example: Oranges are tasty too.',
      );
      expect(parseSentenceBlank(word), isNull);
    });
  });

  group('parseQuiz', () {
    test('parses a well-formed quiz JSON string', () {
      final quizData = parseQuiz(
        '{"question":"What does it mean?","options":["A","B","C"],"correct":1}',
      );

      expect(quizData, isNotNull);
      expect(quizData!.question, 'What does it mean?');
      expect(quizData.options, ['A', 'B', 'C']);
      expect(quizData.correctOption, 'B');
    });

    test('returns null for null input', () {
      expect(parseQuiz(null), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(parseQuiz('not json'), isNull);
    });

    test('returns null when correct index is out of range', () {
      expect(
        parseQuiz('{"question":"Q","options":["A","B"],"correct":5}'),
        isNull,
      );
    });
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run (from `FlutterSpell_Game/`): `flutter test test/utils/exercise_content_parser_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'spell_game/utils/exercise_content_parser.dart'` (file doesn't exist yet).

- [x] **Step 3: Write the parser**

Create `FlutterSpell_Game/lib/utils/exercise_content_parser.dart`:

```dart
import 'dart:convert';
import '../models/game_models.dart';

/// Pulls the `Example: <sentence>` line out of a word's `back_card` text
/// and blanks out the target word, for the Sentence Fill-in exercise.
/// Returns null when there's no back_card, no Example line, or the word
/// doesn't actually appear in that sentence — callers should fall back to
/// a different exercise type in every null case.
String? parseSentenceBlank(Word word) {
  final backCard = word.backCard;
  if (backCard == null) return null;

  final exampleMatch = RegExp(
    r'Example:\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(backCard);
  if (exampleMatch == null) return null;

  final sentence = exampleMatch.group(1)!.trim();
  final wordPattern = RegExp(
    r'\b' + RegExp.escape(word.text) + r'\b',
    caseSensitive: false,
  );
  if (!wordPattern.hasMatch(sentence)) return null;

  return sentence.replaceFirst(wordPattern, '_____');
}

/// A parsed Meaning Matching quiz question for one word.
class QuizData {
  final String question;
  final List<String> options;
  final String correctOption;

  QuizData(this.question, this.options, this.correctOption);
}

/// Parses a word's raw `quiz` JSON string (`{"question","options","correct"}`)
/// into [QuizData]. Returns null for missing/malformed data or an
/// out-of-range correct index — callers should skip the Meaning Matching
/// exercise for that word in every null case.
QuizData? parseQuiz(String? quizJson) {
  if (quizJson == null) return null;
  try {
    final data = jsonDecode(quizJson) as Map<String, dynamic>;
    final options = (data['options'] as List).cast<String>();
    final correctIdx = data['correct'] as int;
    if (correctIdx < 0 || correctIdx >= options.length) return null;
    return QuizData(data['question'] as String, options, options[correctIdx]);
  } catch (_) {
    return null;
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/exercise_content_parser_test.dart`
Expected: PASS (8 tests)

- [x] **Step 5: Commit**

```bash
git add lib/utils/exercise_content_parser.dart test/utils/exercise_content_parser_test.dart
git commit -m "feat: add sentence-blank and quiz parsers for study exercises"
```

---

### Task 4: Frontend — thread lesson `skills` into `StudySessionArgs`

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`

- [x] **Step 1: Add `skills` to `StudySessionArgs`**

In `FlutterSpell_Game/lib/screens/lesson_overview_screen.dart`, `StudySessionArgs` currently reads:

```dart
class StudySessionArgs {
  final List<String> tags;
  final String lessonKey;
  final String displayName;
  final String subject;

  const StudySessionArgs({
    required this.tags,
    required this.lessonKey,
    required this.displayName,
    required this.subject,
  });
}
```

Change it to:

```dart
class StudySessionArgs {
  final List<String> tags;
  final String lessonKey;
  final String displayName;
  final String subject;
  final List<String> skills;

  const StudySessionArgs({
    required this.tags,
    required this.lessonKey,
    required this.displayName,
    required this.subject,
    this.skills = const [],
  });
}
```

- [x] **Step 2: Pass `lesson.skills` when constructing it**

Still in `lesson_overview_screen.dart`, the Start Adventure `onTap` currently builds:

```dart
                    arguments: StudySessionArgs(
                      tags: lesson.tags,
                      lessonKey: lesson.lessonKey,
                      displayName: lesson.displayName,
                      subject: widget.args.subject,
                    ),
```

Change it to:

```dart
                    arguments: StudySessionArgs(
                      tags: lesson.tags,
                      lessonKey: lesson.lessonKey,
                      displayName: lesson.displayName,
                      subject: widget.args.subject,
                      skills: lesson.skills,
                    ),
```

- [x] **Step 3: Verify it compiles**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/screens/lesson_overview_screen.dart --no-fatal-infos`
Expected: no `error` lines.

- [x] **Step 4: Commit**

```bash
git add lib/screens/lesson_overview_screen.dart
git commit -m "feat: thread lesson skills into StudySessionArgs"
```

---

### Task 5: Frontend — `study.dart` exercise-selection logic (Sentence Fill-in, Meaning Matching, skill-gated handwriting)

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/study.dart`

This task wires the new content into the adaptive exercise queue. No new widgets yet (Task 6) — `_buildExerciseBody`'s switch will temporarily be incomplete between this task and the next, which is fine since both land before the next `flutter build`.

- [x] **Step 1: Add imports and new `ExerciseType` values**

At the top of `FlutterSpell_Game/lib/screens/study.dart`, add this import alongside the existing ones:

```dart
import '../utils/exercise_content_parser.dart';
```

Change the `ExerciseType` enum from:

```dart
enum ExerciseType {
  learn,
  chooseSpelling,
  missingLetters,
  buildWord,
  typeWord,
  // Chinese-specific: single hanzi aren't decomposable into letters, so
  // these replace the letter-tile/typing exercises above for Chinese words.
  listenChoose,
  handwriteTrace,
  voiceRead,
}
```

to:

```dart
enum ExerciseType {
  learn,
  chooseSpelling,
  missingLetters,
  buildWord,
  typeWord,
  // Chinese-specific: single hanzi aren't decomposable into letters, so
  // these replace the letter-tile/typing exercises above for Chinese words.
  listenChoose,
  handwriteTrace,
  voiceRead,
  // English-specific, powered by back_card/quiz data that isn't present
  // for every word — see _parseSentenceBlank/_parseQuiz call sites below.
  sentenceBlank,
  meaningMatch,
}
```

- [x] **Step 2: Add `correctAnswer`/`promptText` to `_Exercise` and a `_targetAnswer` getter**

The `_Exercise` class currently reads:

```dart
class _Exercise {
  final Word word;
  final ExerciseType type;
  final List<String> choices; // chooseSpelling
  final List<String?> slots; // fixed letters; null = blank (letter games)
  final List<String> bank; // tappable letter tiles (letter games)
  final bool isRetry;

  _Exercise({
    required this.word,
    required this.type,
    this.choices = const [],
    this.slots = const [],
    this.bank = const [],
    this.isRetry = false,
  });
}
```

Change it to:

```dart
class _Exercise {
  final Word word;
  final ExerciseType type;
  final List<String> choices; // chooseSpelling, listenChoose, meaningMatch
  final List<String?> slots; // fixed letters; null = blank (letter games)
  final List<String> bank; // tappable letter tiles (letter games)
  final bool isRetry;
  final String? promptText; // meaningMatch's question, sentenceBlank's blanked sentence
  final String? correctAnswer; // overrides word.text as the graded target (meaningMatch only)

  _Exercise({
    required this.word,
    required this.type,
    this.choices = const [],
    this.slots = const [],
    this.bank = const [],
    this.isRetry = false,
    this.promptText,
    this.correctAnswer,
  });
}
```

Then, in `_StudyScreenState`, find the existing `_Exercise get _current => _queue[_index];` line and add a getter right after it:

```dart
  _Exercise get _current => _queue[_index];

  /// The value an answer is graded against. Every exercise type grades
  /// against the word's own spelling except meaningMatch, whose correct
  /// answer is a quiz option's text instead.
  String get _targetAnswer => _current.correctAnswer ?? _current.word.text;
```

- [x] **Step 3: Use `_targetAnswer` instead of `_current.word.text` for grading and highlighting**

In `_check()`, change:

```dart
  void _check() {
    final correct = _current.type == ExerciseType.voiceRead
        // Speech-recognition transcripts can carry extra punctuation/noise
        // around the character, so a lenient contains-check avoids
        // penalizing a correct reading over transcription noise.
        ? (_voiceTranscript ?? '').contains(_current.word.text)
        : _assembledAnswer().toLowerCase() == _current.word.text.toLowerCase();
    _applyResult(correct);
  }
```

to:

```dart
  void _check() {
    final correct = _current.type == ExerciseType.voiceRead
        // Speech-recognition transcripts can carry extra punctuation/noise
        // around the character, so a lenient contains-check avoids
        // penalizing a correct reading over transcription noise.
        ? (_voiceTranscript ?? '').contains(_targetAnswer)
        : _assembledAnswer().toLowerCase() == _targetAnswer.toLowerCase();
    _applyResult(correct);
  }
```

In `_buildChoiceTile(String choice)`, change:

```dart
    final isCorrectChoice =
        choice.toLowerCase() == _current.word.text.toLowerCase();
```

to:

```dart
    final isCorrectChoice = choice.toLowerCase() == _targetAnswer.toLowerCase();
```

In the bottom feedback panel (inside `_buildBottomPanel()`), change:

```dart
                    if (!_wasCorrect)
                      Text(
                        'Correct answer: ${_current.word.text}',
```

to:

```dart
                    if (!_wasCorrect)
                      Text(
                        'Correct answer: $_targetAnswer',
```

(`_buildCharacterChoiceTile`, used only by `listenChoose` for Chinese, keeps comparing against `_current.word.text` directly — Chinese exercises never set `correctAnswer`, so leave that one method alone.)

- [x] **Step 4: Add cases to `_assembledAnswer()` and `_hasAnswer`**

In `_assembledAnswer()`, change:

```dart
  String _assembledAnswer() {
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
        return _selectedChoice ?? '';
      case ExerciseType.typeWord:
        return _typingController.text.trim();
```

to:

```dart
  String _assembledAnswer() {
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
      case ExerciseType.meaningMatch:
        return _selectedChoice ?? '';
      case ExerciseType.typeWord:
      case ExerciseType.sentenceBlank:
        return _typingController.text.trim();
```

In `_hasAnswer`, change:

```dart
  bool get _hasAnswer {
    if (_checked) return false;
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
        return _selectedChoice != null;
      case ExerciseType.typeWord:
        return _typingController.text.trim().isNotEmpty;
```

to:

```dart
  bool get _hasAnswer {
    if (_checked) return false;
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
      case ExerciseType.meaningMatch:
        return _selectedChoice != null;
      case ExerciseType.typeWord:
      case ExerciseType.sentenceBlank:
        return _typingController.text.trim().isNotEmpty;
```

- [x] **Step 5: Add the two new cases to `_buildExercise`**

Find the `_buildExercise` method's switch statement and add two new cases right before the `default:` case:

```dart
      case ExerciseType.meaningMatch:
        final quizData = parseQuiz(word.quiz)!;
        return _Exercise(
          word: word,
          type: type,
          choices: quizData.options,
          promptText: quizData.question,
          correctAnswer: quizData.correctOption,
          isRetry: isRetry,
        );
      case ExerciseType.sentenceBlank:
        return _Exercise(
          word: word,
          type: type,
          promptText: parseSentenceBlank(word)!,
          isRetry: isRetry,
        );
```

(The `!` is safe here because both call sites in `_loadWords`, added in the next step, only pick these exercise types after confirming the parse succeeded.)

- [x] **Step 6: Update `_typeForMastery` to prefer `sentenceBlank` when available**

Change:

```dart
  ExerciseType _typeForMastery(int mastery) {
    if (mastery <= 1) {
      return _random.nextBool()
          ? ExerciseType.chooseSpelling
          : ExerciseType.missingLetters;
    }
    if (mastery <= 3) {
      return _random.nextBool()
          ? ExerciseType.missingLetters
          : ExerciseType.buildWord;
    }
    return _random.nextBool()
        ? ExerciseType.typeWord
        : ExerciseType.buildWord;
  }
```

to:

```dart
  ExerciseType _typeForMastery(int mastery, {required bool hasSentence}) {
    if (mastery <= 1) {
      return _random.nextBool()
          ? ExerciseType.chooseSpelling
          : ExerciseType.missingLetters;
    }
    if (mastery <= 3) {
      return _random.nextBool()
          ? ExerciseType.missingLetters
          : ExerciseType.buildWord;
    }
    if (hasSentence) return ExerciseType.sentenceBlank;
    return _random.nextBool()
        ? ExerciseType.typeWord
        : ExerciseType.buildWord;
  }
```

- [x] **Step 7: Simplify `_typeForMasteryChinese` (handwriting moves out of the mastery ladder)**

Change:

```dart
  /// Adaptive ladder for single Chinese characters: recognition (listen &
  /// choose), then production via tracing, then full recall by reading
  /// aloud. There's no letter-tile equivalent for a single hanzi.
  ExerciseType _typeForMasteryChinese(int mastery) {
    if (mastery <= 1) return ExerciseType.listenChoose;
    if (mastery <= 3) return ExerciseType.handwriteTrace;
    return ExerciseType.voiceRead;
  }
```

to:

```dart
  /// Recognition -> production ladder for the read/listen side of a
  /// Chinese word. Handwriting is handled separately in _loadWords, gated
  /// by the lesson's skill tags rather than mastery, so it doesn't take
  /// multiple sessions to become reachable.
  ExerciseType _typeForMasteryChinese(int mastery) {
    return mastery <= 1 ? ExerciseType.listenChoose : ExerciseType.voiceRead;
  }
```

- [x] **Step 8: Rewrite the queue-construction loop in `_loadWords`**

Find this loop in `_loadWords`:

```dart
      for (final card in cards) {
        if (card.repetitions == 0) {
          _queue.add(_Exercise(word: card.word, type: ExerciseType.learn));
        }
        final isChinese = _isChineseWord(card.word.text);
        final type = isChinese
            ? _typeForMasteryChinese(card.repetitions)
            : _typeForMastery(card.repetitions);
        _queue.add(_buildExercise(card.word, type));
      }
```

Replace it with:

```dart
      for (final card in cards) {
        final isChinese = _isChineseWord(card.word.text);

        if (card.repetitions == 0) {
          _queue.add(_Exercise(word: card.word, type: ExerciseType.learn));
          if (!isChinese && parseQuiz(card.word.quiz) != null) {
            _queue.add(_buildExercise(card.word, ExerciseType.meaningMatch));
          }
        }

        if (isChinese) {
          _queue.add(_buildExercise(
            card.word,
            _typeForMasteryChinese(card.repetitions),
          ));
          final skills = widget.args.skills;
          if (skills.isEmpty || skills.contains('write')) {
            _queue.add(_buildExercise(card.word, ExerciseType.handwriteTrace));
          }
        } else {
          final hasSentence = parseSentenceBlank(card.word) != null;
          final type = _typeForMastery(card.repetitions, hasSentence: hasSentence);
          _queue.add(_buildExercise(card.word, type));
        }
      }
```

- [x] **Step 9: Verify it compiles (widgets for the two new types come in Task 6)**

Run (from `FlutterSpell_Game/`): `flutter analyze lib/screens/study.dart --no-fatal-infos`
Expected: one `error` — a non-exhaustive switch in `_buildExerciseBody()` (missing `sentenceBlank`/`meaningMatch` cases). That's expected here; Task 6 adds them. Confirm there are no *other* errors besides that one.

- [x] **Step 10: Commit**

```bash
git add lib/screens/study.dart
git commit -m "feat: route sentence-blank/meaning-match/skill-gated handwriting into the study queue"
```

---

### Task 6: Frontend — `study.dart` UI for Sentence Fill-in and Meaning Matching

**Files:**
- Modify: `FlutterSpell_Game/lib/screens/study.dart`

- [x] **Step 1: Add the two cases to `_buildExerciseBody()`**

Change:

```dart
  Widget _buildExerciseBody() {
    switch (_current.type) {
      case ExerciseType.learn:
        return _buildLearnCard();
      case ExerciseType.chooseSpelling:
        return _buildChooseSpelling();
      case ExerciseType.missingLetters:
        return _buildLetterGame('Fill in the missing letters');
      case ExerciseType.buildWord:
        return _buildLetterGame('Build the word you hear');
      case ExerciseType.typeWord:
        return _buildTypeWord();
      case ExerciseType.listenChoose:
        return _buildListenChoose();
      case ExerciseType.handwriteTrace:
        return _buildHandwriteTrace();
      case ExerciseType.voiceRead:
        return _buildVoiceRead();
    }
  }
```

to:

```dart
  Widget _buildExerciseBody() {
    switch (_current.type) {
      case ExerciseType.learn:
        return _buildLearnCard();
      case ExerciseType.chooseSpelling:
        return _buildChooseSpelling();
      case ExerciseType.missingLetters:
        return _buildLetterGame('Fill in the missing letters');
      case ExerciseType.buildWord:
        return _buildLetterGame('Build the word you hear');
      case ExerciseType.typeWord:
        return _buildTypeWord();
      case ExerciseType.listenChoose:
        return _buildListenChoose();
      case ExerciseType.handwriteTrace:
        return _buildHandwriteTrace();
      case ExerciseType.voiceRead:
        return _buildVoiceRead();
      case ExerciseType.sentenceBlank:
        return _buildSentenceBlank();
      case ExerciseType.meaningMatch:
        return _buildMeaningMatch();
    }
  }
```

- [x] **Step 2: Add `_buildSentenceBlank()` and `_buildMeaningMatch()` widgets**

Find the `// --- Listen & Type ---` section (the `_buildTypeWord()` method) and add these two new methods right after it:

```dart
  // --- Sentence Fill-in (type the missing word) ---

  Widget _buildSentenceBlank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fill in the missing word', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xl),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(DuolingoSpacing.xl),
          decoration: BoxDecoration(
            color: DuolingoColors.neutralGray,
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          ),
          child: Text(
            _current.promptText ?? '',
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.darkText,
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        TextField(
          controller: _typingController,
          enabled: !_checked,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textAlign: TextAlign.center,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_hasAnswer) _check();
          },
          style: DuolingoTextStyles.cardTitle.copyWith(
            fontSize: 24,
            letterSpacing: 2,
          ),
          decoration: InputDecoration(
            hintText: 'Type the missing word...',
            hintStyle: DuolingoTextStyles.body
                .copyWith(color: DuolingoColors.secondaryButtonGray),
            filled: true,
            fillColor: DuolingoColors.neutralGray,
            contentPadding: EdgeInsets.all(DuolingoSpacing.xl),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
              borderSide: const BorderSide(
                  color: DuolingoColors.informationBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // --- Meaning Matching (pick the correct definition) ---

  Widget _buildMeaningMatch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_current.promptText ?? '', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xxl),
        ..._current.choices.map(_buildChoiceTile),
      ],
    );
  }
```

- [x] **Step 3: Verify it compiles**

Run: `flutter analyze lib/screens/study.dart --no-fatal-infos`
Expected: no `error` lines.

- [x] **Step 4: Commit**

```bash
git add lib/screens/study.dart
git commit -m "feat: add Sentence Fill-in and Meaning Matching exercise UI"
```

---

### Task 7: Build, deploy, and run the basic feature test

**Files:** none (build + manual verification only)

- [x] **Step 1: Run the full frontend test suite**

Run (from `FlutterSpell_Game/`): `flutter test`
Expected: all tests pass, including the new `test/utils/exercise_content_parser_test.dart`.

- [x] **Step 2: Run the backend test suite**

Run (from `SpellBackend/`): `python -m pytest tests/ -v`
Expected: all tests pass, including the new `tests/test_deck_builder.py`.

- [x] **Step 3: Full analyzer pass**

Run (from `FlutterSpell_Game/`): `flutter analyze --no-fatal-infos`
Expected: no `error` lines anywhere in the project.

- [x] **Step 4: Rebuild the web app**

Run (from `FlutterSpell_Game/`): `flutter build web --release --dart-define=API_BASE_URL=http://192.168.0.11:8000`
Expected: `√ Built build\web`

- [x] **Step 5: Restart the backend so it picks up the deck_builder change**

The backend process must be restarted (editing a running Python process's source doesn't take effect until restart) — kill the current `uvicorn` process and start a fresh one the same way it was started before (`python -m uvicorn main:app --host 0.0.0.0 --port 8000`, from `SpellBackend/`), confirming `http://localhost:8000/docs` returns 200 afterward. The static file server for `build/web` does not need restarting — it reads files fresh on every request.

- [x] **Step 6: Manually verify the basic feature — Meaning Matching**

Via curl or browser: `GET http://localhost:8000/users/ERIC/deck?limit=10` and confirm at least one card has a non-null `quiz` field (words with IDs 31-33 and similar are known to have quiz data from earlier inspection — if ERIC's deck doesn't include any of them, use `tag=` to scope to a lesson tag that does, or check via `python3` directly against the DB which lesson tags reach those word IDs).

In the browser at `http://localhost:8080` (or the LAN address), log in as ERIC, enter an English lesson whose words include a quiz-bearing word, and confirm:
- A Meaning Matching screen appears once for that word (question + 4 tappable options), right after its Learn card.
- Picking the correct option shows the green success panel; picking wrong shows red with "Correct answer: <the right option text>" (not the word's spelling).

- [x] **Step 7: Manually verify the basic feature — Sentence Fill-in**

Still in the browser, keep studying that same lesson (or revisit) until the word reaches its high-mastery exercise (mastery > 3) — since that takes multiple sessions under normal SRS pacing, the fastest way to confirm this in one sitting is to check the exercise queue logic directly:

Run: `python3` against the running venv to sanity-check parsing rather than waiting out real mastery growth:

```bash
cd SpellBackend
python3 -c "
from src.db_session import get_session
from sqlmodel import select
from src.models.word import SpellingWord
with get_session() as session:
    w = session.exec(select(SpellingWord).where(SpellingWord.back_card.isnot(None))).first()
    print(w.text)
    print(w.back_card)
"
```

Confirm the printed `back_card` has an `Example:` line containing that word — this is what `parseSentenceBlank` will turn into the exercise prompt once a word reaches that mastery tier. Full end-to-end visual confirmation of this specific exercise can happen naturally as real study sessions accumulate mastery; it isn't blocked on anything further from this plan.

- [x] **Step 8: Manually verify the basic feature — handwriting reachability**

In the browser, enter a Chinese Kingdom lesson (these are tagged with both `read` and `write` per `LessonManager`) and confirm a handwriting-trace exercise (faint reference character + drawing canvas + "I WROTE IT!" / "NEED PRACTICE" buttons) appears for the *first* word studied in that session — not gated behind multiple correct reviews like before.

- [x] **Step 9: Confirm no regressions in existing exercises**

Still in the browser: confirm English `chooseSpelling`/`missingLetters`/`buildWord`/`typeWord` and Chinese `listenChoose`/`voiceRead` still work exactly as before for words without quiz/back_card data, and that the Study session summary screen (stars/XP/coins) still renders correctly at the end.

- [x] **Step 10: Report results**

Summarize what passed and what (if anything) didn't, with specifics (which lesson/word was used, what was observed) rather than a bare "it works."

---

## Self-Review Notes

- **Spec coverage:** Task 1 covers spec section 1 (backend). Task 2 covers spec section 1 (frontend model/parsing). Task 3 covers spec sections 2 and 3's parsing functions. Task 4 covers spec section 4's `skills` threading. Tasks 5-6 cover spec sections 2, 3, and 4's `study.dart` wiring and UI. Task 7 covers the user's explicit request to "do the basic feature test."
- **Placeholder scan:** no TBD/TODO; every code-bearing step shows the actual before/after code.
- **Type consistency:** `parseSentenceBlank(Word word) -> String?` and `parseQuiz(String? quizJson) -> QuizData?` (with `QuizData.question`/`.options`/`.correctOption`) are defined once in Task 3 and referenced identically in Tasks 5-6. `StudySessionArgs.skills` defined in Task 4 matches its usage in Task 5 (`widget.args.skills`). `ExerciseType.sentenceBlank`/`ExerciseType.meaningMatch` defined in Task 5 match their usage in Task 6.

## Post-Plan Follow-Ups (done, superseding some plan text above)

All 7 tasks above shipped and passed manual verification. Three follow-up fixes landed afterward, based on further testing feedback, and supersede a few details written above:

- **Chinese "no word list" bug**: lesson-scoped (`tag=`) deck requests were being silently filtered down to zero cards by SM-2 due-date gating. Fixed in `deck_builder.py` so tag-scoped requests no longer exclude not-yet-due words (generic no-tag daily deck still does). See `test_tag_scoped_deck_includes_words_not_yet_due` / `test_untagged_daily_deck_excludes_words_not_yet_due`.
- **`missingLetters`/`buildWord` removed from the English ladder entirely**: Task 5/Step 6 above still has `_typeForMastery` falling back to `missingLetters`/`buildWord` at low/mid mastery and when no sentence is available. That's no longer the shipped behavior — per explicit user feedback, English exercises never blank individual letters/characters within a word. The final ladder is: `chooseSpelling` (recognition) for a brand-new word, then typed whole-word input thereafter (`sentenceBlank` when sentence context exists, `typeWord` otherwise). `missingLetters`/`buildWord` `ExerciseType` values and their UI remain in `study.dart` as dead code (low-risk to leave, not yet requested to be deleted).
- **Homophone-aware Chinese voice grading**: `_check()`'s voiceRead handling above (plain `.contains()` check) was replaced with `rateChineseReading()` (`lib/utils/chinese_pronunciation.dart`, using the `lpinyin` package) giving a 1-3 star rating: 3 for exact match or homophone (same pinyin+tone), 2 for same base pinyin/different tone, 1 otherwise. The feedback panel now shows a star row for voice-read exercises.
