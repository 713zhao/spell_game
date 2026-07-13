import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/widgets/celebration.dart';

/// SpellQuest Journey Selection (Duolingo-style winding path).
///
/// A vertical, zig-zagging map of circular lesson nodes connected by a
/// dashed trail. Nodes are colored/iconed by state (completed / current /
/// available / locked), with star ratings and a milestone treasure chest
/// every 5 lessons. Locked lessons prompt an "Unlock Anyway" dialog.
class EnglishCastleScreen extends StatefulWidget {
  const EnglishCastleScreen({Key? key}) : super(key: key);

  @override
  State<EnglishCastleScreen> createState() => _EnglishCastleScreenState();
}

enum _NodeState { completed, current, available, locked }

class _EnglishCastleScreenState extends State<EnglishCastleScreen>
    with SingleTickerProviderStateMixin {
  // Mock stage data
  final List<StageData> stages = [
    StageData(
      stageNumber: 1,
      title: 'Week 1: Vowels',
      progress: 1.0,
      stars: 3,
      isLocked: false,
    ),
    StageData(
      stageNumber: 2,
      title: 'Week 2: Consonants',
      progress: 0.66,
      stars: 2,
      isLocked: false,
    ),
    StageData(
      stageNumber: 3,
      title: 'Week 3: Blends',
      progress: 0.33,
      stars: 1,
      isLocked: false,
    ),
    StageData(
      stageNumber: 4,
      title: 'Week 4: Digraphs',
      progress: 0.0,
      stars: 0,
      isLocked: true,
    ),
    StageData(
      stageNumber: 5,
      title: 'Week 5: Review',
      progress: 0.0,
      stars: 0,
      isLocked: true,
    ),
  ];

  late final AnimationController _pulseController;

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

  _NodeState _stateFor(int index) {
    final s = stages[index];
    if (s.isLocked) return _NodeState.locked;
    if (s.progress >= 1.0) return _NodeState.completed;
    final isFirstIncomplete = !stages
        .take(index)
        .any((prev) => !prev.isLocked && prev.progress < 1.0);
    return isFirstIncomplete ? _NodeState.current : _NodeState.available;
  }

  void _handleNodeTap(int index) {
    final state = _stateFor(index);
    if (state == _NodeState.locked) {
      _showUnlockDialog(index);
    } else {
      Navigator.pushNamed(
        context,
        '/lesson-overview',
        arguments: stages[index].stageNumber,
      );
    }
  }

  Future<void> _showUnlockDialog(int index) async {
    final recommended =
        (stages[index].stageNumber - 1).clamp(1, stages.length);
    final unlock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
        ),
        title: const Text('🔒 This lesson is locked'),
        content: Text(
          'This lesson is designed to build on previous skills.\n\n'
          'You can unlock it now, but we recommend completing '
          'Stage $recommended first.',
          style: DuolingoTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: DuolingoTextStyles.label
                  .copyWith(color: DuolingoColors.bodyText),
            ),
          ),
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
        ],
      ),
    );
    if (unlock == true && mounted) {
      setState(() => stages[index].isLocked = false);
      Navigator.pushNamed(
        context,
        '/lesson-overview',
        arguments: stages[index].stageNumber,
      );
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
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('English Kingdom', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: DuolingoColors.englishKingdomGradient,
                  ),
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('🏰', style: TextStyle(fontSize: 40)),
                    SizedBox(width: DuolingoSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Greetings, Scholar!',
                            style: DuolingoTextStyles.sectionTitle,
                          ),
                          SizedBox(height: DuolingoSpacing.xs),
                          Text(
                            'Master the English language through stages',
                            style: DuolingoTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              _JourneyPath(
                stages: stages,
                stateFor: _stateFor,
                pulse: _pulseController,
                onTapNode: _handleNodeTap,
                onTapMilestone: _handleMilestoneTap,
              ),
              SizedBox(height: DuolingoSpacing.xl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        backgroundColor: DuolingoColors.backgroundWhite,
        selectedItemColor: DuolingoColors.primaryGreen,
        unselectedItemColor: DuolingoColors.neutralGray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.backpack), label: 'Backpack'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Progress'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacementNamed('/');
              break;
            case 1:
              Navigator.of(context).pushReplacementNamed('/world-map');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/backpack');
              break;
            case 3:
              Navigator.of(context).pushReplacementNamed('/progress');
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/profile');
              break;
          }
        },
      ),
    );
  }
}

// Stage data model
class StageData {
  final int stageNumber;
  final String title;
  final double progress; // 0.0 to 1.0
  final int stars; // 0 to 3
  bool isLocked;

  StageData({
    required this.stageNumber,
    required this.title,
    required this.progress,
    required this.stars,
    required this.isLocked,
  });
}

/// One entry in the winding path: either a lesson node or a milestone chest.
abstract class _PathItem {}

class _LessonItem extends _PathItem {
  final int index; // index into stages
  _LessonItem(this.index);
}

class _MilestoneItem extends _PathItem {
  final bool unlocked;
  _MilestoneItem({required this.unlocked});
}

