import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../main.dart' show gameProvider;

/// Pre-game lesson overview (SpellQuest design):
/// stage number, total words, estimated time, rewards, difficulty,
/// and a big START ADVENTURE button. The word list itself is NOT shown.
class LessonOverviewScreen extends StatefulWidget {
  final int levelId;

  const LessonOverviewScreen({Key? key, required this.levelId})
      : super(key: key);

  @override
  State<LessonOverviewScreen> createState() => _LessonOverviewScreenState();
}

class _LessonOverviewScreenState extends State<LessonOverviewScreen> {
  @override
  void initState() {
    super.initState();
    gameProvider.addListener(_onChanged);
    if (gameProvider.deckCards.isEmpty) {
      gameProvider.loadDeck();
    }
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final levels = gameProvider.levels;
    final level = levels.where((l) => l.id == widget.levelId).isNotEmpty
        ? levels.firstWhere((l) => l.id == widget.levelId)
        : null;
    final levelName = level?.name ?? 'Stage ${widget.levelId}';
    final difficulty = level?.difficulty ?? widget.levelId;

    final wordCount = gameProvider.deckCards.isEmpty
        ? 10
        : gameProvider.deckCards.length;
    final newWords =
        gameProvider.deckCards.where((c) => c.repetitions == 0).length;
    // Learn cards ~8s, exercises ~20s each
    final estMinutes =
        ((newWords * 8 + wordCount * 20) / 60).ceil().clamp(1, 30);
    final maxXp = wordCount * 10;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stage header card
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.xxl),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: DuolingoColors.englishKingdomGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                  border: Border.all(
                      color: DuolingoColors.informationBlue, width: 2),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Column(
                  children: [
                    const Text('🏰', style: TextStyle(fontSize: 64)),
                    SizedBox(height: DuolingoSpacing.md),
                    Text(
                      'Stage ${widget.levelId}',
                      style: DuolingoTextStyles.label
                          .copyWith(color: DuolingoColors.bodyText),
                    ),
                    SizedBox(height: DuolingoSpacing.xs),
                    Text(
                      levelName,
                      textAlign: TextAlign.center,
                      style: DuolingoTextStyles.pageTitle
                          .copyWith(color: DuolingoColors.darkText),
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    // Difficulty stars
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Text(
                          i < difficulty ? '⭐' : '☆',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),

              // Info row: words + time
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      emoji: '📚',
                      value: '$wordCount',
                      label: 'WORDS',
                    ),
                  ),
                  SizedBox(width: DuolingoSpacing.md),
                  Expanded(
                    child: _InfoTile(
                      emoji: '⏱️',
                      value: '~$estMinutes min',
                      label: 'TIME',
                    ),
                  ),
                ],
              ),
              SizedBox(height: DuolingoSpacing.xl),

              // Rewards
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
                    Text('REWARDS',
                        style: DuolingoTextStyles.label
                            .copyWith(color: DuolingoColors.bodyText)),
                    SizedBox(height: DuolingoSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _RewardChip(emoji: '⚡', label: 'up to $maxXp XP'),
                        const _RewardChip(emoji: '💰', label: 'Coins'),
                        const _RewardChip(emoji: '🎁', label: 'Chest'),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Start Adventure
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/study',
                    arguments: widget.levelId,
                  );
                },
                child: Container(
                  height: DuolingoSpacing.largeButton,
                  decoration: BoxDecoration(
                    color: DuolingoColors.primaryGreen,
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF58A700),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'START ADVENTURE  🚀',
                    style: DuolingoTextStyles.cardTitle.copyWith(
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;

  const _InfoTile({
    required this.emoji,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      decoration: BoxDecoration(
        color: DuolingoColors.backgroundWhite,
        border: Border.all(color: const Color(0xFFE5E5E5), width: 2),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          SizedBox(height: DuolingoSpacing.xs),
          Text(value,
              style: DuolingoTextStyles.cardTitle
                  .copyWith(color: DuolingoColors.darkText)),
          Text(label,
              style: DuolingoTextStyles.label
                  .copyWith(color: DuolingoColors.bodyText)),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String emoji;
  final String label;

  const _RewardChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        SizedBox(height: DuolingoSpacing.xs),
        Text(label,
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.darkText)),
      ],
    );
  }
}
