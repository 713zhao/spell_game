import 'package:flutter/material.dart';
import '../widgets/account_avatar_button.dart';
import '../design_system/design_system.dart';
import '../main.dart' show gameProvider;
import '../models/game_models.dart';
import '../utils/reward_calc.dart';

/// Presentation theme (emoji/label/gradient) for whichever kingdom a lesson
/// belongs to, so Lesson Overview isn't hardcoded to the English Castle.
class KingdomTheme {
  final String emoji;
  final String label;
  final List<Color> gradientColors;

  const KingdomTheme({
    required this.emoji,
    required this.label,
    required this.gradientColors,
  });

  static const english = KingdomTheme(
    emoji: '🏰',
    label: 'English Castle',
    gradientColors: DuolingoColors.englishKingdomGradient,
  );

  static const chinese = KingdomTheme(
    emoji: '🐉',
    label: 'Chinese Kingdom',
    gradientColors: DuolingoColors.chineseKingdomGradient,
  );
}

/// Navigation arguments for the '/lesson-overview' route. [lesson] carries
/// the real tag-backed lesson (word count, mastery, tags to scope the
/// deck) fetched from the backend's `/lessons/{user}?subject=` endpoint.
class LessonOverviewArgs {
  final LessonSummary lesson;
  final String subject; // 'EN' | 'CN'
  final KingdomTheme kingdom;

  const LessonOverviewArgs({
    required this.lesson,
    required this.subject,
    this.kingdom = KingdomTheme.english,
  });
}

/// Navigation arguments for the '/study' route.
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

/// Pre-game lesson overview (SpellQuest design):
/// stage number, total words, estimated time, rewards, difficulty,
/// and a big START ADVENTURE button. The word list itself is NOT shown.
class LessonOverviewScreen extends StatefulWidget {
  final LessonOverviewArgs args;

  const LessonOverviewScreen({Key? key, required this.args}) : super(key: key);

  @override
  State<LessonOverviewScreen> createState() => _LessonOverviewScreenState();
}

class _LessonOverviewScreenState extends State<LessonOverviewScreen> {
  @override
  void initState() {
    super.initState();
    gameProvider.addListener(_onChanged);
    gameProvider.loadDeck(
      tags: widget.args.lesson.tags,
      limit: widget.args.lesson.wordCount,
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _showResetRuleInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How mastery works'),
        content: const Text(
          'Each word needs 5 correct answers in a row, and '
          'a mistake resets that word to 0 - that\'s why it can '
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

  @override
  void dispose() {
    gameProvider.removeListener(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.args.lesson;
    final levelName = lesson.displayName;
    final stars = lesson.stars; // mastery earned so far (0-3)

    final wordCount = lesson.wordCount;
    final newWords = gameProvider.deckCards
        .where((c) => c.repetitions == 0)
        .length;
    // Learn cards ~8s, exercises ~20s each
    final estMinutes = ((newWords * 8 + wordCount * 20) / 60).ceil().clamp(
      1,
      30,
    );
    final rewards = computeLessonRewards(wordCount);

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Scrollable content: on short screens (small phones) this
              // card stack can exceed the available height, so it scrolls
              // independently while the Start Adventure button below stays
              // pinned and reachable without depending on a Spacer to push
              // it to the bottom of a fixed-height column.
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stage header card
                      Container(
                        padding: EdgeInsets.all(DuolingoSpacing.xxl),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: widget.args.kingdom.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(
                            DuolingoSpacing.radiusCard,
                          ),
                          border: Border.all(
                            color: DuolingoColors.informationBlue,
                            width: 2,
                          ),
                          boxShadow: DuolingoShadows.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Text(
                              widget.args.kingdom.emoji,
                              style: const TextStyle(fontSize: 64),
                            ),
                            SizedBox(height: DuolingoSpacing.md),
                            Text(
                              widget.args.kingdom.label.toUpperCase(),
                              style: DuolingoTextStyles.label.copyWith(
                                color: DuolingoColors.bodyText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: DuolingoSpacing.xs),
                            Text(
                              levelName,
                              textAlign: TextAlign.center,
                              style: DuolingoTextStyles.pageTitle.copyWith(
                                color: DuolingoColors.darkText,
                              ),
                            ),
                            SizedBox(height: DuolingoSpacing.md),
                            // Mastery stars earned so far
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (i) => Text(
                                  i < stars ? '⭐' : '☆',
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

                      // Mastery
                      Container(
                        padding: EdgeInsets.all(DuolingoSpacing.lg),
                        decoration: BoxDecoration(
                          color: DuolingoColors.neutralGray,
                          borderRadius: BorderRadius.circular(
                            DuolingoSpacing.radiusCard,
                          ),
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
                                  child: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
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
                                  DuolingoColors.primaryGreen,
                                ),
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

                      // Rewards
                      Container(
                        padding: EdgeInsets.all(DuolingoSpacing.lg),
                        decoration: BoxDecoration(
                          color: DuolingoColors.neutralGray,
                          borderRadius: BorderRadius.circular(
                            DuolingoSpacing.radiusCard,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'REWARDS',
                              style: DuolingoTextStyles.label.copyWith(
                                color: DuolingoColors.bodyText,
                              ),
                            ),
                            SizedBox(height: DuolingoSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _RewardChip(
                                  emoji: '⚡',
                                  label: 'up to ${rewards.xp} XP',
                                ),
                                _RewardChip(
                                  emoji: '💰',
                                  label: '${rewards.coins} Coins',
                                ),
                                const _RewardChip(emoji: '🎁', label: 'Chest'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),

              // Start Adventure
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/study',
                    arguments: StudySessionArgs(
                      tags: lesson.tags,
                      lessonKey: lesson.lessonKey,
                      displayName: lesson.displayName,
                      subject: widget.args.subject,
                      skills: lesson.skills,
                    ),
                  );
                },
                child: Container(
                  height: DuolingoSpacing.largeButton,
                  decoration: BoxDecoration(
                    color: DuolingoColors.primaryGreen,
                    borderRadius: BorderRadius.circular(
                      DuolingoSpacing.radiusButton,
                    ),
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
          Text(
            value,
            style: DuolingoTextStyles.cardTitle.copyWith(
              color: DuolingoColors.darkText,
            ),
          ),
          Text(
            label,
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.bodyText,
            ),
          ),
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
        Text(
          label,
          style: DuolingoTextStyles.label.copyWith(
            color: DuolingoColors.darkText,
          ),
        ),
      ],
    );
  }
}
