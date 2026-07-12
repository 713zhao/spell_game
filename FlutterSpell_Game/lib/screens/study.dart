import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_provider.dart';
import '../models/game_models.dart';
import '../services/sound_service.dart';
import '../widgets/point_pop_animation.dart';
import '../widgets/star_animation.dart';
import '../widgets/confetti_animation.dart';

class StudyScreen extends StatefulWidget {
  final int levelId;

  const StudyScreen({Key? key, required this.levelId}) : super(key: key);

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

enum ChallengeType { multipleChoice, typing, speech }

class _StudyScreenState extends State<StudyScreen> with TickerProviderStateMixin {
  late List<Word> words;
  int currentWordIndex = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  bool isAnswered = false;
  bool isCorrect = false;
  late AnimationController _popAnimationController;
  late AnimationController _feedbackAnimationController;
  late Animation<double> _popAnimation;
  late Animation<double> _feedbackAnimation;
  ChallengeType? currentChallengeType;
  String userAnswer = '';
  String? selectedChoice;
  bool isLoading = true;
  String? errorMessage;
  late SoundService _soundService;

  final Random _random = Random();
  final List<ChallengeType> _challengeTypes = [
    ChallengeType.multipleChoice,
    ChallengeType.typing,
    ChallengeType.speech,
  ];

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();

