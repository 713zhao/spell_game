import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/celebration.dart';

/// A vertical, zig-zagging Duolingo-style map of checkpoint nodes connected
/// by a dashed trail, with a milestone treasure chest every 5 nodes. The
/// current lesson is expanded into its checkpoints plus a review node; other
/// lessons are a single node each (see [buildPathItems]). Shared by every kingdom's lesson-selection screen so node styling,
/// star ratings, and the lock dialog stay consistent across kingdoms.
class JourneyPath extends StatefulWidget {
  final List<StageData> stages;
  final String kingdomEmoji;
  final String kingdomLabel;
  final List<Color> gradientColors;
  final bool allowSkipLock;
  // Called with the tapped node's lesson and checkpoint index: >= 0 for a
  // checkpoint, [reviewNodeIndex] for the review node, null for a
  // lesson shown as a single node.
  final void Function(int stageNumber, int? checkpointIndex) onSelectNode;
  // Called when the user confirms "UNLOCK ANYWAY" on a locked node, before
  // onSelectNode opens it - the caller should persist this (and rebuild
  // `stages` with it in StageData.unlockedNodes) so the node doesn't come
  // back locked and re-prompt the next time this screen loads, since the
  // backend's progress doesn't change from skipping ahead. For a lesson
  // shown as a single node the index is 0 (its first checkpoint).
  final void Function(int stageNumber, int checkpointIndex)? onUnlockConfirmed;
  // Stage number to scroll into view and mark with a "look here" indicator
  // on first build (e.g. the user's default/last-opened lesson), so they
  // can pick up where they left off without hunting through the path -
  // still requires a tap to actually open it. Null shows no highlight.
  final int? highlightStageNumber;
  // Milestone chest indices (MilestoneItem.index) already opened, so a
  // chest only ever pays out its reward once instead of replaying the
  // celebration - and its XP/coin pop - on every tap.
  final Set<int> claimedMilestones;
  // Called when the user opens a chest that wasn't already claimed - the
  // caller should persist it into [claimedMilestones] (see
  // treasure_claims.dart) so it stays claimed across rebuilds.
  final void Function(int index)? onMilestoneClaimed;

  const JourneyPath({
    super.key,
    required this.stages,
    required this.kingdomEmoji,
    required this.kingdomLabel,
    required this.gradientColors,
    required this.allowSkipLock,
    required this.onSelectNode,
    this.onUnlockConfirmed,
    this.highlightStageNumber,
    this.claimedMilestones = const {},
    this.onMilestoneClaimed,
  });

  @override
  State<JourneyPath> createState() => _JourneyPathState();
}

