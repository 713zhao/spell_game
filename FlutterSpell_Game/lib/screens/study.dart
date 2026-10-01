import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:math';
import '../design_system/design_system.dart';
import '../models/game_models.dart';
import '../models/stage_data.dart' show reviewNodeIndex;
import '../services/app_settings.dart';
import '../services/hanzi_stroke_data.dart';
import '../services/sound_service.dart';
import '../widgets/celebration.dart';
import '../widgets/gift_box_dialog.dart';
import '../widgets/handwriting_canvas.dart';
import '../widgets/hanzi_writer_trace.dart';
import '../services/speech_recognition_service.dart';
import '../utils/chinese_pronunciation.dart';
import '../utils/exercise_content_parser.dart';
import '../utils/handwriting_gift.dart';
import '../utils/handwriting_plan.dart';
import '../utils/similar_characters.dart';
import '../utils/practice_sessions.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import 'lesson_overview_screen.dart' show StudySessionArgs;

/// SpellQuest study session — a sequence of mini-games:
/// - Learn card (new words), Listen & Choose, Missing Letters,
///   Build the Word, Listen & Type
/// - Exercise type adapts to each word's mastery (spaced-repetition state)
/// - Instant feedback after every interaction (Duolingo-style)
/// - Missed words re-queued with an easier exercise
/// - Summary with stars, XP, coins and weak words
class StudyScreen extends StatefulWidget {
  final StudySessionArgs args;

  const StudyScreen({Key? key, required this.args}) : super(key: key);

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

enum ExerciseType {
  learn,
  chooseSpelling,
  missingLetters,
  buildWord,
  typeWord,
  // Chinese-specific: single hanzi aren't decomposable into letters, so
  // these replace the letter-tile/typing exercises above for Chinese words.
  listenChoose,
  // Chinese: a word with one character blanked ("_出信件"); pick the missing
  // character from look-alikes.
  charFill,
  handwriteTrace,
  voiceRead,
  // English-specific, powered by back_card/quiz data that isn't present
  // for every word — see parseSentenceBlank/parseQuiz call sites below.
  sentenceBlank,
  meaningMatch,
}

bool _isChineseWord(String text) => RegExp(r'[一-鿿]').hasMatch(text);

enum SessionPhase { loading, empty, exercising, complete }

class _Exercise {
  final Word word;
  final ExerciseType type;
  final List<String> choices; // chooseSpelling, listenChoose, meaningMatch
  final List<String?> slots; // fixed letters; null = blank (letter games)
  final List<String> bank; // tappable letter tiles (letter games)
  final bool isRetry;
  final String?
  promptText; // meaningMatch's question, sentenceBlank's blanked sentence
  final String?
  correctAnswer; // overrides word.text as the graded target (meaningMatch only)

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

class _StudyScreenState extends State<StudyScreen>
    with TickerProviderStateMixin {
  final SoundService _soundService = SoundService();
  final Random _random = Random();
  final TextEditingController _typingController = TextEditingController();

  SessionPhase _phase = SessionPhase.loading;
  List<_Exercise> _queue = [];
  int _index = 0;

  // Answer state for the current exercise
  String? _selectedChoice;
  List<int?> _blankFill = []; // per blank: index into bank, or null
  bool _checked = false;
  bool _wasCorrect = false;

  // Chinese-specific exercise state
  List<String> _chineseDistractorPool = [];
  String? _voiceTranscript;
  bool _isRecording = false;
  bool _voiceUnsupported = false;
  int _traceVersion = 0; // bumped by "Clear"/"Restart" to reset the trace UI
  int? _voiceStars; // 1-3 rating for the last voiceRead attempt (see _check)

  // Guided (HanziWriter) vs free-draw handwriting trace. Null while the
  // stroke-data availability check for the current word is in flight.
  bool? _hanziQuizAvailable;
  bool _skippedChar = false; // a character of this word was skipped
  int _hanziCharIndex = 0; // which character of the word is active in quiz mode
  // The characters the child actually writes: the whole word when short, only
  // the hardest few of a long sentence. Empty until the preflight resolves.
  List<String> _writeChars = [];
  bool _typeInstead = false; // sentence handwriting swapped for keyboard input
  int _handwritesDone = 0; // successful handwriting exercises this session
  bool _giftPending = false; // a gift box is owed when the child continues
  final HanziWriterTraceController _hanziController =
      HanziWriterTraceController();

  // Session stats
  int _totalWords = 0;
  int _firstTryCorrect = 0;
  int _earnedXp = 0;
  int _earnedCoins = 0;
  final Set<String> _weakWords = {};
  String _lastPraise = '';
  String _lastEncouragement = '';

  // In-flight /review POSTs, so _finishSession can wait for all of them
  // (including the last word's) before refetching stats/lessons - otherwise
  // the refetch can race the last submission and render stale mastery.
  final List<Future<void>> _pendingReviews = [];

  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;
  late AnimationController _shakeController;

  static const List<String> _praises = [
    'Nicely done!',
    'Awesome!',
    'Amazing!',
    'Great job!',
    'Excellent!',
    'You got it!',
    'Perfect!',
  ];

  static const List<String> _encouragements = [
    'Almost there! 💪',
    'Good try! You\'ll get it next time!',
    'Keep going, you\'re learning!',
    'No worries — practice makes perfect!',
  ];

  late GameProvider gameProvider;

  static const int _reviewSessionSize = 15;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _celebrationScale = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.elasticOut,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );
    _soundService.init();
    _loadWords();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _celebrationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Session construction (adaptive)
  // ---------------------------------------------------------------------

  Future<void> _loadWords() async {
    try {
      await gameProvider.loadDeck(
        tags: widget.args.tags,
        checkpoint: widget.args.checkpoint,
        review: widget.args.review,
        limit: widget.args.review ? _reviewSessionSize : 10,
      );
      var cards = gameProvider.deckCards;

      if (cards.isEmpty) {
        setState(() => _phase = SessionPhase.empty);
        return;
      }

      cards = List<DeckCard>.from(cards)..shuffle(_random);

      // Chinese exercises pick distractor characters from this lesson's own
      // words instead of letter-misspelling (a single hanzi has no letters).
      _chineseDistractorPool = cards
          .where((c) => _isChineseWord(c.word.text))
          .map((c) => c.word.text)
          .toSet()
          .toList();

      // Interleave: new words get a Learn card right before their exercise
      _queue = [];
      for (final card in cards) {
        final isChinese = _isChineseWord(card.word.text);

        if (card.repetitions == 0) {
          _queue.add(_Exercise(word: card.word, type: ExerciseType.learn));
          if (!isChinese && parseQuiz(card.word.quiz) != null) {
            _queue.add(_buildExercise(card.word, ExerciseType.meaningMatch));
          }
        }

        if (isChinese) {
          _queue.add(
            _buildExercise(card.word, _typeForMasteryChinese(card.repetitions)),
          );
          final skills = widget.args.skills;
          if (_canCharFill(card.word.text) && _random.nextBool()) {
            _queue.add(_buildExercise(card.word, ExerciseType.charFill));
          }
          if (skills.isEmpty || skills.contains('write')) {
            _queue.add(_buildExercise(card.word, ExerciseType.handwriteTrace));
          }
        } else {
          final hasSentence = parseSentenceBlank(card.word) != null;
          final type = _typeForMastery(
            card.repetitions,
            hasSentence: hasSentence,
          );
          _queue.add(_buildExercise(card.word, type));
        }
      }

      // Brand-new English words get a second, harder recall (typing the
      // whole word) at the end of the session, after the other words, so
      // first exposure is tested again once it has had to be held for a
      // while. Chinese words already get a second exercise (handwriting).
      final secondPass = <_Exercise>[
        for (final card in cards)
          if (card.repetitions == 0 && !_isChineseWord(card.word.text))
            _buildExercise(card.word, ExerciseType.typeWord),
      ]..shuffle(_random);
      _queue.addAll(secondPass);

      // Accuracy is first-try-correct out of the graded exercises (learn
      // cards aren't graded).
      _totalWords = _queue.where((e) => e.type != ExerciseType.learn).length;

      setState(() => _phase = SessionPhase.exercising);
      _resetAnswerState();
      _autoPlayCurrentWord();
    } catch (e) {
      setState(() => _phase = SessionPhase.empty);
    }
  }