    _popAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _popAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _popAnimationController, curve: Curves.elasticOut),
    );

    _feedbackAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _feedbackAnimationController, curve: Curves.easeInOut),
    );

    _loadLevel();
  }

  Future<void> _loadLevel() async {
    try {
      final provider = context.read<GameProvider>();
      await provider.loadLevelDetails(widget.levelId);

      setState(() {
        words = provider.currentLevel?.words ?? [];
        isLoading = false;
        if (words.isNotEmpty) {
          _selectRandomChallenge();
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load level: $e';
        isLoading = false;
      });
    }
  }

  void _selectRandomChallenge() {
    setState(() {
      currentChallengeType = _challengeTypes[_random.nextInt(_challengeTypes.length)];
      isAnswered = false;
      selectedChoice = null;
      userAnswer = '';
    });
  }

  void _checkAnswer(String answer) {
    final correctWord = words[currentWordIndex].text.toLowerCase();
    final isCorrectAnswer = answer.toLowerCase() == correctWord;

    setState(() {
      isAnswered = true;
      isCorrect = isCorrectAnswer;
      if (isCorrectAnswer) {
        correctCount++;
        _popAnimationController.forward();
        _soundService.playCorrectAnswer();
      } else {
        incorrectCount++;
        _soundService.playIncorrectAnswer();
      }
    });

    _feedbackAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _nextWord();
        }
      });
    });
  }

  void _nextWord() {
    setState(() {
      currentWordIndex++;
      _popAnimationController.reset();
      _feedbackAnimationController.reset();
    });

    if (currentWordIndex < words.length) {
      _selectRandomChallenge();
    } else {
      _showCompletionScreen();
    }
  }

  void _showCompletionScreen() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CompletionDialog(
        correctCount: correctCount,
        totalCount: words.length,
        levelId: widget.levelId,
        onComplete: () {
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Go back to previous screen
        },
      ),
    );
  }

  @override
  void dispose() {
    _popAnimationController.dispose();
    _feedbackAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(child: Text('Error: $errorMessage')),
      );
    }

    if (words.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No words to study')),
      );
    }

    final currentWord = words[currentWordIndex];
    final accuracy = ((correctCount / (correctCount + incorrectCount)) * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Level ${widget.levelId}'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress bar and stats
          Container(
            color: Colors.blue[50],
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Progress indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${currentWordIndex + 1}/${words.length}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (currentWordIndex + 1) / words.length,
                            minHeight: 8,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      '$accuracy%',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Score stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatChip(
                      icon: Icons.check_circle,
                      label: 'Correct',
                      value: correctCount,
                      color: Colors.green,
                    ),
                    _StatChip(
                      icon: Icons.cancel,
                      label: 'Incorrect',
                      value: incorrectCount,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Main content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Word display with TTS button
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Text(
                            'Spell this word:',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            currentWord.text,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FloatingActionButton.extended(
                            onPressed: () {
                              // TODO: Implement TTS
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Playing: ${currentWord.text}')),
                              );
                            },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Hear it'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Challenge based on type
                  if (!isAnswered) ...[
                    if (currentChallengeType == ChallengeType.multipleChoice)
                      _MultipleChoiceChallenge(
                        word: currentWord,
                        onAnswer: _checkAnswer,
                      )
                    else if (currentChallengeType == ChallengeType.typing)
                      _TypingChallenge(
                        word: currentWord,
                        onAnswer: _checkAnswer,
                      )
                    else if (currentChallengeType == ChallengeType.speech)
                      _SpeechChallenge(
                        word: currentWord,
                        onAnswer: _checkAnswer,
                      ),
                  ] else ...[
                    // Feedback
                    FadeTransition(
                      opacity: _feedbackAnimation,
                      child: Column(
                        children: [
                          if (isCorrect) ...[
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Great job!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            ScaleTransition(
                              scale: _popAnimation,
                              child: const Text(
                                '+1 point',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.cancel,
                              color: Colors.red,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Try again!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Correct spelling: ${currentWord.text}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $value'),
    );
  }
}

class _MultipleChoiceChallenge extends StatefulWidget {
  final Word word;
  final Function(String) onAnswer;

  const _MultipleChoiceChallenge({
    required this.word,
    required this.onAnswer,
  });

  @override
  State<_MultipleChoiceChallenge> createState() => _MultipleChoiceChallengeState();
}

class _MultipleChoiceChallengeState extends State<_MultipleChoiceChallenge> {
  late List<String> options;
  String? selectedOption;

  @override
  void initState() {
    super.initState();
    _generateOptions();
  }

  void _generateOptions() {
    final random = Random();
    final correctSpelling = widget.word.text;

    // Common misspellings for learning
    final incorrectOptions = [
      _createMisspelling(correctSpelling, 0),
      _createMisspelling(correctSpelling, 1),
      _createMisspelling(correctSpelling, 2),
    ];

    options = [correctSpelling, ...incorrectOptions]..shuffle(random);
  }

  String _createMisspelling(String word, int type) {
    switch (type) {
      case 0:
        // Swap two characters
        if (word.length > 1) {
          final chars = word.split('')..shuffle();
          return chars.join();
        }
        return word;
      case 1:
        // Remove a character
        if (word.length > 1) {
          return word.substring(0, word.length - 1);
        }
        return word;
      case 2:
        // Add a character
        return word + 'e';
      default:
        return word;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Select the correct spelling:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ...options.map((option) {
          final isSelected = selectedOption == option;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    selectedOption = option;
                  });
                  widget.onAnswer(option);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(option, style: const TextStyle(fontSize: 16)),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _TypingChallenge extends StatefulWidget {
  final Word word;
  final Function(String) onAnswer;

  const _TypingChallenge({
    required this.word,
    required this.onAnswer,
  });

  @override
  State<_TypingChallenge> createState() => _TypingChallengeState();
}

class _TypingChallengeState extends State<_TypingChallenge> {
  late TextEditingController _controller;
  String userInput = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Type the word:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          onChanged: (value) {
            setState(() {
              userInput = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Enter the word here...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: userInput.isNotEmpty
              ? () {
                  widget.onAnswer(userInput);
                }
              : null,
          icon: const Icon(Icons.check),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _SpeechChallenge extends StatelessWidget {
  final Word word;
  final Function(String) onAnswer;

  const _SpeechChallenge({
    required this.word,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Say the word:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 32),
        FloatingActionButton(
          onPressed: () {
            // TODO: Implement speech-to-text
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Listening... (Mock) Expected: ${word.text}')),
            );
            // For now, submit the correct word as a mock
            onAnswer(word.text);
          },
          child: const Icon(Icons.mic),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tap the microphone and say the word clearly',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }
}

class CompletionDialog extends StatefulWidget {
  final int correctCount;
  final int totalCount;
  final int levelId;
  final VoidCallback onComplete;

  const CompletionDialog({
    required this.correctCount,
    required this.totalCount,
    required this.levelId,
    required this.onComplete,
  });

  @override
  State<CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<CompletionDialog> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late SoundService _soundService;
  late bool _confettiVisible;
  late bool _starsAnimating;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    _confettiVisible = true;
    _starsAnimating = false;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _submitCompletion();
    _soundService.playLevelComplete();
  }

  Future<void> _submitCompletion() async {
    try {
      final accuracy = (widget.correctCount / widget.totalCount) * 100;
      final provider = context.read<GameProvider>();
      await provider.completeLevel(widget.levelId, accuracy);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving progress: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = ((widget.correctCount / widget.totalCount) * 100).toStringAsFixed(0);
    final stars = int.parse(accuracy) >= 80 ? 3 : int.parse(accuracy) >= 60 ? 2 : 1;
    final pointsEarned = widget.correctCount * 10;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Stack(
        children: [
          AlertDialog(
            title: const Text('Level Complete!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Star animation rating
                SizedBox(
                  height: 80,
                  child: StarAnimation(
                    starCount: stars,
                    size: 48,
                    delayBetweenStars: const Duration(milliseconds: 250),
                  ),
                ),
                const SizedBox(height: 24),
                // Score
                Text(
                  '${widget.correctCount}/${widget.totalCount}',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$accuracy% Accuracy',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                // Points earned with animation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+$pointsEarned points earned',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: widget.onComplete,
                child: const Text('Continue'),
              ),
            ],
          ),
          // Confetti overlay
          if (_confettiVisible)
            Positioned.fill(
              child: IgnorePointer(
                child: ConfettiAnimation(
                  duration: const Duration(seconds: 3),
                  onComplete: () {
                    if (mounted) {
                      setState(() => _confettiVisible = false);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