/// The winding vertical journey map.
class _JourneyPath extends StatelessWidget {
  final List<StageData> stages;
  final _NodeState Function(int index) stateFor;
  final AnimationController pulse;
  final void Function(int index) onTapNode;
  final void Function(bool unlocked) onTapMilestone;

  static const double _nodeSize = DuolingoSpacing.nodeSize; // 56
  static const double _milestoneSize = DuolingoSpacing.nodeSize + 26; // 82
  static const double _rowSpacing = 122;
  static const double _topPadding = 70;
  // Zig-zag horizontal fractions across the available width, cycling.
  static const List<double> _xFractions = [0.5, 0.8, 0.5, 0.2];

  const _JourneyPath({
    required this.stages,
    required this.stateFor,
    required this.pulse,
    required this.onTapNode,
    required this.onTapMilestone,
  });

  List<_PathItem> _buildItems() {
    final items = <_PathItem>[];
    for (var i = 0; i < stages.length; i++) {
      items.add(_LessonItem(i));
      if ((i + 1) % 5 == 0) {
        final unlocked = stages[i].progress >= 1.0;
        items.add(_MilestoneItem(unlocked: unlocked));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItems();

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
                    DuolingoColors.englishKingdomGradient[0]
                        .withOpacity(0.35),
                    DuolingoColors.backgroundWhite,
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(DuolingoSpacing.radiusCard),
              ),
              child: Stack(
                children: [
                  // Castle banner at the top of the path
                  Positioned(
                    top: 4,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const Text('🏰', style: TextStyle(fontSize: 30)),
                        Text(
                          'Castle',
                          style: DuolingoTextStyles.label
                              .copyWith(color: DuolingoColors.bodyText),
                        ),
                      ],
                    ),
                  ),
                  // Dashed connecting trail
                  CustomPaint(
                    size: Size(width, totalHeight),
                    painter: _TrailPainter(centers: centers),
                  ),
                  // Nodes + labels
                  for (var i = 0; i < items.length; i++)
                    ..._buildItemWidgets(context, items[i], i, centers[i],
                        width),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildItemWidgets(
    BuildContext context,
    _PathItem item,
    int i,
    Offset center,
    double width,
  ) {
    if (item is _MilestoneItem) {
      return [
        Positioned(
          left: center.dx - _milestoneSize / 2,
          top: center.dy - _milestoneSize / 2,
          child: _MilestoneNode(
            size: _milestoneSize,
            unlocked: item.unlocked,
            onTap: () => onTapMilestone(item.unlocked),
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

    final index = (item as _LessonItem).index;
    final stage = stages[index];
    final state = stateFor(index);

    return [
      Positioned(
        left: center.dx - _nodeSize / 2,
        top: center.dy - _nodeSize / 2,
        child: _LessonNode(
          state: state,
          pulse: pulse,
          onTap: () => onTapNode(index),
        ),
      ),
      if (stage.stars > 0)
        Positioned(
          top: center.dy - _nodeSize / 2 - 22,
          left: (center.dx - 40).clamp(0, width - 80),
          width: 80,
          child: _StarRow(stars: stage.stars, dimmed: state == _NodeState.locked),
        ),
      Positioned(
        top: center.dy + _nodeSize / 2 + 6,
        left: (center.dx - 70).clamp(0, width - 140),
        width: 140,
        child: Text(
          stage.title,
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.label.copyWith(
            color: state == _NodeState.locked
                ? DuolingoColors.bodyText.withOpacity(0.5)
                : DuolingoColors.darkText,
            fontWeight:
                state == _NodeState.current ? FontWeight.bold : FontWeight.w600,
          ),
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

/// A single circular lesson node, styled per state.
class _LessonNode extends StatelessWidget {
  final _NodeState state;
  final AnimationController pulse;
  final VoidCallback onTap;

  const _LessonNode({
    required this.state,
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
      case _NodeState.completed:
        fill = DuolingoColors.primaryGreen;
        border = const Color(0xFF58A700);
        icon = const Icon(Icons.check, color: Colors.white, size: 28);
        break;
      case _NodeState.current:
        fill = DuolingoColors.streakOrange;
        border = const Color(0xFFCC7A00);
        icon = const Text('🔥', style: TextStyle(fontSize: 26));
        break;
      case _NodeState.available:
        fill = DuolingoColors.informationBlue;
        border = const Color(0xFF1876BF);
        icon = const Icon(Icons.play_arrow, color: Colors.white, size: 28);
        break;
      case _NodeState.locked:
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

    if (state == _NodeState.current) {
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

    return GestureDetector(
      onTap: onTap,
      child: node,
    );
  }
}

/// Milestone treasure chest node shown every 5 lessons.
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
            color: unlocked
                ? const Color(0xFFB8860B)
                : const Color(0xFFAAAAAA),
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: unlocked
                  ? const Color(0xFFB8860B)
                  : const Color(0xFFAAAAAA),
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

/// Dashed trail connecting node centers, drawn as straight zig-zag segments.
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
      final segEnd =
          a + direction * (drawn + dashLength).clamp(0, total);
      canvas.drawLine(segStart, segEnd, paint);
      drawn += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) =>
      oldDelegate.centers != centers;
}