  /// Adaptive learning ladder (SpellQuest design):
  /// low mastery = recognition, mid = missing letters / building,
  /// high = full typing.
  /// English ladder: recognition (tap to choose) for a brand-new word,
  /// then typed whole-word input for everything after that - sentence
  /// context when available, plain typed word otherwise. Never
  /// letter-dragging (missingLetters/buildWord blank out individual
  /// characters within a word, not the whole missing word).
  ExerciseType _typeForMastery(int mastery, {required bool hasSentence}) {
    if (hasSentence) return ExerciseType.sentenceBlank;
    if (mastery <= 1) return ExerciseType.chooseSpelling;
    return ExerciseType.typeWord;
  }

  /// Recognition -> production ladder for the read/listen side of a
  /// Chinese word. Handwriting is handled separately in _loadWords, gated
  /// by the lesson's skill tags rather than mastery, so it doesn't take
  /// multiple sessions to become reachable.
  ExerciseType _typeForMasteryChinese(int mastery) {
    return mastery <= 1 ? ExerciseType.listenChoose : ExerciseType.voiceRead;
  }

  _Exercise _buildExercise(
    Word word,
    ExerciseType type, {
    bool isRetry = false,
  }) {
    switch (type) {
      case ExerciseType.chooseSpelling:
        return _Exercise(
          word: word,
          type: type,
          choices: _buildChoices(word.text),
          isRetry: isRetry,
        );
      case ExerciseType.listenChoose:
        return _Exercise(
          word: word,
          type: type,
          choices: _buildCharacterChoices(word.text),
          isRetry: isRetry,
        );
      case ExerciseType.charFill:
        final chars = cjkChars(word.text);
        final missing = chars[_random.nextInt(chars.length)];
        final blanked = word.text.replaceFirst(missing, '＿');
        return _Exercise(
          word: word,
          type: type,
          choices: _buildFillChoices(missing, word.text),
          promptText: blanked,
          correctAnswer: missing,
          isRetry: isRetry,
        );
      case ExerciseType.missingLetters:
        final result = _buildMissingLetters(word.text);
        return _Exercise(
          word: word,
          type: type,
          slots: result.$1,
          bank: result.$2,
          isRetry: isRetry,
        );
      case ExerciseType.buildWord:
        final letters = word.text.toLowerCase().split('')..shuffle(_random);
        return _Exercise(
          word: word,
          type: type,
          slots: List<String?>.filled(word.text.length, null),
          bank: letters,
          isRetry: isRetry,
        );
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
      default:
        return _Exercise(word: word, type: type, isRetry: isRetry);
    }
  }

  /// Blank out 1-3 letters; bank = blanked letters + distractors.
  (List<String?>, List<String>) _buildMissingLetters(String word) {
    final lower = word.toLowerCase();
    final blankCount = (lower.length ~/ 3).clamp(1, 3);
    final positions = List<int>.generate(lower.length, (i) => i)
      ..shuffle(_random);
    final blanks = positions.take(blankCount).toSet();

    final slots = <String?>[];
    final bank = <String>[];
    for (var i = 0; i < lower.length; i++) {
      if (blanks.contains(i)) {
        slots.add(null);
        bank.add(lower[i]);
      } else {
        slots.add(lower[i]);
      }
    }
    // Distractor letters
    const alphabet = 'abcdefghijklmnopqrstuvwxyz';
    while (bank.length < blankCount + 3) {
      final c = alphabet[_random.nextInt(26)];
      bank.add(c);
    }
    bank.shuffle(_random);
    return (slots, bank);
  }

  static const List<String> _fallbackCharacters = [
    '的',
    '一',
    '是',
    '了',
    '我',
    '不',
    '人',
    '在',
    '他',
    '有',
    '这',
    '个',
    '上',
    '们',
    '来',
    '到',
    '时',
    '大',
    '地',
    '为',
  ];

  /// A multi-character word has enough context to blank one character.
  bool _canCharFill(String text) {
    final n = cjkChars(text).length;
    return n >= 2 && n <= 6;
  }

  /// The missing character plus look-alikes; padded from the lesson's own
  /// characters, then common ones.
  List<String> _buildFillChoices(String missing, String word) {
    final picked = <String>[...similarCharacters(missing, 3)..shuffle(_random)];
    if (picked.length > 3) picked.removeRange(3, picked.length);
    final lessonChars = _chineseDistractorPool
        .expand((t) => cjkChars(t))
        .toSet()
        .where((c) => c != missing && !word.contains(c))
        .toList()
      ..shuffle(_random);
    for (final c in lessonChars) {
      if (picked.length >= 3) break;
      if (!picked.contains(c)) picked.add(c);
    }
    var guard = 0;
    while (picked.length < 3 && guard < 30) {
      guard++;
      final c =
          _fallbackCharacters[_random.nextInt(_fallbackCharacters.length)];
      if (c != missing && !picked.contains(c)) picked.add(c);
    }
    return <String>[missing, ...picked]..shuffle(_random);
  }

  /// Distractor characters for Listen & Choose: prefer sibling characters
  /// from this lesson so choices stay visually plausible; pad with common
  /// characters if the lesson is too small to have three others.
  List<String> _buildCharacterChoices(String target) {
    final distractors =
        _chineseDistractorPool.where((t) => t != target).toList()
          ..shuffle(_random);
    final picked = distractors.take(3).toList();
    var guard = 0;
    while (picked.length < 3 && guard < 30) {
      guard++;
      final c =
          _fallbackCharacters[_random.nextInt(_fallbackCharacters.length)];
      if (c != target && !picked.contains(c)) picked.add(c);
    }
    final options = <String>[target, ...picked]..shuffle(_random);
    return options;
  }

  List<String> _buildChoices(String word) {
    final wrong = <String>{};
    final lower = word.toLowerCase();
    var guard = 0;
    while (wrong.length < 3 && guard < 60) {
      guard++;
      final candidate = _misspell(lower);
      if (candidate != lower && candidate.isNotEmpty) wrong.add(candidate);
    }
    final options = <String>[lower, ...wrong]..shuffle(_random);
    return options;
  }

