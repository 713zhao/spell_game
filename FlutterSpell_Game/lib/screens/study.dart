import 'package:flutter/material.dart';
import 'dart:math';
import '../design_system/design_system.dart';
import '../models/game_models.dart';
import '../services/sound_service.dart';
import '../main.dart' show gameProvider;

/// Duolingo-style study session:
/// - One exercise at a time with a progress bar on top
/// - Immediate feedback panel slides up after every answer
/// - Missed words are re-queued until answered correctly
/// - Celebration screen with XP + accuracy at the end
class StudyScreen extends StatefulWidget {
  final int levelId;

  const StudyScreen({Key? key, required this.levelId}) : super(key: key);

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

enum ExerciseType { chooseSpelling, typeWord }

enum SessionPhase { loading, empty, exercising, complete }

class _Exercise {
  final Word word;
  final ExerciseType type;
  final List<String> choices;
  final bool isRetry;

  _Exercise({
    required this.word,
    required this.type,
    required this.choices,
    this.isRetry = false,
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
  bool _checked = false;
  bool _wasCorrect = false;

  // Session stats
  int _totalWords = 0;
  int _firstTryCorrect = 0;
  int _earnedXp = 0;
  String _lastPraise = '';

  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;

  static const List<String> _praises = [
    'Nicely done!',
    'Awesome!',
    'Amazing!',
    'Great job!',
    'Excellent!',
    'You got it!',
    'Perfect!',
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
    _soundService.init();
    _loadWords();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    try {
      // Primary source: the user's real word deck from the backend
      if (gameProvider.deckWords.isEmpty) {
        await gameProvider.loadDeck();
      }
      var words = gameProvider.deckWords;

      // Fallback: words attached to the level (if any)
      if (words.isEmpty) {
        await gameProvider.loadLevelDetails(widget.levelId);
        words = gameProvider.currentLevel?.words ?? [];
      }

      // Prefer English words for the spelling exercises
      final english = words
          .where((w) =>
              w.language.toLowerCase() == 'english' ||
              w.language.toLowerCase() == 'en')
          .toList();
      if (english.isNotEmpty) words = english;

      if (words.isEmpty) {
        setState(() => _phase = SessionPhase.empty);
        return;
      }

      words = List<Word>.from(words)..shuffle(_random);
      _totalWords = words.length;
      _queue = words.map(_buildExercise).toList();

      setState(() => _phase = SessionPhase.exercising);
      _autoPlayCurrentWord();
    } catch (e) {
      setState(() => _phase = SessionPhase.empty);
    }
  }

  _Exercise _buildExercise(Word word, {bool isRetry = false}) {
    final type = _random.nextBool()
        ? ExerciseType.chooseSpelling
        : ExerciseType.typeWord;
    return _Exercise(
      word: word,
      type: type,
      choices:
          type == ExerciseType.chooseSpelling ? _buildChoices(word.text) : [],
      isRetry: isRetry,
    );
  }

  /// Generate 3 plausible misspellings + the correct word, shuffled.
  List<String> _buildChoices(String word) {
    final wrong = <String>{};
    final lower = word.toLowerCase();
    var guard = 0;
    while (wrong.length < 3 && guard < 60) {
      guard++;
      final candidate = _misspell(lower);
      if (candidate != lower && candidate.isNotEmpty) {
        wrong.add(candidate);
      }
    }
    final options = <String>[lower, ...wrong];
    options.shuffle(_random);
    return options;
  }

  String _misspell(String word) {
    if (word.length < 3) return word;
    const vowels = 'aeiou';
    final chars = word.split('');
    switch (_random.nextInt(4)) {
      case 0: // swap two adjacent letters
        final i = _random.nextInt(word.length - 1);
        final t = chars[i];
        chars[i] = chars[i + 1];
        chars[i + 1] = t;
        break;
      case 1: // double a letter
        final i = _random.nextInt(word.length);
        chars.insert(i, chars[i]);
        break;
      case 2: // drop a letter
        chars.removeAt(_random.nextInt(word.length));
        break;
      default: // substitute a vowel
        final vowelIdxs = <int>[];
        for (var i = 0; i < chars.length; i++) {
          if (vowels.contains(chars[i])) vowelIdxs.add(i);
        }
        if (vowelIdxs.isEmpty) return _misspell(word);
        final i = vowelIdxs[_random.nextInt(vowelIdxs.length)];
        final replacement =
            vowels[_random.nextInt(vowels.length)];
        chars[i] = replacement;
    }
    return chars.join();
  }

  _Exercise get _current => _queue[_index];

  void _autoPlayCurrentWord() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_phase == SessionPhase.exercising) {
        _soundService.playWordPronunciation(_current.word.text);
      }
    });
  }

  bool get _hasAnswer {
    if (_checked) return false;
    if (_current.type == ExerciseType.chooseSpelling) {
      return _selectedChoice != null;
    }
    return _typingController.text.trim().isNotEmpty;
  }

  void _check() {
    final answer = _current.type == ExerciseType.chooseSpelling
        ? (_selectedChoice ?? '')
        : _typingController.text.trim();
    final correct =
        answer.toLowerCase() == _current.word.text.toLowerCase();

    setState(() {
      _checked = true;
      _wasCorrect = correct;
      _lastPraise = _praises[_random.nextInt(_praises.length)];
      if (correct) {
        if (_current.isRetry) {
          _earnedXp += 5;
        } else {
          _earnedXp += 10;
          _firstTryCorrect++;
        }
        _soundService.playCorrectAnswer();
      } else {
        // Duolingo behavior: missed word comes back later in the session
        _queue.add(_buildExercise(_current.word, isRetry: true));
        _soundService.playIncorrectAnswer();
      }
    });
  }

  void _continue() {
    if (_index + 1 >= _queue.length) {
      _finishSession();
      return;
    }
    setState(() {
      _index++;
      _checked = false;
      _wasCorrect = false;
      _selectedChoice = null;
      _typingController.clear();
    });
    _autoPlayCurrentWord();
  }

  Future<void> _finishSession() async {
    setState(() => _phase = SessionPhase.complete);
    _celebrationController.forward(from: 0);
    _soundService.playLevelComplete();
    final accuracy =
        _totalWords == 0 ? 0.0 : _firstTryCorrect / _totalWords;
    // Report to backend (updates stars/progress and reloads stats)
    await gameProvider.completeLevel(widget.levelId, accuracy);
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
            'You\'ll lose your progress in this lesson if you quit now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'KEEP LEARNING',
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
        return _buildCelebration();
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
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.xxl,
                  vertical: DuolingoSpacing.lg,
                ),
                child: _current.type == ExerciseType.chooseSpelling
                    ? _buildChooseSpelling()
                    : _buildTypeWord(),
              ),
            ),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
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
    final isCorrectChoice =
        choice.toLowerCase() == _current.word.text.toLowerCase();

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
        onTap: _checked
            ? null
            : () => setState(() => _selectedChoice = choice),
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
            borderRadius:
                BorderRadius.circular(DuolingoSpacing.radiusButton),
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

  /// The bottom area: CHECK button before answering, then it transforms into
  /// the Duolingo-style instant feedback panel with CONTINUE.
  Widget _buildBottomPanel() {
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _wasCorrect ? Icons.check : Icons.close,
                  color: accent,
                  size: 30,
                ),
              ),
              SizedBox(width: DuolingoSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _wasCorrect ? _lastPraise : 'Correct answer:',
                      style: DuolingoTextStyles.sectionTitle
                          .copyWith(color: accent),
                    ),
                    if (!_wasCorrect)
                      Text(
                        _current.word.text,
                        style: DuolingoTextStyles.cardTitle.copyWith(
                          color: accent,
                          fontSize: 20,
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
            color: enabled
                ? Colors.white
                : DuolingoColors.secondaryButtonGray,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCelebration() {
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
                child: const Text('🎉', style: TextStyle(fontSize: 96)),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              Text(
                'Lesson complete!',
                style: DuolingoTextStyles.pageTitle
                    .copyWith(color: DuolingoColors.treasureGold, fontSize: 28),
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
                  SizedBox(width: DuolingoSpacing.lg),
                  _buildResultCard(
                    title: 'ACCURACY',
                    value: '🎯 $accuracy%',
                    color: DuolingoColors.primaryGreen,
                  ),
                ],
              ),
              const Spacer(),
              _buildBigButton(
                label: 'CONTINUE',
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
      width: 140,
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
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
            decoration: BoxDecoration(
              color: DuolingoColors.backgroundWhite,
              borderRadius:
                  BorderRadius.circular(DuolingoSpacing.radiusCard - 4),
            ),
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.cardTitle.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
