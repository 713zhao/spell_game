# Study Exercises: Easy Wins (Sentence Fill-in, Meaning Matching, Handwriting Reachability)

## Context

A larger mini-games taxonomy was proposed spanning English exercises, a
Chinese Pinyin system, expanded Chinese character exercises, and a deeper
handwriting pipeline (stroke order, independent writing, AI evaluation).
That's four largely independent subsystems; this spec covers only the
first, lowest-risk slice: fixing concrete problems in what already exists,
using data that's already in the database, with no new content authoring
or AI generation required. Pinyin, AI handwriting evaluation, and the rest
of the taxonomy are out of scope here and would each get their own spec.

Three problems, in `FlutterSpell_Game`:

1. **Sentence-style exercises would misuse letter-dragging.** There's no
   sentence exercise today, but if one were added the same way as
   `missingLetters`/`buildWord` (which blank/shuffle individual Latin
   letters), it would be nonsensical for a sentence — you don't
   letter-drag a whole sentence. It should ask the child to type the
   missing word instead.
2. **`back_card` and `quiz` data exist but never reach the app.** 11
   English words have a `back_card` (memorization tip + explanation +
   similar words + an `Example: <sentence>` line) and 26 have a `quiz`
   (`{"question","options","correct"}`) — both completely unused today.
   `back_card` is sent by `/users/{name}/deck` but the Flutter parser
   discards it; `quiz` isn't sent by the endpoint at all.
3. **Handwriting is effectively unreachable in a single session.**
   `study.dart` picks each word's exercise type once, from its SRS
   `repetitions` count, when the deck loads. `repetitions` only changes
   *between* sessions (via `/review`), so a lesson full of brand-new
   words (`repetitions == 0` for everyone) can never produce a
   `handwriteTrace` or `voiceRead` exercise in that sitting, no matter
   where the mastery thresholds are set — it would take several days of
   correct reviews to climb there.

## 1. Surface `back_card` and `quiz` through the deck

**Backend** — `SpellBackend/src/services/deck_builder.py`: both places
`build_daily_deck` builds a card dict (the overdue-words loop and the
new-words loop) already include `"back_card": w.back_card`. Add
`"quiz": w.quiz` next to it in both places.

**Frontend model** — `FlutterSpell_Game/lib/models/game_models.dart`: add
two optional fields to `Word`:

```dart
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
  // fromJson/toJson unchanged — DeckCard's Word is built manually, not
  // through Word.fromJson, so the generated game_models.g.dart doesn't
  // need regenerating.
}
```

**Frontend parsing** — `FlutterSpell_Game/lib/services/api_client.dart`,
`getDeckCards()`: pass through the two new fields when constructing each
`Word`:

```dart
word: Word(
  id: c['word_id'] as int,
  text: c['text'] as String,
  language: (c['language'] ?? 'english') as String,
  backCard: c['back_card'] as String?,
  quiz: c['quiz'] as String?,
),
```

## 2. Sentence Fill-in (`ExerciseType.sentenceBlank`)

A pure parsing function (in `study.dart`) extracts the example sentence
from `back_card`:

```dart
String? _parseSentenceBlank(Word word) {
  final backCard = word.backCard;
  if (backCard == null) return null;
  final match = RegExp(r'Example:\s*(.+)$', multiLine: true, caseSensitive: false)
      .firstMatch(backCard);
  if (match == null) return null;
  final sentence = match.group(1)!.trim();
  final wordPattern = RegExp(r'\b' + RegExp.escape(word.text) + r'\b', caseSensitive: false);
  if (!wordPattern.hasMatch(sentence)) return null;
  return sentence.replaceFirst(wordPattern, '_____');
}
```

Returns `null` (not eligible) when there's no `back_card`, no `Example:`
line, or the target word doesn't actually appear in that sentence as a
whole word — in every `null` case the word just falls back to its normal
exercise type, never a dead end.

**Ladder placement** (English, `_typeForMastery`): at the current highest
tier (today: random `typeWord`/`buildWord`), use `sentenceBlank` instead
when a blank is available for that word, otherwise keep today's behavior:

```dart
ExerciseType _typeForMastery(int mastery, {required bool hasSentence}) {
  if (mastery <= 1) {
    return _random.nextBool() ? ExerciseType.chooseSpelling : ExerciseType.missingLetters;
  }
  if (mastery <= 3) {
    return _random.nextBool() ? ExerciseType.missingLetters : ExerciseType.buildWord;
  }
  if (hasSentence) return ExerciseType.sentenceBlank;
  return _random.nextBool() ? ExerciseType.typeWord : ExerciseType.buildWord;
}
```

**UI**: show the blanked sentence as the prompt, a text field below it
(same widget pattern as `_buildTypeWord`), CHECK button enabled once
non-empty. Grading reuses the existing typed-answer path — target is
`word.text`, no new comparison logic needed. Concretely, add
`ExerciseType.sentenceBlank` to the same `_assembledAnswer()`/`_hasAnswer`
switch case that `ExerciseType.typeWord` already uses (both read from
`_typingController`).