  String _misspell(String word) {
    if (word.length < 3) return word;
    const vowels = 'aeiou';
    final chars = word.split('');
    switch (_random.nextInt(4)) {
      case 0:
        final i = _random.nextInt(word.length - 1);
        final t = chars[i];
        chars[i] = chars[i + 1];
        chars[i + 1] = t;
        break;
      case 1:
        final i = _random.nextInt(word.length);
        chars.insert(i, chars[i]);
        break;
      case 2:
        chars.removeAt(_random.nextInt(word.length));
        break;
      default:
        final vowelIdxs = <int>[];
        for (var i = 0; i < chars.length; i++) {
          if (vowels.contains(chars[i])) vowelIdxs.add(i);
        }
        if (vowelIdxs.isEmpty) return _misspell(word);
        chars[vowelIdxs[_random.nextInt(vowelIdxs.length)]] =
            vowels[_random.nextInt(vowels.length)];
    }
    return chars.join();
  }

  // ---------------------------------------------------------------------
  // Session flow
  // ---------------------------------------------------------------------

  _Exercise get _current => _queue[_index];

  /// The value an answer is graded against. Every exercise type grades
  /// against the word's own spelling except meaningMatch, whose correct
  /// answer is a quiz option's text instead.
  String get _targetAnswer => _current.correctAnswer ?? _current.word.text;

  void _resetAnswerState() {
    _checked = false;
    _wasCorrect = false;
    _selectedChoice = null;
    _typingController.clear();
    _voiceTranscript = null;
    _isRecording = false;
    _voiceUnsupported = false;
    _voiceStars = null;
    _hanziQuizAvailable = null;
    _hanziCharIndex = 0;
    _skippedChar = false;
    _writeChars = [];
    _typeInstead = false;
    final blanks = _current.slots.where((s) => s == null).length;
    _blankFill = List<int?>.filled(blanks, null);
    if (_current.type == ExerciseType.handwriteTrace) {
      _checkHanziQuizAvailability();
    }
  }

  /// Decides which characters of the current word the child writes (all of a
  /// short word, only the hardest few of a sentence), then preflights whether
  /// each has HanziWriter stroke data, so _buildHandwriteTrace can commit to
  /// guided quiz tracing or the free-draw fallback instead of switching
  /// mid-word.
  Future<void> _checkHanziQuizAvailability() async {
    final chars = cjkChars(_current.word.text);
    final capturedIndex = _index;
    final counts = chars.length > maxHandwriteChars
        ? await hanziStrokeCounts(chars.toSet())
        : const <String, int>{};
    if (!mounted || _index != capturedIndex) return;
    final writeChars = pickKeyChars(chars, counts);
    if (!kIsWeb) {
      setState(() {
        _writeChars = writeChars;
        _hanziQuizAvailable = false;
      });
      return;
    }
    final available = await hanziStrokeDataAvailable(writeChars.join());
    if (!mounted || _index != capturedIndex) return;
    setState(() {
      _writeChars = writeChars;
      _hanziQuizAvailable = available;
    });
  }

  /// True when the current handwriting exercise is a sentence of which the
  /// child only writes the tricky characters.
  bool get _isSentenceTrace =>
      _writeChars.length < cjkChars(_current.word.text).length;

  void _autoPlayCurrentWord() {
    // Called synchronously rather than via addPostFrameCallback: iOS
    // Safari's autoplay/speech restrictions are far more lenient when
    // playback stays inside the same call chain as a user gesture (see
    // `_continue`, bound directly to onTap) - deferring to the next frame
    // breaks that chain even though the caller was itself a tap. Ported
    // from FlutterSpell's TtsHelper.playWord, which is always invoked this
    // way (only from button onPressed handlers, never auto-played after
    // an async load) and has no iOS silence issue.
    if (_phase == SessionPhase.exercising) {
      _soundService.playWordPronunciation(_current.word.text);
    }
  }

  String _assembledAnswer() {
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
      case ExerciseType.charFill:
      case ExerciseType.meaningMatch:
        return _selectedChoice ?? '';
      case ExerciseType.typeWord:
      case ExerciseType.sentenceBlank:
        return _typingController.text.trim();
      case ExerciseType.voiceRead:
        return _voiceTranscript ?? '';
      case ExerciseType.missingLetters:
      case ExerciseType.buildWord:
        final buffer = StringBuffer();
        var blankIdx = 0;
        for (final s in _current.slots) {
          if (s != null) {
            buffer.write(s);
          } else {
            final bankIdx = _blankFill[blankIdx++];
            buffer.write(bankIdx == null ? ' ' : _current.bank[bankIdx]);
          }
        }
        return buffer.toString();
      default:
        return '';
    }
  }