class _JourneyPathState extends State<JourneyPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  // One GlobalKey per stage's label-anchor node, so a highlighted stage's
  // rendered position can be found for Scrollable.ensureVisible after the
  // path lays out - the path itself has no ScrollController of its own,
  // it just scrolls within whichever ancestor Scrollable the caller wraps
  // it in (a plain SingleChildScrollView on every current call site).
  final Map<int, GlobalKey> _stageAnchorKeys = {};
  bool _scrolledToHighlight = false;

  static const double _nodeSize = DuolingoSpacing.nodeSize; // 56
  static const double _milestoneSize = DuolingoSpacing.nodeSize + 26; // 82
  static const double _rowSpacing = 122;
  static const double _topPadding = 124;
  static const List<double> _xFractions = [0.5, 0.8, 0.5, 0.2];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    if (widget.highlightStageNumber != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
    }
  }

  @override
  void didUpdateWidget(covariant JourneyPath oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The highlight target is often only known after an async lookup (e.g.
    // a confirm dialog) that resolves after this widget's first build, so
    // it can arrive as a prop change rather than being present up front.
    if (widget.highlightStageNumber != null &&
        widget.highlightStageNumber != oldWidget.highlightStageNumber) {
      _scrolledToHighlight = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight());
    }
  }

  void _scrollToHighlight() {
    if (_scrolledToHighlight || !mounted) return;
    final stageNumber = widget.highlightStageNumber;
    if (stageNumber == null) return;
    final ctx = _stageAnchorKeys[stageNumber]?.currentContext;
    if (ctx == null) return;
    _scrolledToHighlight = true;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.3,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleNodeTap(LessonItem item) {
    final stage = widget.stages[item.stageIndex];
    if (item.state != NodeState.locked) {
      widget.onSelectNode(
        stage.stageNumber,
        item.isCollapsed ? null : item.checkpointIndex,
      );
      return;
    }
    _showUnlockDialog(item);
  }

  Future<void> _showUnlockDialog(LessonItem item) async {
    final stage = widget.stages[item.stageIndex];
    final String title;
    final String build;
    final String recommend;
    if (item.isCollapsed) {
      title = '🔒 This lesson is locked';
      build = 'This lesson is designed to build on previous skills.';
      recommend =
          'Stage ${(stage.stageNumber - 1).clamp(1, widget.stages.length)}';
    } else if (item.isReview) {
      title = '🔒 Review is locked';
      build = 'The review covers the whole lesson.';
      recommend = 'all the points in this lesson';
    } else {
      title = '🔒 This point is locked';
      build = 'Each point builds on the one before it.';
      var firstUnpassed = 0;
      while (firstUnpassed < stage.checkpointCount &&
          stage.isCheckpointPassed(firstUnpassed)) {
        firstUnpassed++;
      }
      recommend = 'point ${firstUnpassed + 1}';
    }

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(
          widget.allowSkipLock ? 'CANCEL' : 'OK',
          style: DuolingoTextStyles.label.copyWith(
            color: DuolingoColors.bodyText,
          ),
        ),
      ),
    ];
    if (widget.allowSkipLock) {
      actions.add(
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'UNLOCK ANYWAY',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.informationBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    final unlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
        ),
        title: Text(title),
        content: Text(
          widget.allowSkipLock
              ? '$build\n\n'
                    'You can unlock it now, but we recommend completing '
                    '$recommend first.'
              : '$build\n\nComplete $recommend first to unlock it.',
          style: DuolingoTextStyles.body,
        ),
        actions: actions,
      ),
    );
    if (unlock == true && mounted) {
      widget.onUnlockConfirmed?.call(stage.stageNumber, item.checkpointIndex);
      widget.onSelectNode(
        stage.stageNumber,
        item.isCollapsed ? 0 : item.checkpointIndex,
      );
    }
  }

  void _handleMilestoneTap(MilestoneItem item) {
    if (!item.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete more lessons to unlock this treasure!'),
        ),
      );
      return;
    }
    if (widget.claimedMilestones.contains(item.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already claimed this treasure!')),
      );
      return;
    }
    Celebration.reward(context);
    Celebration.xpPop(context, 50);
    widget.onMilestoneClaimed?.call(item.index);
  }

  @override
  Widget build(BuildContext context) {
    final items = buildPathItems(widget.stages);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final centers = <Offset>[];
            for (var i = 0; i < items.length; i++) {
              final xf = _xFractions[i % _xFractions.length];
              final y = _topPadding + _rowSpacing * i;
              centers.add(Offset(xf * width, y));
            }
            final totalHeight =
                _topPadding + _rowSpacing * (items.length - 1) + 90;

            return Container(
              width: width,
              height: totalHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    widget.gradientColors[0].withOpacity(0.35),
                    DuolingoColors.backgroundWhite,
                  ],
                ),
                borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          widget.kingdomEmoji,
                          style: const TextStyle(fontSize: 30),
                        ),
                        Text(
                          widget.kingdomLabel,
                          style: DuolingoTextStyles.label.copyWith(
                            color: DuolingoColors.bodyText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: Size(width, totalHeight),
                    painter: _TrailPainter(centers: centers),
                  ),
                  for (var i = 0; i < items.length; i++)
                    ..._buildItemWidgets(items[i], centers[i], width),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildItemWidgets(PathItem item, Offset center, double width) {
    if (item is MilestoneItem) {
      final claimed = widget.claimedMilestones.contains(item.index);
      return [
        Positioned(
          left: center.dx - _milestoneSize / 2,
          top: center.dy - _milestoneSize / 2,
          child: _MilestoneNode(
            size: _milestoneSize,
            unlocked: item.unlocked,
            claimed: claimed,
            onTap: () => _handleMilestoneTap(item),
          ),
        ),
        Positioned(
          top: center.dy + _milestoneSize / 2 + 4,
          left: (center.dx - 80).clamp(0, width - 160),
          width: 160,
          child: Text(
            claimed
                ? 'Treasure claimed'
                : item.unlocked
                ? 'Treasure unlocked!'
                : 'Treasure Chest',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.label.copyWith(
              color: item.unlocked
                  ? DuolingoColors.treasureGold
                  : DuolingoColors.bodyText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    }

    final lessonItem = item as LessonItem;
    final stage = widget.stages[lessonItem.stageIndex];
    final state = lessonItem.state;

    // _LessonNode's outer footprint is always _nodeSize + footprintPadding
    // (matches the fixed bounding box every node reports, regardless of
    // state) so Positioned offsets computed here stay centered on `center`.
    const outerSize = _nodeSize + _LessonNode.footprintPadding;

    final isHighlighted =
        lessonItem.isPointerAnchor &&
        stage.stageNumber == widget.highlightStageNumber;

    final labelWidgets = <Widget>[];
    if (isHighlighted) {
      labelWidgets.add(
        Positioned(
          top: center.dy - _nodeSize / 2 - 54,
          left: (center.dx - 20).clamp(0, width - 40),
          width: 40,
          child: _HighlightArrow(pulse: _pulseController),
        ),
      );
    }
    if (lessonItem.isLabelAnchor) {
      // The label (title/date/stars) reflects the LESSON's overall state,
      // not the state of the single checkpoint node it happens to be
      // anchored to - those can differ (e.g. an in-progress lesson's label
      // anchor may land on a not-yet-reached checkpoint).
      final lessonLocked = stage.isLocked;
      final lessonCurrent = stage.isCurrent;

      if (stage.stars > 0) {
        labelWidgets.add(
          Positioned(
            top: center.dy - _nodeSize / 2 - 22,
            left: (center.dx - 40).clamp(0, width - 80),
            width: 80,
            child: _StarRow(stars: stage.stars, dimmed: lessonLocked),
          ),
        );
      }
      // A lesson still being practiced past completion gets its own
      // "Session N" label below instead of the plain title/date.
      if (!lessonItem.isPracticeNode) {
        labelWidgets.add(
          Positioned(
            top: center.dy + _nodeSize / 2 + 6,
            left: (center.dx - 70).clamp(0, width - 140),
            width: 140,
            child: Column(
              children: [
                Text(
                  stage.title,
                  textAlign: TextAlign.center,
                  style: DuolingoTextStyles.label.copyWith(
                    color: lessonLocked
                        ? DuolingoColors.bodyText.withOpacity(0.5)
                        : DuolingoColors.darkText,
                    fontWeight: lessonCurrent
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                ),
                if ((stage.spellDate ?? '').isNotEmpty ||
                    stage.labelBadge != null)
                  Text(
                    [
                      if (stage.labelBadge != null) stage.labelBadge!,
                      if ((stage.spellDate ?? '').isNotEmpty)
                        stage.spellDate!,
                    ].join(' '),
                    textAlign: TextAlign.center,
                    style: DuolingoTextStyles.label.copyWith(
                      fontSize: 11,
                      color: DuolingoColors.bodyText.withOpacity(
                        lessonLocked ? 0.4 : 0.8,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    if (lessonItem.isReview) {
      labelWidgets.add(
        Positioned(
          top: center.dy + _nodeSize / 2 + 6,
          left: (center.dx - 70).clamp(0, width - 140),
          width: 140,
          child: Text(
            stage.reviewDueCount > 0
                ? 'Review · ${stage.reviewDueCount} due'
                : 'Review',
            textAlign: TextAlign.center,
            style: DuolingoTextStyles.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: state == NodeState.locked
                  ? DuolingoColors.bodyText.withOpacity(0.5)
                  : DuolingoColors.informationBlue,
            ),
          ),
        ),
      );
    }

    if (lessonItem.isPracticeNode && lessonItem.isLabelAnchor) {
      labelWidgets.add(
        Positioned(
          top: center.dy + _nodeSize / 2 + 6,
          left: (center.dx - 70).clamp(0, width - 140),
          width: 140,
          child: Column(
            children: [
              Text(
                '${stage.title} Session ${lessonItem.practiceSessionNumber}',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: DuolingoColors.informationBlue,
                ),
              ),
              Text(
                '${(stage.progress * 100).round()}% mastery',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 11,
                  color: DuolingoColors.bodyText.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget node = _LessonNode(
      state: state,
      isReview: lessonItem.isReview,
      isPractice: lessonItem.isPracticeNode,
      pulse: _pulseController,
      onTap: () => _handleNodeTap(lessonItem),
    );
    if (lessonItem.isLabelAnchor) {
      node = KeyedSubtree(
        key: _stageAnchorKeys.putIfAbsent(stage.stageNumber, () => GlobalKey()),
        child: node,
      );
    }

    return [
      Positioned(
        left: center.dx - outerSize / 2,
        top: center.dy - outerSize / 2,
        child: node,
      ),
      ...labelWidgets,
    ];
  }
}

class _HighlightArrow extends StatelessWidget {
  final Animation<double> pulse;

  const _HighlightArrow({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, pulse.value * 8), child: child),
      child: const Text('👇', style: TextStyle(fontSize: 26)),
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  final bool dimmed;

  const _StarRow({required this.stars, required this.dimmed});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        3,
        (i) => Text(
          i < stars ? '⭐' : '☆',
          style: TextStyle(
            fontSize: DuolingoSpacing.starSize,
            color: dimmed ? Colors.grey : null,
          ),
        ),
      ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  // Extra footprint padding around the node's visible circle, kept
  // state-invariant so `Positioned` offsets computed by the caller stay
  // centered on `center` for every state. Single source of truth shared
  // with `_JourneyPathState._buildItemWidgets`'s `outerSize` calculation.
  static const double footprintPadding = 10;

  final NodeState state;
  final bool isReview;
  final bool isPractice;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _LessonNode({
    required this.state,
    this.isReview = false,
    this.isPractice = false,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = DuolingoSpacing.nodeSize;

    Color fill;
    Color border;
    Widget icon;

    switch (state) {
      case NodeState.completed:
        fill = DuolingoColors.primaryGreen;
        border = const Color(0xFF58A700);
        icon = const Icon(Icons.check, color: Colors.white, size: 28);
        break;
      case NodeState.current:
        fill = DuolingoColors.streakOrange;
        border = const Color(0xFFCC7A00);
        icon = isPractice
            ? const Icon(Icons.fitness_center, color: Colors.white, size: 28)
            : isReview
            ? const Icon(Icons.replay, color: Colors.white, size: 28)
            : const Text('🔥', style: TextStyle(fontSize: 26));
        break;
      case NodeState.available:
        fill = DuolingoColors.informationBlue;
        border = const Color(0xFF1876BF);
        icon = Icon(
          isPractice
              ? Icons.fitness_center
              : isReview
              ? Icons.replay
              : Icons.play_arrow,
          color: Colors.white,
          size: 28,
        );
        break;
      case NodeState.locked:
        fill = DuolingoColors.secondaryButtonGray;
        border = const Color(0xFFAAAAAA);
        icon = Icon(Icons.lock, color: Colors.grey[600], size: 24);
        break;
    }

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

    // Keep the node's outer footprint state-invariant (matching the old
    // ring-reserving box) so `Positioned` offsets computed by the caller
    // stay centered on `center` for every state.
    node = SizedBox(
      width: size + footprintPadding,
      height: size + footprintPadding,
      child: Center(child: node),
    );

    if (state == NodeState.current) {
      node = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final glow = 6 + pulse.value * DuolingoSpacing.glowRadius;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DuolingoColors.streakOrange.withOpacity(
                    0.5 - pulse.value * 0.25,
                  ),
                  blurRadius: glow,
                  spreadRadius: pulse.value * 4,
                ),
              ],
            ),
            child: child,
          );
        },
        child: node,
      );
    }

    return GestureDetector(onTap: onTap, child: node);
  }
}

class _MilestoneNode extends StatelessWidget {
  final double size;
  final bool unlocked;
  final bool claimed;
  final VoidCallback onTap;

  const _MilestoneNode({
    required this.size,
    required this.unlocked,
    required this.claimed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A claimed chest keeps its gold ring (it was earned) but drops the
    // glossy gradient/shadow so it reads as already-opened, not a reward
    // still waiting to be tapped.
    final active = unlocked && !claimed;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active
              ? const LinearGradient(
                  colors: [
                    DuolingoColors.treasureGold,
                    DuolingoColors.rewardYellow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active
              ? null
              : unlocked
              ? DuolingoColors.treasureGold.withOpacity(0.35)
              : DuolingoColors.neutralGray,
          border: Border.all(
            color: unlocked ? const Color(0xFFB8860B) : const Color(0xFFAAAAAA),
            width: 3,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0xFFB8860B),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          claimed ? '📦' : unlocked ? '🎁' : '🔒',
          style: TextStyle(fontSize: size * 0.42),
        ),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  final List<Offset> centers;

  _TrailPainter({required this.centers});

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < centers.length - 1; i++) {
      _drawDashedLine(canvas, centers[i], centers[i + 1], paint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dashLength = 10.0;
    const gapLength = 8.0;
    final total = (b - a).distance;
    final direction = (b - a) / total;
    double drawn = 0;
    while (drawn < total) {
      final segStart = a + direction * drawn;
      final segEnd = a + direction * (drawn + dashLength).clamp(0, total);
      canvas.drawLine(segStart, segEnd, paint);
      drawn += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.centers != centers;
}
