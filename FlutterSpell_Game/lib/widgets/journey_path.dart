import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/celebration.dart';

/// A vertical, zig-zagging Duolingo-style map of lesson nodes connected by a
/// dashed trail, with a milestone treasure chest every 5 lessons. Shared by
/// every kingdom's lesson-selection screen so node styling, star ratings,
/// and the lock dialog stay consistent across kingdoms.
class JourneyPath extends StatefulWidget {
  final List<StageData> stages;
  final String kingdomEmoji;
  final String kingdomLabel;
  final List<Color> gradientColors;
  final bool allowSkipLock;
  final void Function(int stageNumber) onSelectLesson;

  const JourneyPath({
    super.key,
    required this.stages,
    required this.kingdomEmoji,
    required this.kingdomLabel,
    required this.gradientColors,
    required this.allowSkipLock,
    required this.onSelectLesson,
  });

  @override
  State<JourneyPath> createState() => _JourneyPathState();
}

class _JourneyPathState extends State<JourneyPath>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  static const double _nodeSize = DuolingoSpacing.nodeSize; // 56
  static const double _milestoneSize = DuolingoSpacing.nodeSize + 26; // 82
  static const double _rowSpacing = 122;
  static const double _topPadding = 70;
  static const List<double> _xFractions = [0.5, 0.8, 0.5, 0.2];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleNodeTap(int index) {
    final state = deriveNodeState(widget.stages, index);
    if (state == NodeState.locked) {
      _showUnlockDialog(index);
    } else {
      widget.onSelectLesson(widget.stages[index].stageNumber);
    }
  }

  Future<void> _showUnlockDialog(int index) async {
    final recommended =
        (widget.stages[index].stageNumber - 1).clamp(1, widget.stages.length);

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: Text(
          widget.allowSkipLock ? 'CANCEL' : 'OK',
          style:
              DuolingoTextStyles.label.copyWith(color: DuolingoColors.bodyText),
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
        title: const Text('🔒 This lesson is locked'),
        content: Text(
          widget.allowSkipLock
              ? 'This lesson is designed to build on previous skills.\n\n'
                  'You can unlock it now, but we recommend completing '
                  'Stage $recommended first.'
              : 'This lesson is designed to build on previous skills.\n\n'
                  'Complete Stage $recommended first to unlock it.',
          style: DuolingoTextStyles.body,
        ),
        actions: actions,
      ),
    );
    if (unlock == true && mounted) {
      setState(() => widget.stages[index].isLocked = false);
      widget.onSelectLesson(widget.stages[index].stageNumber);
    }
  }

  void _handleMilestoneTap(bool unlocked) {
    if (unlocked) {
      Celebration.reward(context);
      Celebration.xpPop(context, 50);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete more lessons to unlock this treasure!'),
        ),
      );
    }
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
                        Text(widget.kingdomEmoji,
                            style: const TextStyle(fontSize: 30)),
                        Text(
                          widget.kingdomLabel,
                          style: DuolingoTextStyles.label
                              .copyWith(color: DuolingoColors.bodyText),
                        ),
                      ],
                    ),
                  ),
                  CustomPaint(
                    size: Size(width, totalHeight),
                    painter: _TrailPainter(centers: centers),
                  ),
                  for (var i = 0; i < items.length; i++)
                    ..._buildItemWidgets(items[i], i, centers[i], width),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildItemWidgets(
    PathItem item,
    int i,
    Offset center,
    double width,
  ) {
    if (item is MilestoneItem) {
      return [
        Positioned(
          left: center.dx - _milestoneSize / 2,
          top: center.dy - _milestoneSize / 2,
          child: _MilestoneNode(
            size: _milestoneSize,
            unlocked: item.unlocked,
            onTap: () => _handleMilestoneTap(item.unlocked),
          ),
        ),
        Positioned(
          top: center.dy + _milestoneSize / 2 + 4,
          left: (center.dx - 80).clamp(0, width - 160),
          width: 160,
          child: Text(
            item.unlocked ? 'Treasure unlocked!' : 'Treasure Chest',
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

    final index = (item as LessonItem).index;
    final stage = widget.stages[index];
    final state = deriveNodeState(widget.stages, index);

    // _LessonNode's outer footprint is always _nodeSize + 10 (it reserves
    // room for the progress ring on every non-locked node so the ring
    // doesn't grow the widget's bounding box relative to the locked case).
    // Center the enlarged footprint on `center` so the node — ring or no
    // ring — stays visually aligned with the trail, star row, and label.
    const outerSize = _nodeSize + 10;

    return [
      Positioned(
        left: center.dx - outerSize / 2,
        top: center.dy - outerSize / 2,
        child: _LessonNode(
          state: state,
          progress: stage.progress,
          pulse: _pulseController,
          onTap: () => _handleNodeTap(index),
        ),
      ),
      if (stage.stars > 0)
        Positioned(
          top: center.dy - _nodeSize / 2 - 22,
          left: (center.dx - 40).clamp(0, width - 80),
          width: 80,
          child: _StarRow(stars: stage.stars, dimmed: state == NodeState.locked),
        ),
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
                color: state == NodeState.locked
                    ? DuolingoColors.bodyText.withOpacity(0.5)
                    : DuolingoColors.darkText,
                fontWeight: state == NodeState.current
                    ? FontWeight.bold
                    : FontWeight.w600,
              ),
            ),
            if (stage.spellDate != null && stage.spellDate!.isNotEmpty)
              Text(
                stage.spellDate!,
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 11,
                  color: DuolingoColors.bodyText.withOpacity(
                    state == NodeState.locked ? 0.4 : 0.8,
                  ),
                ),
              ),
            if (stage.checkpointCount > 1 && state != NodeState.locked)
              Text(
                'Checkpoint ${stage.checkpointIndex + 1}/${stage.checkpointCount}',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.label.copyWith(
                  fontSize: 10,
                  color: DuolingoColors.bodyText.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    ];
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
  final NodeState state;
  final double progress;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _LessonNode({
    required this.state,
    required this.progress,
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
        icon = const Text('🔥', style: TextStyle(fontSize: 26));
        break;
      case NodeState.available:
        fill = DuolingoColors.informationBlue;
        border = const Color(0xFF1876BF);
        icon = const Icon(Icons.play_arrow, color: Colors.white, size: 28);
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

    if (state != NodeState.locked) {
      node = Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size + 10,
            height: size + 10,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: DuolingoColors.secondaryButtonGray.withOpacity(0.4),
              // darkText (0x333333) verified via WCAG relative-luminance
              // contrast: 6.05:1 vs primaryGreen, 6.40:1 vs streakOrange,
              // 4.41:1 vs informationBlue, 7.87:1 vs secondaryButtonGray
              // (the track's own background color) -- comfortably clears a
              // ~3:1 legibility floor against every node fill and the track,
              // unlike treasureGold (1.08-1.65:1 against all four) or
              // primaryGreen (identical to the completed fill).
              valueColor: const AlwaysStoppedAnimation<Color>(DuolingoColors.darkText),
            ),
          ),
          node,
        ],
      );
    }

    // Keep the node's outer footprint state-invariant (always size + 10, the
    // same box the ring occupies) so `Positioned` offsets computed by the
    // caller for the enlarged footprint stay centered on `center` whether or
    // not a ring is actually drawn (locked nodes have no ring but must still
    // report/occupy the same bounding box).
    node = SizedBox(
      width: size + 10,
      height: size + 10,
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
                  color: DuolingoColors.streakOrange
                      .withOpacity(0.5 - pulse.value * 0.25),
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
  final VoidCallback onTap;

  const _MilestoneNode({
    required this.size,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: unlocked
              ? const LinearGradient(
                  colors: [
                    DuolingoColors.treasureGold,
                    DuolingoColors.rewardYellow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: unlocked ? null : DuolingoColors.neutralGray,
          border: Border.all(
            color:
                unlocked ? const Color(0xFFB8860B) : const Color(0xFFAAAAAA),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  unlocked ? const Color(0xFFB8860B) : const Color(0xFFAAAAAA),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          unlocked ? '🎁' : '🔒',
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
