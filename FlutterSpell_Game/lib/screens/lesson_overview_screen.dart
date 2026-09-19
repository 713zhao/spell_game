import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/account_avatar_button.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../models/game_models.dart';
import '../models/stage_data.dart' show reviewNodeIndex;
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
  // Which node of the lesson was tapped on the journey path: a checkpoint
  // index, [reviewNodeIndex] for the review node, or null for the lesson as
  // a whole (the lesson's current checkpoint, or everything once completed).
  final int? checkpoint;

  const LessonOverviewArgs({
    required this.lesson,
    required this.subject,
    this.kingdom = KingdomTheme.english,
    this.checkpoint,
  });
}

/// Navigation arguments for the '/study' route.
class StudySessionArgs {
  final List<String> tags;
  final String lessonKey;
  final String displayName;
  final String subject;
  final List<String> skills;
  final int? checkpoint;
  // A lesson review session (see the backend's /deck?mode=review): the whole
  // lesson weakest-first plus due words from earlier lessons.
  final bool review;

  const StudySessionArgs({
    required this.tags,
    required this.lessonKey,
    required this.displayName,
    required this.subject,
    this.skills = const [],
    this.checkpoint,
    this.review = false,
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
  bool _showWordDetail = false;
  late GameProvider gameProvider;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    gameProvider.addListener(_onChanged);
    // Deferred to after the first frame: loadDeck's own synchronous prelude
    // (clearing deckCards, scheduling its "cleared" notifyListeners) can
    // otherwise land inside this widget's own first build here, which
    // Provider disallows ("setState()/markNeedsBuild() called during
    // build") since this screen reads GameProvider via context now instead
    // of the old bare global singleton import.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.loadDeck(
        tags: widget.args.lesson.tags,
        limit: widget.args.lesson.wordCount,
      );
    });
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
          'A point is done when you get each of its words right in a '
          'session. Stars come from remembering words over several days: '
          'a word needs 3 correct answers on different days, and a '
          'mistake sends that word back to the start.',
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

  // Chip background per mastery tier. Text color is always
  // DuolingoColors.darkText (#333333) rather than white - computed WCAG
  // contrast ratios (see docstring on _MasteryChip) showed white text fails
  // the ~4.5:1 floor for small text on every one of these backgrounds,
  // including primaryGreen, so darkText is used uniformly instead of
  // assuming white works on the "dark-looking" green tier.
  Color _masteryChipColor(int repetitions) {
    if (repetitions >= 3) return DuolingoColors.primaryGreen;
    if (repetitions >= 1) return DuolingoColors.rewardYellow;
    return DuolingoColors.secondaryButtonGray;
  }

  /// The node this screen is about: a checkpoint index, [reviewNodeIndex],
  /// or null for the whole lesson (a completed lesson's free practice).
  int? get _point {
    final lesson = widget.args.lesson;
    return widget.args.checkpoint ??
        (lesson.status == 'completed' ? null : lesson.checkpointIndex);
  }

  /// Ids of the words in the selected checkpoint, or null when the session
  /// isn't scoped to one (review / whole lesson / no checkpoint data).
  Set<int>? get _pointWordIds {
    final point = _point;
    final checkpoints = widget.args.lesson.checkpoints;
    if (point == null || point < 0 || point >= checkpoints.length) return null;
    return checkpoints[point].wordIds.toSet();
  }

  static const int _reviewSessionSize = 15;

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

    final lesson = widget.args.lesson;
    final cardById = {for (final c in gameProvider.deckCards) c.word.id: c};
    // Checkpoints come from the server so this grid always matches the
    // sessions the path actually launches.
    final chunks = <List<DeckCard>>[
      for (final cp in lesson.checkpoints)
        [
          for (final id in cp.wordIds)
            if (cardById[id] != null) cardById[id]!,
        ],
    ];
    if (chunks.isEmpty) {
      chunks.add(
        List<DeckCard>.from(gameProvider.deckCards)
          ..sort((a, b) => a.word.id.compareTo(b.word.id)),
      );
    }
    final currentCheckpoint = lesson.checkpointIndex;

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
                      final locked =
                          i > currentCheckpoint &&
                          !(i < lesson.checkpoints.length &&
                              lesson.checkpoints[i].passed);
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
    // Start Adventure launches a session scoped to the selected point (a
    // checkpoint or the review node), or the whole lesson for a completed
    // one's free practice. The WORDS/TIME/REWARDS tiles should describe that
    // session, not the whole lesson, or they'd overstate what tapping the
    // button actually gives you.
    final point = _point;
    final isReview = point == reviewNodeIndex;
    final pointWordIds = _pointWordIds;
    final sessionWordCount = isReview
        ? min(wordCount, _reviewSessionSize)
        : pointWordIds?.length ?? wordCount;
    // newWords must be scoped the same way: counting zero-repetition cards
    // across the whole deck (rather than just the selected point's words)
    // would inflate the TIME estimate with words that aren't even part of
    // the session Start Adventure is about to launch.
    final newWords = isReview
        ? 0
        : gameProvider.deckCards
              .where(
                (c) =>
                    c.repetitions == 0 &&
                    (pointWordIds == null || pointWordIds.contains(c.word.id)),
              )
              .length;
    // Learn cards ~8s, exercises ~20s each
    final estMinutes = ((newWords * 8 + sessionWordCount * 20) / 60)
        .ceil()
        .clamp(1, 30);
    final rewards = computeLessonRewards(sessionWordCount);

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
                            if (point != null &&
                                lesson.checkpointCount > 0) ...[
                              SizedBox(height: DuolingoSpacing.xs),
                              Text(
                                isReview
                                    ? 'Review'
                                    : 'Point ${point + 1} of ${lesson.checkpointCount}',
                                style: DuolingoTextStyles.label.copyWith(
                                  color: DuolingoColors.bodyText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                              value: '$sessionWordCount',
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
                              'Finish every point and the review to unlock the next lesson',
                              style: DuolingoTextStyles.label.copyWith(
                                color: DuolingoColors.bodyText,
                                fontSize: 11,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(
                                () => _showWordDetail = !_showWordDetail,
                              ),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: DuolingoSpacing.xs,
                                ),
                                child: Text(
                                  _showWordDetail
                                      ? 'Hide word-by-word progress ▴'
                                      : 'Show word-by-word progress ▾',
                                  style: DuolingoTextStyles.label.copyWith(
                                    color: DuolingoColors.informationBlue,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            if (_showWordDetail) _buildWordDetailGrid(),
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
                      // null means "no checkpoint scoping, serve from the
                      // whole lesson pool" (a completed lesson's free
                      // practice) to getDeckCards / loadDeck / the
                      // backend's /deck route. A review node is scoped by
                      // `review` instead.
                      checkpoint: point != null && point >= 0 ? point : null,
                      review: isReview,
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

/// One word chip in the per-word mastery grid, colored by mastery tier.
///
/// Text is always [DuolingoColors.darkText] (#333333), never white, on
/// every tier's background. Computed WCAG 2.x contrast ratios (relative
/// luminance formula from the W3C spec) for darkText vs. each tier's
/// background:
///   - green  (primaryGreen      #58CC02): ~6.05:1
///   - yellow (rewardYellow      #FFD700): ~9.01:1
///   - grey   (secondaryButtonGray #CCCCCC): ~7.87:1
/// All three clear the ~4.5:1 AA floor for small text (grey and yellow
/// clear the 7:1 AAA floor too). White text was checked against every one
/// of these backgrounds and rejected because it fails on all three,
/// including the green tier: white-on-primaryGreen is only ~2.09:1,
/// white-on-rewardYellow ~1.40:1, white-on-secondaryButtonGray ~1.61:1 (and
/// white-on-streakOrange, the other candidate yellow token, was ~1.98:1 -
/// also rejected, and rewardYellow gives a better ratio with darkText
/// besides).
class _MasteryChip extends StatelessWidget {
  final String text;
  final Color color;

  const _MasteryChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(color: DuolingoColors.darkText, fontSize: 11),
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
