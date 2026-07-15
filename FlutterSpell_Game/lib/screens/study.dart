import 'package:flutter/material.dart';
import 'dart:math';
import '../design_system/design_system.dart';
import '../models/game_models.dart';
import '../services/sound_service.dart';
import '../widgets/celebration.dart';
import '../widgets/handwriting_canvas.dart';
import '../services/speech_recognition_service.dart';
import '../utils/exercise_content_parser.dart';
import '../main.dart' show gameProvider;
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
  int _traceVersion = 0; // bumped by "Clear" to reset the handwriting canvas

  // Session stats
  int _totalWords = 0;
  int _firstTryCorrect = 0;
  int _earnedXp = 0;
  int _earnedCoins = 0;
  final Set<String> _weakWords = {};
  String _lastPraise = '';
  String _lastEncouragement = '';

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

  @override
  void initState() {
    super.initState();
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
      await gameProvider.loadDeck(tags: widget.args.tags);
      var cards = gameProvider.deckCards;

      if (cards.isEmpty) {
        setState(() => _phase = SessionPhase.empty);
        return;
      }

      cards = List<DeckCard>.from(cards)..shuffle(_random);
      _totalWords = cards.length;

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
          final type =
              _typeForMastery(card.repetitions, hasSentence: hasSentence);
          _queue.add(_buildExercise(card.word, type));
        }
      }

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

  /// Recognition -> production ladder for the read/listen side of a
  /// Chinese word. Handwriting is handled separately in _loadWords, gated
  /// by the lesson's skill tags rather than mastery, so it doesn't take
  /// multiple sessions to become reachable.
  ExerciseType _typeForMasteryChinese(int mastery) {
    return mastery <= 1 ? ExerciseType.listenChoose : ExerciseType.voiceRead;
  }

  _Exercise _buildExercise(Word word, ExerciseType type,
      {bool isRetry = false}) {
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
    '的', '一', '是', '了', '我', '不', '人', '在', '他', '有',
    '这', '个', '上', '们', '来', '到', '时', '大', '地', '为',
  ];

  /// Distractor characters for Listen & Choose: prefer sibling characters
  /// from this lesson so choices stay visually plausible; pad with common
  /// characters if the lesson is too small to have three others.
  List<String> _buildCharacterChoices(String target) {
    final distractors = _chineseDistractorPool
        .where((t) => t != target)
        .toList()
      ..shuffle(_random);
    final picked = distractors.take(3).toList();
    var guard = 0;
    while (picked.length < 3 && guard < 30) {
      guard++;
      final c = _fallbackCharacters[_random.nextInt(_fallbackCharacters.length)];
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
    final blanks = _current.slots.where((s) => s == null).length;
    _blankFill = List<int?>.filled(blanks, null);
  }

  void _autoPlayCurrentWord() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phase == SessionPhase.exercising) {
        _soundService.playWordPronunciation(_current.word.text);
      }
    });
  }

  String _assembledAnswer() {
    switch (_current.type) {
      case ExerciseType.chooseSpelling:
      case ExerciseType.listenChoose:
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
      default:
        return false;
    }
  }

  void _check() {
    final correct = _current.type == ExerciseType.voiceRead
        // Speech-recognition transcripts can carry extra punctuation/noise
        // around the character, so a lenient contains-check avoids
        // penalizing a correct reading over transcription noise.
        ? (_voiceTranscript ?? '').contains(_targetAnswer)
        : _assembledAnswer().toLowerCase() == _targetAnswer.toLowerCase();
    _applyResult(correct);
  }

  /// Handwriting trace has no auto-gradable input (no OCR) — the child
  /// self-reports whether they wrote it correctly, and that feeds the same
  /// reward/retry/SRS pipeline as an auto-graded answer.
  void _selfGrade(bool gotIt) => _applyResult(gotIt);

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

  void _applyResult(bool correct) {
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
      } else {
        _weakWords.add(_current.word.text);
        // Missed word returns later with an easier exercise
        final retryType = _isChineseWord(_current.word.text)
            ? ExerciseType.listenChoose
            : ExerciseType.chooseSpelling;
        _queue.add(_buildExercise(
          _current.word,
          retryType,
          isRetry: true,
        ));
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
    final quality = correct ? (_current.isRetry ? 3 : 5) : 1;
    gameProvider.submitReview(_current.word.id, quality);
  }

  void _continue() {
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
    // Per-word /review calls already advanced ReviewState (and each earned
    // a point); refresh the cached stats so points/streak reflect them.
    await gameProvider.loadUserStats();
  }

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
            'You\'ll lose your progress in this adventure if you quit now.'),
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
            Text('No words to study yet!',
                style: DuolingoTextStyles.sectionTitle),
            SizedBox(height: DuolingoSpacing.sm),
            Text(
              'Ask your teacher to add words to your deck.',
              style: DuolingoTextStyles.body
                  .copyWith(color: DuolingoColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseScreen() {
    final progress = _index / _queue.length;
    return Scaffold(
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
                      offset: Offset(dx, 0), child: child);
                },
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.xxl,
                    vertical: DuolingoSpacing.lg,
                  ),
                  child: _buildExerciseBody(),
                ),
              ),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
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

  Widget _buildTopBar(double progress) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: DuolingoSpacing.lg,
        vertical: DuolingoSpacing.md,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close,
                color: DuolingoColors.secondaryButtonGray, size: 28),
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
                      DuolingoColors.primaryGreen),
                ),
              ),
            ),
          ),
          SizedBox(width: DuolingoSpacing.md),
          const Text('⚡', style: TextStyle(fontSize: 18)),
          Text(
            '$_earnedXp',
            style: DuolingoTextStyles.cardTitle
                .copyWith(color: DuolingoColors.streakOrange),
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
            border:
                Border.all(color: DuolingoColors.informationBlue, width: 2),
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
                style: DuolingoTextStyles.label
                    .copyWith(color: DuolingoColors.bodyText),
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
        Text('Tap the correct spelling',
            style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(child: _buildAudioButton()),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            'Tap to hear the word',
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.bodyText),
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
        onTap:
            _checked ? null : () => setState(() => _selectedChoice = choice),
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
        Text('Tap the character you hear',
            style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.xxl),
        Center(child: _buildAudioButton()),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: Text(
            'Tap to hear it again',
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.bodyText),
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

  Widget _buildCharacterChoiceTile(String choice) {
    final selected = _selectedChoice == choice;
    final isCorrectChoice = choice == _current.word.text;

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

  // --- Chinese: Handwriting trace (self-graded, no OCR) ---

  Widget _buildHandwriteTrace() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trace the character', style: DuolingoTextStyles.sectionTitle),
        SizedBox(height: DuolingoSpacing.lg),
        Center(child: _buildAudioButton(size: 56, iconSize: 28)),
        SizedBox(height: DuolingoSpacing.lg),
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: DuolingoColors.neutralGray,
              border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
              borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _current.word.text,
                    style: TextStyle(
                      fontSize: 160,
                      fontWeight: FontWeight.bold,
                      color: DuolingoColors.darkText.withOpacity(0.15),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: HandwritingCanvas(
                    key: ValueKey('trace-$_index-$_traceVersion'),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: DuolingoSpacing.sm),
        Center(
          child: TextButton(
            onPressed:
                _checked ? null : () => setState(() => _traceVersion++),
            child: Text(
              'Clear',
              style:
                  DuolingoTextStyles.label.copyWith(color: DuolingoColors.bodyText),
            ),
          ),
        ),
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
            style: DuolingoTextStyles.pageTitle
                .copyWith(fontSize: 72, color: DuolingoColors.darkText),
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
              child: Icon(_isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white, size: 40),
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
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.bodyText),
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
                style: DuolingoTextStyles.label
                    .copyWith(color: DuolingoColors.informationBlue),
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
          child: Wrap(
            spacing: 6,
            runSpacing: 8,
            children: _buildSlotTiles(),
          ),
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
        tiles.add(GestureDetector(
          onTap: _checked || bankIdx == null
              ? null
              : () => setState(() => _blankFill[idx] = null),
          child: _slotTile(
            letter: bankIdx == null ? '' : _current.bank[bankIdx],
            fixed: false,
          ),
        ));
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
          color: fixed
              ? DuolingoColors.darkText
              : const Color(0xFF1899D6),
        ),
      ),
    );
  }

  List<Widget> _buildBankTiles() {
    final usedIdxs = _blankFill.whereType<int>().toSet();
    final tiles = <Widget>[];
    for (var i = 0; i < _current.bank.length; i++) {
      final used = usedIdxs.contains(i);
      tiles.add(GestureDetector(
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
      ));
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
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.bodyText),
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
            hintStyle: DuolingoTextStyles.body
                .copyWith(color: DuolingoColors.secondaryButtonGray),
            filled: true,
            fillColor: DuolingoColors.neutralGray,
            contentPadding: EdgeInsets.all(DuolingoSpacing.xl),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(DuolingoSpacing.radiusButton),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(DuolingoSpacing.radiusButton),
              borderSide: const BorderSide(
                  color: DuolingoColors.informationBlue, width: 2),
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

    // Handwriting trace has no auto-gradable input (no OCR) — the child
    // self-reports instead of hitting a CHECK button.
    if (_current.type == ExerciseType.handwriteTrace && !_checked) {
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

    final panelColor =
        _wasCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0);
    final accent =
        _wasCorrect ? const Color(0xFF58A700) : const Color(0xFFEA2B2B);

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
                      style: DuolingoTextStyles.sectionTitle
                          .copyWith(color: accent, fontSize: 17),
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
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusBadge),
                  ),
                  child: Text(
                    _current.isRetry ? '+5 XP' : '+10 XP',
                    style: DuolingoTextStyles.cardTitle
                        .copyWith(color: DuolingoColors.streakOrange),
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
            shadowColor:
                _wasCorrect ? const Color(0xFF58A700) : const Color(0xFFC22B2B),
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
            color:
                enabled ? Colors.white : DuolingoColors.secondaryButtonGray,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  // --- Summary (stars, XP, coins, weak words) ---

  Widget _buildSummary() {
    final accuracy =
        _totalWords == 0 ? 0 : (_firstTryCorrect / _totalWords * 100).round();
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
                    color: DuolingoColors.treasureGold, fontSize: 26),
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
              if (_weakWords.isNotEmpty) ...[
                SizedBox(height: DuolingoSpacing.xxl),
                Text(
                  'Words to practice again:',
                  style: DuolingoTextStyles.label
                      .copyWith(color: DuolingoColors.bodyText),
                ),
                SizedBox(height: DuolingoSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _weakWords
                      .map((w) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: DuolingoSpacing.md,
                              vertical: DuolingoSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFDFE0),
                              borderRadius: BorderRadius.circular(
                                  DuolingoSpacing.radiusBadge),
                            ),
                            child: Text(
                              w,
                              style: DuolingoTextStyles.body.copyWith(
                                color: const Color(0xFFEA2B2B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ))
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
              borderRadius:
                  BorderRadius.circular(DuolingoSpacing.radiusCard - 4),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.cardTitle
                  .copyWith(color: color, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