## 3. Meaning Matching (`ExerciseType.meaningMatch`)

Another pure parsing function:

```dart
class QuizData {
  final String question;
  final List<String> options;
  final String correctOption;
  QuizData(this.question, this.options, this.correctOption);
}

QuizData? _parseQuiz(String? quizJson) {
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

Malformed/missing quiz data returns `null` — the word simply doesn't get
a Meaning Matching step, same fallback principle as above.

**Placement**: inserted once per word, the first time it appears in a
session (`repetitions == 0`), in the same slot the `Learn` card already
uses — right after `Learn`, before the word's regular spelling exercise.
This guarantees it's seen (not gated behind mastery/multiple sessions)
without disturbing the existing spelling-mastery ladder.

**UI**: show `quizData.question` as the prompt, then `quizData.options`
rendered as choice tiles (reusing the existing `_buildChoiceTile`).
Concretely, add `ExerciseType.meaningMatch` to the same
`_assembledAnswer()`/`_hasAnswer` switch case that
`ExerciseType.chooseSpelling`/`ExerciseType.listenChoose` already share
(all three read from `_selectedChoice`).

**Correctness refactor needed**: `_buildChoiceTile`'s "is this the
correct tile" check and `_check()`'s grading currently both hardcode the
target as `_current.word.text`. For Meaning Matching the correct answer
is a quiz option's text, not the word's spelling. Introduce:

```dart
String get _targetAnswer => _current.correctAnswer ?? _current.word.text;
```

where `_Exercise` gains an optional `correctAnswer` field (set to the
quiz's correct option for `meaningMatch`, left `null` — meaning "use the
word's own spelling" — for every other exercise type). Replace the three
existing `_current.word.text` comparison/display sites
(`_check()`'s correctness check, `_buildChoiceTile`'s green-highlight
check, and the feedback panel's "Correct answer: …" text) with
`_targetAnswer`. This is a small, mechanical refactor — behavior for
every existing exercise type is unchanged since `correctAnswer` is `null`
for all of them.

## 4. Handwriting reachability: gate by lesson skill, not mastery

`LessonSummary.skills` (from `/lessons/{user}`) already reports which tag
suffixes (`read`, `write`) make up a lesson — e.g. a combined
`::read`+`::write` Chinese lesson reports `["read", "write"]`. This is
fetched today but never threaded past the lesson list screens. Thread it
through:

- `StudySessionArgs` (`lesson_overview_screen.dart`) gains a
  `List<String> skills` field (default `const []`, so the "Quick
  Practice" shortcuts with no lesson context keep today's behavior).
- `LessonOverviewScreen`'s Start Adventure navigation passes
  `skills: lesson.skills` alongside the existing `tags`.

**New per-word logic in `_loadWords`** for Chinese words, replacing the
current three-tier `_typeForMasteryChinese`:

```dart
/// Recognition -> production ladder for the read/listen side. Handwriting
/// is handled separately below, gated by the lesson's skill tags rather
/// than mastery, so it doesn't take multiple sessions to become reachable.
ExerciseType _typeForMasteryChinese(int mastery) {
  return mastery <= 1 ? ExerciseType.listenChoose : ExerciseType.voiceRead;
}
```

```dart
if (isChinese) {
  _queue.add(_buildExercise(card.word, _typeForMasteryChinese(card.repetitions)));
  final skills = widget.args.skills;
  if (skills.isEmpty || skills.contains('write')) {
    _queue.add(_buildExercise(card.word, ExerciseType.handwriteTrace));
  }
}
```

A lesson tagged with `write` (or a session with no lesson context at all,
e.g. Quick Practice) always gets a handwriting rep for every Chinese
word, every session — handwriting is muscle-memory practice, not
something to "graduate" out of quickly, so it isn't mastery-gated. A
lesson tagged `read` only (no `write`) skips handwriting entirely,
matching what the teacher tagged that lesson to test. The read/listen
side still escalates from `listenChoose` to `voiceRead` as mastery
increases, now reachable one review sooner (`mastery <= 1` instead of the
old `<= 1` / `<= 3` split across three tiers) — though the real fix for
"never seen it" is the skill-gating above, not the threshold.

## Out of scope

Everything else from the original taxonomy: the Pinyin system entirely
(Listen & Type, Multiple Choice, Tone Selection, Rearrange Syllables, Read
Aloud for pinyin), stroke-order display, independent-writing stage, AI
handwriting evaluation, Speed Challenge, Sentence Matching / Character
Typing for Chinese, and backfilling `back_card`/`quiz` for words that
don't have them (via AI generation or otherwise). Each is a separate
subsystem with its own data and design questions, deferred to its own
spec.