  bool get _hasAnswer {
    if (_checked) return false;
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
      case ExerciseType.charFill:
      case ExerciseType.meaningMatch:
        return _selectedChoice != null;
      case ExerciseType.typeWord:
      case ExerciseType.sentenceBlank:
        return _typingController.text.trim().isNotEmpty;
      case ExerciseType.voiceRead:
        return _voiceTranscript != null && _voiceTranscript!.isNotEmpty;
      case ExerciseType.missingLetters:
      case ExerciseType.buildWord:
        return !_blankFill.contains(null);
      case ExerciseType.handwriteTrace:
        return _typeInstead && _typingController.text.trim().isNotEmpty;
      default:
        return false;
    }
  }

  void _check() {
    if (_current.type == ExerciseType.voiceRead) {
      // Graded by pronunciation, not text equality: a homophone of the
      // target (same pinyin + tone) is a correct reading even if speech
      // recognition wrote down a different character.
      final stars = rateChineseReading(_targetAnswer, _voiceTranscript);
      _voiceStars = stars;
      _applyResult(
        stars >= 2, // homophone or merely similar both count as a pass
        qualityOverride: stars == 3 ? 5 : (stars == 2 ? 3 : 1),
      );
      return;
    }
    if (_current.type == ExerciseType.handwriteTrace) {
      // Typed instead of handwritten: compare characters, not punctuation.
      _applyResult(typedMatchesTarget(_typingController.text, _targetAnswer));
      return;
    }
    final correct =
        _assembledAnswer().toLowerCase() == _targetAnswer.toLowerCase();
    _applyResult(correct);
  }

  /// Free-draw handwriting trace has no auto-gradable input (no OCR) — the
  /// child self-reports whether they wrote it correctly, and that feeds
  /// the same reward/retry/SRS pipeline as an auto-graded answer.
  void _selfGrade(bool gotIt) => _applyResult(gotIt);

  /// Called when HanziWriter reports a character's quiz complete (every
  /// stroke drawn correctly, in order). Advances to the next character in
  /// a multi-character word, or grades the whole word correct once the
  /// last one finishes — unlike the free-draw fallback, this is a real
  /// auto-grade since HanziWriter already verified the strokes.
  void _onHanziCharComplete() {
    if (_hanziCharIndex + 1 >= _writeChars.length) {
      // A skipped character means the word wasn't fully written: move on
      // ungraded rather than awarding credit.
      if (_skippedChar) {
        _advance();
      } else {
        _applyResult(true);
      }
    } else {
      setState(() => _hanziCharIndex++);
    }
  }

  Future<void> _recordVoiceAnswer() async {
    setState(() {
      _isRecording = true;
      _voiceTranscript = null;
    });
    final result = await recognizeSpeech(lang: 'zh-CN');
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      if (result == null) {
        _voiceUnsupported = true;
      } else {
        _voiceTranscript = result;
      }
    });
  }

  void _applyResult(bool correct, {int? qualityOverride}) {
    // Close the text field's input connection before grading disables it:
    // on web, disabling a still-focused TextField makes the engine update a
    // text-input configuration whose DOM element is already gone, which
    // throws an assertion (harmless to play, but noisy).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _checked = true;
      _wasCorrect = correct;
      _lastPraise = _praises[_random.nextInt(_praises.length)];
      _lastEncouragement =
          _encouragements[_random.nextInt(_encouragements.length)];
      if (correct) {
        if (_current.isRetry) {
          _earnedXp += 5;
        } else {
          _earnedXp += 10;
          _earnedCoins += 2;
          _firstTryCorrect++;
        }
        Celebration.correct(context);
        if (_current.type == ExerciseType.handwriteTrace) {
          _handwritesDone++;
          _giftPending = handwriteGiftDue(_handwritesDone);
        }
      } else {
        _weakWords.add(_current.word.text);
        // Missed word returns later with an easier exercise
        final retryType = _isChineseWord(_current.word.text)
            ? ExerciseType.listenChoose
            : ExerciseType.chooseSpelling;
        _queue.add(_buildExercise(_current.word, retryType, isRetry: true));
        _soundService.playIncorrectAnswer();
        _shakeController.forward(from: 0);
        // Replay the pronunciation so the child hears it again
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _soundService.playWordPronunciation(_current.word.text);
          }
        });
      }
    });

    // Update spaced-repetition state on the backend so lesson mastery/stars
    // (computed from ReviewState on next /lessons fetch) advance for real.
    final quality =
        qualityOverride ?? (correct ? (_current.isRetry ? 3 : 5) : 1);
    _pendingReviews.add(gameProvider.submitReview(_current.word.id, quality));
  }

  void _continue() {
    if (_giftPending) {
      _giftPending = false;
      _openGiftBox();
      return;
    }
    _advance();
  }

  /// A gift box for every few handwriting exercises done. The rewards join
  /// the session's XP/coin tally, and the next exercise only starts once the
  /// child closes the box - via the dialog's callback rather than the
  /// showDialog future, so audio for the next word still starts inside the
  /// tap (see _autoPlayCurrentWord).
  void _openGiftBox() {
    final gift = rollHandwriteGift(_random);
    _earnedXp += gift.xp;
    _earnedCoins += gift.coins;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GiftBoxDialog(gift: gift, onClaim: _advance),
    );
  }

  void _advance() {
    if (_index + 1 >= _queue.length) {
      _finishSession();
      return;
    }
    setState(() {
      _index++;
      _resetAnswerState();
    });
    _autoPlayCurrentWord();
  }

  Future<void> _finishSession() async {
    setState(() => _phase = SessionPhase.complete);
    _celebrationController.forward(from: 0);
    Celebration.lessonComplete(context);
    // Wait for every word's /review POST (including the last one, which may
    // still be in flight) before refetching - otherwise the refetch below
    // can race it and render mastery/stats that don't include this session.
    await Future.wait(_pendingReviews);
    // Per-word /review calls already advanced ReviewState (and each earned
    // a point); refresh the cached stats so points/streak reflect them.
    await gameProvider.loadUserStats();
    // Finishing a checkpoint (or the review) session is what passes it and
    // enables the next node on the path. Must land before the lessons
    // reload below so that reload sees it.
    final checkpoint = widget.args.checkpoint;
    if (widget.args.review || checkpoint != null) {
      var passed = await gameProvider.markCheckpointPassed(
        widget.args.subject,
        widget.args.lessonKey,
        widget.args.review ? reviewNodeIndex : checkpoint!,
      );
      // A flaky connection or backend hiccup shouldn't silently strand the
      // child on a lesson that never unlocks the next node - retry once.
      if (!passed) {
        passed = await gameProvider.markCheckpointPassed(
          widget.args.subject,
          widget.args.lessonKey,
          widget.args.review ? reviewNodeIndex : checkpoint!,
        );
      }
      if (!passed && mounted) {
        _progressSaveFailed = true;
      }
    } else {
      // checkpoint == null and not a review: a completed lesson's free
      // practice (see lesson_overview_screen.dart's _point) - count it so
      // its practice node's "Session N" label advances next time.
      await incrementPracticeSessionCount(
        widget.args.subject,
        widget.args.lessonKey,
      );
    }
    // Also refresh the lesson list so checkpoint/mastery progress from this
    // session (which may have unlocked the next checkpoint or lesson) is
    // reflected once the user navigates back to the World Map - otherwise
    // the kingdom screen's cached LessonSummary still shows the pre-session
    // checkpointIndex, silently re-serving already-mastered words.
    await gameProvider.loadLessons(widget.args.subject);
    if (mounted) setState(() {});
  }

  // Set when markCheckpointPassed fails twice, so the summary screen can
  // warn the child/parent instead of showing an unqualified "complete!".
  bool _progressSaveFailed = false;

  int get _stars {
    final accuracy = _totalWords == 0 ? 0.0 : _firstTryCorrect / _totalWords;
    if (accuracy >= 0.9) return 3;
    if (accuracy >= 0.7) return 2;
    return 1;
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
        ),
        title: const Text('Wait, don\'t go! 🥺'),
        content: const Text(
          'You\'ll lose your progress in this adventure if you quit now.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'KEEP GOING',
              style: TextStyle(
                color: DuolingoColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'QUIT',
              style: TextStyle(color: DuolingoColors.mistakeRed),
            ),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      // Each exercise already submitted its /review the moment it was
      // graded (see _applyResult), so points/mastery earned so far this
      // session are real on the backend even when quitting early - but
      // gameProvider's cached userStats/lessons won't reflect that until
      // something reloads them. Without this, Home silently shows stale
      // numbers until its own next full reload.
      await gameProvider.loadUserStats();
      await gameProvider.loadLessons(widget.args.subject);
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case SessionPhase.loading:
        return const Scaffold(
          backgroundColor: DuolingoColors.backgroundWhite,
          body: Center(child: CircularProgressIndicator()),
        );
      case SessionPhase.empty:
        return _buildEmptyState();
      case SessionPhase.complete:
        return _buildSummary();
      case SessionPhase.exercising:
        return _buildExerciseScreen();
    }
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: DuolingoColors.bodyText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 64)),
            SizedBox(height: DuolingoSpacing.lg),
            Text(
              'No words to study yet!',
              style: DuolingoTextStyles.sectionTitle,
            ),
            SizedBox(height: DuolingoSpacing.sm),
            Text(
              'Ask your teacher to add words to your deck.',
              style: DuolingoTextStyles.body.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseScreen() {
    final progress = _index / _queue.length;
    // Without this, a phone's back gesture/button (much more natural on
    // mobile web than tapping the in-app close button) pops the route
    // directly - skipping _confirmQuit and the userStats/lessons refresh
    // it does, so Home silently shows stale points/progress even though
    // the backend already recorded everything reviewed so far.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        backgroundColor: DuolingoColors.backgroundWhite,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(progress),
              Expanded(
                child: AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final t = _shakeController.value;
                    final dx = sin(t * pi * 4) * 10 * (1 - t);
                    return Transform.translate(
                      offset: Offset(dx, 0),
                      child: child,
                    );
                  },
                  child: _buildExerciseContent(),
                ),
              ),
              _buildBottomPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseContent() {
    final padding = EdgeInsets.symmetric(
      horizontal: DuolingoSpacing.xxl,
      vertical: DuolingoSpacing.lg,
    );
    // Handwriting must never scroll: a stroke that drifts (or starts) off
    // the drawing surface would otherwise drag the page up/down instead of
    // drawing. So the trace is sized to fit the space it's given, and the
    // view is locked.
    if (_current.type == ExerciseType.handwriteTrace && !_typeInstead) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          child: _buildHandwriteTrace(
            Size(
              constraints.maxWidth - padding.horizontal,
              constraints.maxHeight - padding.vertical,
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(padding: padding, child: _buildExerciseBody());
  }

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
      case ExerciseType.charFill:
        return _buildCharFill();
      case ExerciseType.handwriteTrace:
        // Only reached when typing instead; tracing goes through
        // _buildExerciseContent's fixed layout.
        return _buildTypedSentence();
      case ExerciseType.voiceRead:
        return _buildVoiceRead();
      case ExerciseType.sentenceBlank:
        return _buildSentenceBlank();
      case ExerciseType.meaningMatch:
        return _buildMeaningMatch();
    }
  }

  Widget _buildTopBar(double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DuolingoSpacing.lg,
        vertical: DuolingoSpacing.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: DuolingoColors.secondaryButtonGray,
              size: 28,
            ),
            onPressed: _confirmQuit,
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: DuolingoSpacing.progressBarHeight,
                  backgroundColor: DuolingoColors.neutralGray,
                  valueColor: const AlwaysStoppedAnimation(
                    DuolingoColors.primaryGreen,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: DuolingoSpacing.md),
          const Text('⚡', style: TextStyle(fontSize: 18)),
          Text(
            '$_earnedXp',
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.streakOrange,
            ),
          ),
          SizedBox(width: DuolingoSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildAudioButton({double size = 72, double iconSize = 36}) {
    return GestureDetector(
      onTap: () => _soundService.playWordPronunciation(_current.word.text),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: DuolingoColors.informationBlue,
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFF1876BF),
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(Icons.volume_up, color: Colors.white, size: iconSize),
      ),
    );
  }

  // --- Learn card (new word introduction) ---

  Widget _buildLearnCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 22)),
            SizedBox(width: DuolingoSpacing.sm),
            Text('New word!', style: DuolingoTextStyles.sectionTitle),
          ],
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(DuolingoSpacing.xxl),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: DuolingoColors.englishKingdomGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            border: Border.all(color: DuolingoColors.informationBlue, width: 2),
          ),
          child: Column(
            children: [
              const Text('🐕', style: TextStyle(fontSize: 48)),
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                _current.word.text,
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.pageTitle.copyWith(
                  fontSize: 36,
                  letterSpacing: 2,
                  color: DuolingoColors.darkText,
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              _buildAudioButton(size: 56, iconSize: 28),
              SizedBox(height: DuolingoSpacing.sm),
              Text(
                'Listen and remember the spelling',
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.bodyText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Listen & Choose ---

  Widget _buildChooseSpelling() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the correct spelling',
          style: DuolingoTextStyles.sectionTitle,
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(child: _buildAudioButton()),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            'Tap to hear the word',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        ..._current.choices.map(_buildChoiceTile),
      ],
    );
  }

  Widget _buildChoiceTile(String choice) {
    final selected = _selectedChoice == choice;
    final isCorrectChoice = choice.toLowerCase() == _targetAnswer.toLowerCase();

    Color border = const Color(0xFFE5E5E5);
    Color fill = DuolingoColors.backgroundWhite;
    Color textColor = DuolingoColors.darkText;

    if (_checked && isCorrectChoice) {
      border = DuolingoColors.primaryGreen;
      fill = const Color(0xFFD7FFB8);
      textColor = const Color(0xFF58A700);
    } else if (_checked && selected && !isCorrectChoice) {
      border = DuolingoColors.mistakeRed;
      fill = const Color(0xFFFFDFE0);
      textColor = const Color(0xFFEA2B2B);
    } else if (selected) {
      border = DuolingoColors.informationBlue;
      fill = const Color(0xFFDDF4FF);
      textColor = const Color(0xFF1899D6);
    }

    return Padding(
      padding: EdgeInsets.only(bottom: DuolingoSpacing.md),
      child: GestureDetector(
        onTap: _checked ? null : () => setState(() => _selectedChoice = choice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            vertical: DuolingoSpacing.lg,
            horizontal: DuolingoSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: border, width: 2),
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
            boxShadow: [
              BoxShadow(
                color: border.withOpacity(selected || _checked ? 0.4 : 1),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Text(
            choice,
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: textColor,
              fontSize: 20,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // --- Chinese: Listen & Choose (audio -> pick the matching character) ---

  Widget _buildListenChoose() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap the character you hear',
          style: DuolingoTextStyles.sectionTitle,
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(child: _buildAudioButton()),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            'Tap to hear it again',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: _current.choices.map(_buildCharacterChoiceTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCharFill() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pick the missing character',
          style: DuolingoTextStyles.sectionTitle,
        ),
        SizedBox(height: DuolingoSpacing.xl),
        Center(
          child: Text(
            _current.promptText ?? '',
            style: DuolingoTextStyles.cardTitle.copyWith(fontSize: 44),
          ),
        ),
        SizedBox(height: DuolingoSpacing.md),
        Center(child: _buildAudioButton(size: 44, iconSize: 22)),
        SizedBox(height: DuolingoSpacing.xl),
        Center(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: _current.choices.map(_buildCharacterChoiceTile).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterChoiceTile(String choice) {
    final selected = _selectedChoice == choice;
    final isCorrectChoice = choice == _targetAnswer;

    Color border = const Color(0xFFE5E5E5);
    Color fill = DuolingoColors.backgroundWhite;
    Color textColor = DuolingoColors.darkText;

    if (_checked && isCorrectChoice) {
      border = DuolingoColors.primaryGreen;
      fill = const Color(0xFFD7FFB8);
      textColor = const Color(0xFF58A700);
    } else if (_checked && selected && !isCorrectChoice) {
      border = DuolingoColors.mistakeRed;
      fill = const Color(0xFFFFDFE0);
      textColor = const Color(0xFFEA2B2B);
    } else if (selected) {
      border = DuolingoColors.informationBlue;
      fill = const Color(0xFFDDF4FF);
      textColor = const Color(0xFF1899D6);
    }

    return GestureDetector(
      onTap: _checked ? null : () => setState(() => _selectedChoice = choice),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 130,
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(color: border, width: 2),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
          boxShadow: [
            BoxShadow(
              color: border.withOpacity(selected || _checked ? 0.4 : 1),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          choice,
          style: DuolingoTextStyles.cardTitle.copyWith(
            color: textColor,
            fontSize: 36,
          ),
        ),
      ),
    );
  }

  // --- Chinese: Handwriting trace ---
  //
  // Two modes, decided per-word by _checkHanziQuizAvailability once its
  // stroke-data preflight resolves:
  //  - Guided quiz (preferred): HanziWriter checks stroke order/shape one
  //    character at a time and fills in each correct stroke, matching
  //    https://hanziwriter.org/quiz.html. Auto-grades on completion.
  //  - Free trace (fallback): the old plain canvas, for characters outside
  //    HanziWriter's dataset. Self-graded by the child (no OCR).

  Widget _buildHandwriteTrace(Size area) {
    if (_hanziQuizAvailable == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trace the word', style: DuolingoTextStyles.sectionTitle),
          SizedBox(height: DuolingoSpacing.xxl),
          const Center(child: CircularProgressIndicator()),
        ],
      );
    }
    return _hanziQuizAvailable == true
        ? _buildHanziQuizTrace(area)
        : _buildFreeTrace(area);
  }

  Widget _buildHanziQuizTrace(Size area) {
    final characters = _writeChars;
    final isSingle = characters.length == 1;
    final activeIndex = _hanziCharIndex.clamp(0, characters.length - 1);
    final title = isSingle
        ? 'Trace the character'
        : 'Character ${activeIndex + 1} of ${characters.length}';

    // Everything but the trace itself, so the trace gets what's left.
    var otherHeight = 210.0; // title + audio + Show/Restart + Skip rows + gaps
    if (_isSentenceTrace) {
      final perRow = max(1, (area.width - 24) ~/ 24);
      otherHeight +=
          40 + ((_current.word.text.length / perRow).ceil() * 32 + 24);
    } else if (!isSingle) {
      otherHeight += 52;
    }
    final traceSize = (area.height - otherHeight).clamp(120.0, 220.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DuolingoTextStyles.sectionTitle),
        if (_isSentenceTrace) ...[
          SizedBox(height: DuolingoSpacing.md),
          _buildSentenceContext(activeIndex),
        ] else if (!isSingle) ...[
          SizedBox(height: DuolingoSpacing.md),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: DuolingoSpacing.sm,
              runSpacing: DuolingoSpacing.sm,
              children: [
                for (var i = 0; i < characters.length; i++)
                  _buildHanziProgressChip(characters[i], i, activeIndex),
              ],
            ),
          ),
        ],
        SizedBox(height: DuolingoSpacing.lg),
        Center(child: _buildAudioButton(size: 44, iconSize: 22)),
        SizedBox(height: DuolingoSpacing.lg),
        Center(
          child: HanziWriterTrace(
            key: ValueKey(
              'hanzi-$_index-$_traceVersion-$activeIndex-${characters[activeIndex]}',
            ),
            character: characters[activeIndex],
            size: traceSize,
            controller: _hanziController,
            onComplete: _onHanziCharComplete,
            onUnavailable: () => setState(() => _hanziQuizAvailable = false),
          ),
        ),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _checked
                    ? null
                    : () => _hanziController.showStrokeOrder(),
                child: Text(
                  'Show me ✍️',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.informationBlue,
                  ),
                ),
              ),
              SizedBox(width: DuolingoSpacing.md),
              TextButton(
                onPressed: _checked
                    ? null
                    : () => setState(() => _traceVersion++),
                child: Text(
                  'Restart',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.bodyText,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isSentenceTrace) Center(child: _buildTypeInsteadButton()),
        if (!_checked) _buildSkipButton(),
      ],
    );
  }

  /// Skips only the character being written; on the last character (or a
  /// single-character word) the exercise ends ungraded. Hidden via the
  /// Profile setting.
  void _skipWriting() {
    final inQuiz = _hanziQuizAvailable == true;
    if (inQuiz && _hanziCharIndex + 1 < _writeChars.length) {
      setState(() {
        _skippedChar = true;
        _hanziCharIndex++;
      });
    } else {
      _advance();
    }
  }

  /// (Skip is ungraded: no reward, no penalty, no review submitted.)
  Widget _buildSkipButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.showSkipWriting,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return Center(
          child: TextButton(
            onPressed: _skipWriting,
            child: Text(
              'Skip',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
          ),
        );
      },
    );
  }

  /// A long sentence only asks for its hardest characters (shown as chips
  /// in place); everything else is displayed as plain text for context.
  /// [activeIndex] is which key character is currently being written.
  Widget _buildSentenceContext(int activeIndex) {
    var keyIndex = 0;
    final written = <String>{};
    final chips = <Widget>[];
    for (final ch in _current.word.text.split('')) {
      final isKey =
          _writeChars.contains(ch) && !written.contains(ch) && isCjkChar(ch);
      if (isKey) {
        written.add(ch);
        chips.add(_buildHanziProgressChip(ch, keyIndex, activeIndex));
        keyIndex++;
      } else {
        chips.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              ch,
              style: TextStyle(
                fontSize: 22,
                color: DuolingoColors.darkText.withOpacity(0.7),
              ),
            ),
          ),
        );
      }
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        color: DuolingoColors.neutralGray,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: DuolingoSpacing.xs,
        children: chips,
      ),
    );
  }

  Widget _buildTypeInsteadButton() {
    return TextButton(
      onPressed: _checked
          ? null
          : () => setState(() {
              _typeInstead = true;
              _typingController.clear();
            }),
      child: Text(
        'Type it instead ⌨️',
        style: DuolingoTextStyles.label.copyWith(
          color: DuolingoColors.informationBlue,
        ),
      ),
    );
  }

  /// Keyboard alternative to handwriting a long sentence: the child copies
  /// the sentence with their own input method, graded on characters only.
  Widget _buildTypedSentence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type the sentence', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.lg),
        Center(child: _buildAudioButton(size: 56, iconSize: 28)),
        SizedBox(height: DuolingoSpacing.lg),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(DuolingoSpacing.xl),
          decoration: BoxDecoration(
            color: DuolingoColors.neutralGray,
            borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          ),
          child: Text(
            _current.word.text,
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.darkText,
              fontSize: 22,
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.xl),
        TextField(
          controller: _typingController,
          enabled: !_checked,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          style: DuolingoTextStyles.cardTitle.copyWith(fontSize: 22),
          decoration: InputDecoration(
            hintText: 'Type it here...',
            hintStyle: DuolingoTextStyles.body.copyWith(
              color: DuolingoColors.secondaryButtonGray,
            ),
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
                color: DuolingoColors.informationBlue,
                width: 2,
              ),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _checked
                ? null
                : () => setState(() {
                    _typeInstead = false;
                    _traceVersion++;
                  }),
            child: Text(
              'Write it by hand instead ✍️',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.informationBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHanziProgressChip(String char, int index, int activeIndex) {
    final done = index < activeIndex;
    final active = index == activeIndex;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done
            ? DuolingoColors.primaryGreen.withOpacity(0.15)
            : (active ? DuolingoColors.neutralGray : Colors.transparent),
        border: Border.all(
          color: active
              ? DuolingoColors.informationBlue
              : const Color(0xFFE5E5E5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        char,
        style: TextStyle(
          fontSize: 18,
          color: done ? DuolingoColors.primaryGreen : DuolingoColors.darkText,
        ),
      ),
    );
  }

  Widget _buildFreeTrace(Size area) {
    // word.text can be a single hanzi ("的") or a multi-character word,
    // phrase, or whole dictation sentence ("螃蟹米粉", "我们必须靠自己的
    // 力量捍卫新加坡。") — trace one box per character instead of cramming
    // the whole string into a single box sized for one glyph.
    final characters = _writeChars;
    final isSingle = characters.length == 1;
    final title = isSingle
        ? 'Trace the character'
        : 'Trace these ${characters.length} characters';
    // Single box fills the height left over; several share one row when
    // they fit (and wrap when they don't).
    final singleSize = (area.height - (_isSentenceTrace ? 250 : 170)).clamp(
      120.0,
      220.0,
    );
    final multiSize =
        ((area.width - (characters.length - 1) * DuolingoSpacing.sm) /
                characters.length)
            .clamp(80.0, 140.0);

    Widget traceBox(String char, int index, double size, double fontSize) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: DuolingoColors.neutralGray,
          border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                char,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: DuolingoColors.darkText.withOpacity(0.15),
                ),
              ),
            ),
            Positioned.fill(
              child: HandwritingCanvas(
                key: ValueKey('trace-$_index-$_traceVersion-$index'),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: DuolingoTextStyles.sectionTitle),
        if (_isSentenceTrace) ...[
          SizedBox(height: DuolingoSpacing.md),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(DuolingoSpacing.md),
            decoration: BoxDecoration(
              color: DuolingoColors.neutralGray,
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            ),
            child: Text(
              _current.word.text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, color: DuolingoColors.darkText),
            ),
          ),
        ],
        SizedBox(height: DuolingoSpacing.lg),
        Center(child: _buildAudioButton(size: 44, iconSize: 22)),
        SizedBox(height: DuolingoSpacing.lg),
        isSingle
            ? Center(
                child: traceBox(
                  characters.first,
                  0,
                  singleSize,
                  singleSize * 0.73,
                ),
              )
            : Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: DuolingoSpacing.sm,
                  runSpacing: DuolingoSpacing.sm,
                  children: [
                    for (var i = 0; i < characters.length; i++)
                      traceBox(characters[i], i, multiSize, multiSize * 0.7),
                  ],
                ),
              ),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: TextButton(
            onPressed: _checked ? null : () => setState(() => _traceVersion++),
            child: Text(
              'Clear',
              style: DuolingoTextStyles.label.copyWith(
                color: DuolingoColors.bodyText,
              ),
            ),
          ),
        ),
        if (_isSentenceTrace) Center(child: _buildTypeInsteadButton()),
        if (!_checked) _buildSkipButton(),
      ],
    );
  }

  // --- Chinese: Voice input (read the character aloud) ---

  Widget _buildVoiceRead() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Read it aloud', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(
          child: Text(
            _current.word.text,
            style: DuolingoTextStyles.pageTitle.copyWith(
              fontSize: 72,
              color: DuolingoColors.darkText,
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(
          child: GestureDetector(
            onTap: _checked || _isRecording ? null : _recordVoiceAnswer,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _isRecording
                    ? DuolingoColors.mistakeRed
                    : DuolingoColors.informationBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _isRecording
                        ? const Color(0xFFC22B2B)
                        : const Color(0xFF1876BF),
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            _isRecording
                ? 'Listening...'
                : (_voiceTranscript == null
                      ? 'Tap the mic and say the word'
                      : 'Heard: "$_voiceTranscript" — tap CHECK, or tap the mic to try again'),
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
        ),
        if (_voiceUnsupported) ...[
          SizedBox(height: DuolingoSpacing.lg),
          Center(
            child: TextButton(
              onPressed: _checked
                  ? null
                  : () => setState(() => _voiceTranscript = _current.word.text),
              child: Text(
                "Can't record? Tap here if you read it correctly",
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  color: DuolingoColors.informationBlue,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // --- Missing Letters / Build the Word (letter tile games) ---

  Widget _buildLetterGame(String prompt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(prompt, style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xl),
        Center(child: _buildAudioButton(size: 56, iconSize: 28)),
        SizedBox(height: DuolingoSpacing.xxl),
        // Word slots
        Center(
          child: Wrap(spacing: 6, runSpacing: 8, children: _buildSlotTiles()),
        ),
        SizedBox(height: DuolingoSpacing.xxl * 1.5),
        // Letter bank
        Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _buildBankTiles(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSlotTiles() {
    final tiles = <Widget>[];
    var blankIdx = 0;
    for (final s in _current.slots) {
      if (s != null) {
        tiles.add(_slotTile(letter: s, fixed: true));
      } else {
        final idx = blankIdx;
        final bankIdx = _blankFill[idx];
        tiles.add(
          GestureDetector(
            onTap: _checked || bankIdx == null
                ? null
                : () => setState(() => _blankFill[idx] = null),
            child: _slotTile(
              letter: bankIdx == null ? '' : _current.bank[bankIdx],
              fixed: false,
            ),
          ),
        );
        blankIdx++;
      }
    }
    return tiles;
  }

  Widget _slotTile({required String letter, required bool fixed}) {
    final filled = letter.isNotEmpty;
    return Container(
      width: 38,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fixed
            ? DuolingoColors.neutralGray
            : (filled ? const Color(0xFFDDF4FF) : Colors.white),
        border: Border.all(
          color: fixed
              ? Colors.transparent
              : (filled
                    ? DuolingoColors.informationBlue
                    : const Color(0xFFE5E5E5)),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        letter,
        style: DuolingoTextStyles.cardTitle.copyWith(
          fontSize: 22,
          color: fixed ? DuolingoColors.darkText : const Color(0xFF1899D6),
        ),
      ),
    );
  }

  List<Widget> _buildBankTiles() {
    final usedIdxs = _blankFill.whereType<int>().toSet();
    final tiles = <Widget>[];
    for (var i = 0; i < _current.bank.length; i++) {
      final used = usedIdxs.contains(i);
      tiles.add(
        GestureDetector(
          onTap: _checked || used
              ? null
              : () {
                  final nextBlank = _blankFill.indexOf(null);
                  if (nextBlank != -1) {
                    setState(() => _blankFill[nextBlank] = i);
                    _soundService.playPop();
                  }
                },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: used ? 0.25 : 1,
            child: Container(
              width: 44,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFE5E5E5),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                _current.bank[i],
                style: DuolingoTextStyles.cardTitle.copyWith(
                  fontSize: 22,
                  color: DuolingoColors.darkText,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return tiles;
  }

  // --- Listen & Type ---

  Widget _buildTypeWord() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type what you hear', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(child: _buildAudioButton()),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            'Tap to hear the word again',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
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
            hintText: 'Type the word...',
            hintStyle: DuolingoTextStyles.body.copyWith(
              color: DuolingoColors.secondaryButtonGray,
            ),
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
                color: DuolingoColors.informationBlue,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Sentence Fill-in (type the missing word) ---

  Widget _buildSentenceBlank() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fill in the missing word',
          style: DuolingoTextStyles.sectionTitle,
        ),
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
            hintStyle: DuolingoTextStyles.body.copyWith(
              color: DuolingoColors.secondaryButtonGray,
            ),
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
                color: DuolingoColors.informationBlue,
                width: 2,
              ),
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

  // --- Bottom panel: CHECK / feedback / GOT IT ---

  Widget _buildBottomPanel() {
    // Learn card: single always-enabled button, no checking
    if (_current.type == ExerciseType.learn) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 2)),
        ),
        child: _buildBigButton(
          label: 'GOT IT!',
          enabled: true,
          color: DuolingoColors.primaryGreen,
          shadowColor: const Color(0xFF58A700),
          onTap: _continue,
        ),
      );
    }

    // Guided HanziWriter quiz mode auto-grades on completion (see
    // _onHanziCharComplete) — no button needed, just a hint while tracing.
    if (_current.type == ExerciseType.handwriteTrace &&
        !_typeInstead &&
        _hanziQuizAvailable == true &&
        !_checked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 2)),
        ),
        child: Text(
          'Trace each stroke in order — it\'ll fill in automatically ✍️',
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.label.copyWith(
            color: DuolingoColors.bodyText,
          ),
        ),
      );
    }

    // Free-draw trace fallback has no auto-gradable input (no OCR) — the
    // child self-reports instead of hitting a CHECK button.
    if (_current.type == ExerciseType.handwriteTrace &&
        !_typeInstead &&
        !_checked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildBigButton(
                label: 'NEED PRACTICE',
                enabled: true,
                color: DuolingoColors.secondaryButtonGray,
                shadowColor: const Color(0xFFAAAAAA),
                onTap: () => _selfGrade(false),
              ),
            ),
            SizedBox(width: DuolingoSpacing.md),
            Expanded(
              child: _buildBigButton(
                label: 'I WROTE IT!',
                enabled: true,
                color: DuolingoColors.primaryGreen,
                shadowColor: const Color(0xFF58A700),
                onTap: () => _selfGrade(true),
              ),
            ),
          ],
        ),
      );
    }

    if (!_checked) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE5E5E5), width: 2)),
        ),
        child: _buildBigButton(
          label: 'CHECK',
          enabled: _hasAnswer,
          color: DuolingoColors.primaryGreen,
          shadowColor: const Color(0xFF58A700),
          onTap: _check,
        ),
      );
    }

    final panelColor = _wasCorrect
        ? const Color(0xFFD7FFB8)
        : const Color(0xFFFFDFE0);
    final accent = _wasCorrect
        ? const Color(0xFF58A700)
        : const Color(0xFFEA2B2B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: EdgeInsets.all(DuolingoSpacing.xl),
      color: panelColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _wasCorrect
                    ? const Text('🐕', style: TextStyle(fontSize: 24))
                    : Icon(Icons.close, color: accent, size: 30),
              ),
              SizedBox(width: DuolingoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _wasCorrect ? _lastPraise : _lastEncouragement,
                      style: DuolingoTextStyles.sectionTitle.copyWith(
                        color: accent,
                        fontSize: 17,
                      ),
                    ),
                    if (_voiceStars != null)
                      Padding(
                        padding: EdgeInsets.only(top: DuolingoSpacing.xs),
                        child: Row(
                          children: List.generate(
                            3,
                            (i) => Text(
                              i < _voiceStars! ? '⭐' : '☆',
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                      ),
                    if (!_wasCorrect)
                      Text(
                        'Correct answer: $_targetAnswer',
                        style: DuolingoTextStyles.cardTitle.copyWith(
                          color: accent,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
              if (_wasCorrect)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.md,
                    vertical: DuolingoSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      DuolingoSpacing.radiusBadge,
                    ),
                  ),
                  child: Text(
                    _current.isRetry ? '+5 XP' : '+10 XP',
                    style: DuolingoTextStyles.cardTitle.copyWith(
                      color: DuolingoColors.streakOrange,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: DuolingoSpacing.lg),
          _buildBigButton(
            label: 'CONTINUE',
            enabled: true,
            color: _wasCorrect
                ? DuolingoColors.primaryGreen
                : DuolingoColors.mistakeRed,
            shadowColor: _wasCorrect
                ? const Color(0xFF58A700)
                : const Color(0xFFC22B2B),
            onTap: _continue,
          ),
        ],
      ),
    );
  }

  Widget _buildBigButton({
    required String label,
    required bool enabled,
    required Color color,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: DuolingoSpacing.largeButton,
        decoration: BoxDecoration(
          color: enabled ? color : DuolingoColors.neutralGray,
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: shadowColor,
                    offset: const Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: DuolingoTextStyles.cardTitle.copyWith(
            color: enabled ? Colors.white : DuolingoColors.secondaryButtonGray,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // --- Summary (stars, XP, coins, weak words) ---

  Widget _buildSummary() {
    final accuracy = _totalWords == 0
        ? 0
        : (_firstTryCorrect / _totalWords * 100).round();
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.xxl),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: _celebrationScale,
                child: Column(
                  children: [
                    const Text('🎉', style: TextStyle(fontSize: 80)),
                    SizedBox(height: DuolingoSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            i < _stars ? '⭐' : '☆',
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                'Adventure complete!',
                style: DuolingoTextStyles.pageTitle.copyWith(
                  color: DuolingoColors.treasureGold,
                  fontSize: 26,
                ),
              ),
              SizedBox(height: DuolingoSpacing.xxl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildResultCard(
                    title: 'TOTAL XP',
                    value: '⚡ $_earnedXp',
                    color: DuolingoColors.streakOrange,
                  ),
                  SizedBox(width: DuolingoSpacing.md),
                  _buildResultCard(
                    title: 'ACCURACY',
                    value: '🎯 $accuracy%',
                    color: DuolingoColors.primaryGreen,
                  ),
                  SizedBox(width: DuolingoSpacing.md),
                  _buildResultCard(
                    title: 'COINS',
                    value: '💰 $_earnedCoins',
                    color: DuolingoColors.treasureGold,
                  ),
                ],
              ),
              if (_progressSaveFailed) ...[
                SizedBox(height: DuolingoSpacing.lg),
                Container(
                  padding: EdgeInsets.all(DuolingoSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(
                      DuolingoSpacing.radiusCard,
                    ),
                  ),
                  child: Text(
                    "Couldn't save your progress - check your connection "
                    'and try this adventure again so it counts.',
                    textAlign: TextAlign.center,
                    style: DuolingoTextStyles.body.copyWith(
                      color: const Color(0xFF856404),
                    ),
                  ),
                ),
              ],
              if (_weakWords.isNotEmpty) ...[
                SizedBox(height: DuolingoSpacing.xxl),
                Text(
                  'Words to practice again:',
                  style: DuolingoTextStyles.label.copyWith(
                    color: DuolingoColors.bodyText,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _weakWords
                      .map(
                        (w) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: DuolingoSpacing.md,
                            vertical: DuolingoSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFDFE0),
                            borderRadius: BorderRadius.circular(
                              DuolingoSpacing.radiusBadge,
                            ),
                          ),
                          child: Text(
                            w,
                            style: DuolingoTextStyles.body.copyWith(
                              color: const Color(0xFFEA2B2B),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const Spacer(),
              _buildBigButton(
                label: 'CONTINUE ADVENTURE',
                enabled: true,
                color: DuolingoColors.primaryGreen,
                shadowColor: const Color(0xFF58A700),
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 105,
      padding: EdgeInsets.all(DuolingoSpacing.xs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.xs),
            child: Text(
              title,
              style: DuolingoTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.md),
            decoration: BoxDecoration(
              color: DuolingoColors.backgroundWhite,
              borderRadius: BorderRadius.circular(
                DuolingoSpacing.radiusCard - 4,
              ),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.cardTitle.copyWith(
                color: color,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
