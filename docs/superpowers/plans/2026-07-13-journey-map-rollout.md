# Journey Map Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Roll the Duolingo-style journey map (currently English-Kingdom-only) out to Chinese Kingdom via a shared widget, add coin rewards + kingdom theming to Lesson Overview, wire the existing Parent Mode toggle to disable lesson skip-lock, and delete the two now-bypassed flat word-grid screens.

**Architecture:** Extract the pure lesson-state/path-layout logic and the journey-map rendering out of `english_castle_screen.dart` into `lib/models/stage_data.dart` (data + pure functions) and `lib/widgets/journey_path.dart` (shared widget). Both kingdom screens become thin wrappers supplying their own stage list and kingdom theme. `lesson_overview_screen.dart` gains a `LessonOverviewArgs`/`KingdomTheme` pair so it can render either kingdom's colors and a real coin reward.

**Tech Stack:** Flutter/Dart 3.8, `flutter_test` for widget/unit tests, `shared_preferences` (already a dependency) for reading the Parent Mode flag.

**Spec:** `docs/superpowers/specs/2026-07-13-journey-map-rollout-design.md`

---

### Task 1: `StageData` model + pure journey logic

**Files:**
- Create: `lib/models/stage_data.dart`
- Test: `test/models/stage_data_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/models/stage_data_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/stage_data.dart';

List<StageData> _stages() => [
      StageData(stageNumber: 1, title: 'One', progress: 1.0, stars: 3, isLocked: false),
      StageData(stageNumber: 2, title: 'Two', progress: 0.5, stars: 1, isLocked: false),
      StageData(stageNumber: 3, title: 'Three', progress: 0.0, stars: 0, isLocked: false),
      StageData(stageNumber: 4, title: 'Four', progress: 0.0, stars: 0, isLocked: true),
    ];

void main() {
  group('deriveNodeState', () {
    test('completed stage returns NodeState.completed', () {
      expect(deriveNodeState(_stages(), 0), NodeState.completed);
    });

    test('first not-fully-completed unlocked stage returns NodeState.current', () {
      expect(deriveNodeState(_stages(), 1), NodeState.current);
    });

    test('unlocked stage after the current one returns NodeState.available', () {
      expect(deriveNodeState(_stages(), 2), NodeState.available);
    });

    test('locked stage returns NodeState.locked regardless of progress', () {
      expect(deriveNodeState(_stages(), 3), NodeState.locked);
    });
  });

  group('buildPathItems', () {
    test('inserts one milestone after every 5th stage', () {
      final stages = List.generate(
        12,
        (i) => StageData(
          stageNumber: i + 1,
          title: 'Stage ${i + 1}',
          progress: i < 5 ? 1.0 : 0.0,
          stars: 0,
          isLocked: i >= 5,
        ),
      );

      final items = buildPathItems(stages);

      // 12 lessons + milestones after stage 5 and stage 10 = 14 items.
      expect(items.length, 14);
      expect(items[5], isA<MilestoneItem>());
      expect((items[5] as MilestoneItem).unlocked, isTrue);
      expect(items[11], isA<MilestoneItem>());
      expect((items[11] as MilestoneItem).unlocked, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/stage_data_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'spell_game' in 'package:spell_game/models/stage_data.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

```dart
// lib/models/stage_data.dart

/// One lesson node's data within a kingdom's journey path.
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

enum NodeState { completed, current, available, locked }

/// Derives the visual state of the lesson at [index] from the full stage
/// list: locked stays locked, the first not-yet-completed unlocked stage is
/// "current", completed stages show a checkmark, and any unlocked stage
/// after the current one is "available" (can be replayed/started).
NodeState deriveNodeState(List<StageData> stages, int index) {
  final stage = stages[index];
  if (stage.isLocked) return NodeState.locked;
  if (stage.progress >= 1.0) return NodeState.completed;
  final isFirstIncomplete = !stages
      .take(index)
      .any((prev) => !prev.isLocked && prev.progress < 1.0);
  return isFirstIncomplete ? NodeState.current : NodeState.available;
}

/// An entry in the winding path: either a lesson node or a milestone chest
/// shown every 5 lessons.
abstract class PathItem {}

class LessonItem extends PathItem {
  final int index; // index into stages
  LessonItem(this.index);
}

class MilestoneItem extends PathItem {
  final bool unlocked;
  MilestoneItem({required this.unlocked});
}

/// Interleaves lesson nodes with a treasure-chest milestone every 5 stages.
/// A milestone is unlocked once the preceding stage is completed.
List<PathItem> buildPathItems(List<StageData> stages) {
  final items = <PathItem>[];
  for (var i = 0; i < stages.length; i++) {
    items.add(LessonItem(i));
    if ((i + 1) % 5 == 0) {
      items.add(MilestoneItem(unlocked: stages[i].progress >= 1.0));
    }
  }
  return items;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/models/stage_data_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/stage_data.dart test/models/stage_data_test.dart
git commit -m "feat: extract StageData model and pure journey-path logic"
```

---

### Task 2: Shared `JourneyPath` widget

**Files:**
- Create: `lib/widgets/journey_path.dart`
- Test: `test/widgets/journey_path_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/journey_path_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';

List<StageData> _stages() => [
      StageData(stageNumber: 1, title: 'Stage 1', progress: 1.0, stars: 3, isLocked: false),
      StageData(stageNumber: 2, title: 'Stage 2', progress: 0.0, stars: 0, isLocked: true),
    ];

Future<void> _pump(
  WidgetTester tester,
  void Function(int) onSelect, {
  bool allowSkipLock = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JourneyPath(
          stages: _stages(),
          kingdomEmoji: '🏰',
          kingdomLabel: 'Castle',
          gradientColors: const [Color(0xFFE6F5FF), Color(0xFFCCE6FF)],
          allowSkipLock: allowSkipLock,
          onSelectLesson: onSelect,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('tapping a completed lesson node calls onSelectLesson',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();

    expect(selected, 1);
  });

  testWidgets(
      'tapping a locked node with allowSkipLock true offers Unlock Anyway',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n, allowSkipLock: true);

    await tester.tap(find.byIcon(Icons.lock));
    // NOTE: don't use pumpAndSettle() here — JourneyPath's pulse
    // AnimationController repeats indefinitely (for the "current" node glow)
    // even when unused by this test's stages, so pumpAndSettle would never
    // detect settling and would time out. Pump a bounded duration instead,
    // long enough for the dialog's open transition to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsOneWidget);

    await tester.tap(find.text('UNLOCK ANYWAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 2);
  });

  testWidgets(
      'tapping a locked node with allowSkipLock false has no skip option',
      (tester) async {
    int? selected;
    await _pump(tester, (n) => selected = n, allowSkipLock: false);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsNothing);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/journey_path_test.dart`
Expected: FAIL — `journey_path.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/widgets/journey_path.dart
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

    return [
      Positioned(
        left: center.dx - _nodeSize / 2,
        top: center.dy - _nodeSize / 2,
        child: _LessonNode(
          state: state,
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
        child: Text(
          stage.title,
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.label.copyWith(
            color: state == NodeState.locked
                ? DuolingoColors.bodyText.withOpacity(0.5)
                : DuolingoColors.darkText,
            fontWeight:
                state == NodeState.current ? FontWeight.bold : FontWeight.w600,
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

class _LessonNode extends StatelessWidget {
  final NodeState state;
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widgets/journey_path_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/journey_path.dart test/widgets/journey_path_test.dart
git commit -m "feat: extract shared JourneyPath widget from English Castle screen"
```

---

### Task 3: Reward calc + kingdom theming on Lesson Overview

**Files:**
- Create: `lib/utils/reward_calc.dart`
- Test: `test/utils/reward_calc_test.dart`
- Modify: `lib/screens/lesson_overview_screen.dart` (full contents below)
- Modify: `lib/main.dart:20,77-83` (import + route case)

- [ ] **Step 1: Write the failing test**

```dart
// test/utils/reward_calc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/utils/reward_calc.dart';

void main() {
  test('scales xp and coins with word count', () {
    final rewards = computeLessonRewards(20);
    expect(rewards.xp, 200);
    expect(rewards.coins, 40);
  });

  test('zero words gives zero rewards', () {
    final rewards = computeLessonRewards(0);
    expect(rewards.xp, 0);
    expect(rewards.coins, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/reward_calc_test.dart`
Expected: FAIL — `reward_calc.dart` doesn't exist yet.

- [ ] **Step 3: Write the reward calc implementation**

```dart
// lib/utils/reward_calc.dart

class LessonRewards {
  final int xp;
  final int coins;

  const LessonRewards({required this.xp, required this.coins});
}

/// XP and coin rewards shown on the Lesson Overview screen, scaled to the
/// number of words in the deck.
LessonRewards computeLessonRewards(int wordCount) {
  return LessonRewards(xp: wordCount * 10, coins: wordCount * 2);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/reward_calc_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Add `KingdomTheme`/`LessonOverviewArgs` and wire rewards into Lesson Overview**

Replace the full contents of `lib/screens/lesson_overview_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../main.dart' show gameProvider;
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

/// Navigation arguments for the '/lesson-overview' route.
class LessonOverviewArgs {
  final int levelId;
  final KingdomTheme kingdom;

  const LessonOverviewArgs({
    required this.levelId,
    this.kingdom = KingdomTheme.english,
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
    final level = levels.where((l) => l.id == widget.args.levelId).isNotEmpty
        ? levels.firstWhere((l) => l.id == widget.args.levelId)
        : null;
    final levelName = level?.name ?? 'Stage ${widget.args.levelId}';
    final difficulty = level?.difficulty ?? widget.args.levelId;

    final wordCount = gameProvider.deckCards.isEmpty
        ? 10
        : gameProvider.deckCards.length;
    final newWords =
        gameProvider.deckCards.where((c) => c.repetitions == 0).length;
    // Learn cards ~8s, exercises ~20s each
    final estMinutes =
        ((newWords * 8 + wordCount * 20) / 60).ceil().clamp(1, 30);
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
                  gradient: LinearGradient(
                    colors: widget.args.kingdom.gradientColors,
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
                    Text(widget.args.kingdom.emoji,
                        style: const TextStyle(fontSize: 64)),
                    SizedBox(height: DuolingoSpacing.md),
                    Text(
                      'Stage ${widget.args.levelId}',
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
                        _RewardChip(
                            emoji: '⚡', label: 'up to ${rewards.xp} XP'),
                        _RewardChip(
                            emoji: '💰', label: '${rewards.coins} Coins'),
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
                    arguments: widget.args.levelId,
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
```

- [ ] **Step 6: Update the `/lesson-overview` route in `main.dart`**

In `lib/main.dart`, change:

```dart
            case '/lesson-overview':
              final overviewLevelId = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => LessonOverviewScreen(
                  levelId: overviewLevelId ?? 1,
                ),
              );
```

to:

```dart
            case '/lesson-overview':
              final overviewArgs = settings.arguments as LessonOverviewArgs;
              return MaterialPageRoute(
                builder: (context) => LessonOverviewScreen(args: overviewArgs),
              );
```

(`LessonOverviewArgs` is already visible here via the existing `import 'screens/lesson_overview_screen.dart';`.)

- [ ] **Step 7: Run the full test suite to confirm nothing broke**

Run: `flutter test`
Expected: `All tests passed!` (existing smoke test in `test/widget_test.dart` still passes; `english_castle_screen.dart` still compiles against its old `Navigator.pushNamed('/lesson-overview', arguments: stages[index].stageNumber)` calls will now fail to compile — this is expected and fixed in Task 4. If Task 4 hasn't run yet, `flutter analyze` will show errors in `english_castle_screen.dart`; that's fine, it's fixed next.)

- [ ] **Step 8: Commit**

```bash
git add lib/utils/reward_calc.dart test/utils/reward_calc_test.dart lib/screens/lesson_overview_screen.dart lib/main.dart
git commit -m "feat: add coin rewards and per-kingdom theming to Lesson Overview"
```

---

### Task 4: Refactor English Castle screen onto the shared widget

**Files:**
- Modify: `lib/screens/english_castle_screen.dart` (full replacement below)

- [ ] **Step 1: Replace the full contents of `lib/screens/english_castle_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';
import 'lesson_overview_screen.dart';

/// SpellQuest Journey Selection (Duolingo-style winding path) for the
/// English Kingdom. Renders the shared [JourneyPath] widget over this
/// kingdom's stage data.
class EnglishCastleScreen extends StatefulWidget {
  const EnglishCastleScreen({Key? key}) : super(key: key);

  @override
  State<EnglishCastleScreen> createState() => _EnglishCastleScreenState();
}

class _EnglishCastleScreenState extends State<EnglishCastleScreen> {
  // Mock stage data
  final List<StageData> stages = [
    StageData(
        stageNumber: 1,
        title: 'Week 1: Vowels',
        progress: 1.0,
        stars: 3,
        isLocked: false),
    StageData(
        stageNumber: 2,
        title: 'Week 2: Consonants',
        progress: 0.66,
        stars: 2,
        isLocked: false),
    StageData(
        stageNumber: 3,
        title: 'Week 3: Blends',
        progress: 0.33,
        stars: 1,
        isLocked: false),
    StageData(
        stageNumber: 4,
        title: 'Week 4: Digraphs',
        progress: 0.0,
        stars: 0,
        isLocked: true),
    StageData(
        stageNumber: 5,
        title: 'Week 5: Review',
        progress: 0.0,
        stars: 0,
        isLocked: true),
  ];

  bool _allowSkipLock = true;

  @override
  void initState() {
    super.initState();
    _loadParentMode();
  }

  Future<void> _loadParentMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _allowSkipLock = !(prefs.getBool('parent_mode') ?? false));
  }

  void _openLesson(int stageNumber) {
    Navigator.pushNamed(
      context,
      '/lesson-overview',
      arguments: LessonOverviewArgs(
        levelId: stageNumber,
        kingdom: KingdomTheme.english,
      ),
    );
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
              JourneyPath(
                stages: stages,
                kingdomEmoji: '🏰',
                kingdomLabel: 'Castle',
                gradientColors: DuolingoColors.englishKingdomGradient,
                allowSkipLock: _allowSkipLock,
                onSelectLesson: _openLesson,
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
```

- [ ] **Step 2: Run `flutter analyze` to confirm no compile errors**

Run: `flutter analyze lib/screens/english_castle_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/english_castle_screen.dart
git commit -m "refactor: rebuild English Castle screen on shared JourneyPath widget"
```

---

### Task 5: Chinese Kingdom stage data

**Files:**
- Create: `lib/data/chinese_stages.dart`
- Test: `test/data/chinese_stages_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/chinese_stages_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/data/chinese_stages.dart';

void main() {
  test('builds 30 stages titled by group nickname', () {
    final stages = buildChineseStages();

    expect(stages.length, 30);
    expect(stages.first.title, 'Forest 1');
    expect(stages[9].title, 'Forest 10');
    expect(stages[10].title, 'River 1');
    expect(stages[19].title, 'River 10');
    expect(stages[20].title, 'Mountain 1');
    expect(stages.last.title, 'Mountain 10');
  });

  test('first 7 stages completed, 8-10 unlocked in progress, 11+ locked', () {
    final stages = buildChineseStages();

    expect(stages[6].progress, 1.0); // stage 7
    expect(stages[6].isLocked, isFalse);
    expect(stages[7].isLocked, isFalse); // stage 8, current
    expect(stages[7].progress, 0.0);
    expect(stages[9].isLocked, isFalse); // stage 10, available
    expect(stages[10].isLocked, isTrue); // stage 11, locked
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/chinese_stages_test.dart`
Expected: FAIL — `chinese_stages.dart` doesn't exist yet.

- [ ] **Step 3: Write the implementation**

```dart
// lib/data/chinese_stages.dart
import 'package:spell_game/models/stage_data.dart';

/// Mock stage data for the Chinese Kingdom's journey path: 3 themed groups
/// of 10 lessons each (Forest, River, Mountain), flattened into one winding
/// path so it renders with the same [JourneyPath] widget as English
/// Kingdom. Progress ports the previous mock: 7/10 Forest lessons done.
List<StageData> buildChineseStages() {
  const groupNames = ['Forest', 'River', 'Mountain'];
  const lessonsPerGroup = 10;

  final stages = <StageData>[];
  for (var g = 0; g < groupNames.length; g++) {
    for (var i = 1; i <= lessonsPerGroup; i++) {
      final stageNumber = g * lessonsPerGroup + i;
      stages.add(StageData(
        stageNumber: stageNumber,
        title: '${groupNames[g]} $i',
        progress: stageNumber <= 7 ? 1.0 : 0.0,
        stars: stageNumber <= 7 ? 3 : 0,
        isLocked: stageNumber > 10,
      ));
    }
  }
  return stages;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/chinese_stages_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/data/chinese_stages.dart test/data/chinese_stages_test.dart
git commit -m "feat: add flattened Chinese Kingdom stage data with themed nicknames"
```

---

### Task 6: Rewrite Chinese Kingdom screen onto the shared widget

**Files:**
- Modify: `lib/screens/chinese_kingdom_screen.dart` (full replacement below)

- [ ] **Step 1: Replace the full contents of `lib/screens/chinese_kingdom_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/data/chinese_stages.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/journey_path.dart';
import 'lesson_overview_screen.dart';

/// SpellQuest Journey Selection (Duolingo-style winding path) for the
/// Chinese Kingdom. Same [JourneyPath] widget as English Kingdom, themed
/// with Forest/River/Mountain lesson nicknames.
class ChineseKingdomScreen extends StatefulWidget {
  const ChineseKingdomScreen({Key? key}) : super(key: key);

  @override
  State<ChineseKingdomScreen> createState() => _ChineseKingdomScreenState();
}

class _ChineseKingdomScreenState extends State<ChineseKingdomScreen> {
  final List<StageData> stages = buildChineseStages();
  bool _allowSkipLock = true;

  @override
  void initState() {
    super.initState();
    _loadParentMode();
  }

  Future<void> _loadParentMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _allowSkipLock = !(prefs.getBool('parent_mode') ?? false));
  }

  void _openLesson(int stageNumber) {
    Navigator.pushNamed(
      context,
      '/lesson-overview',
      arguments: LessonOverviewArgs(
        levelId: stageNumber,
        kingdom: KingdomTheme.chinese,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Chinese Kingdom', style: DuolingoTextStyles.pageTitle),
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
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: DuolingoColors.chineseKingdomGradient,
                  ),
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Row(
                  children: [
                    const Text('🐉', style: TextStyle(fontSize: 40)),
                    SizedBox(width: DuolingoSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ni Hao, Traveler!',
                            style: DuolingoTextStyles.sectionTitle,
                          ),
                          SizedBox(height: DuolingoSpacing.xs),
                          Text(
                            'Journey through Forest, River, and Mountain',
                            style: DuolingoTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              JourneyPath(
                stages: stages,
                kingdomEmoji: '🐉',
                kingdomLabel: 'Kingdom',
                gradientColors: DuolingoColors.chineseKingdomGradient,
                allowSkipLock: _allowSkipLock,
                onSelectLesson: _openLesson,
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
```

- [ ] **Step 2: Run `flutter analyze` to confirm no compile errors**

Run: `flutter analyze lib/screens/chinese_kingdom_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/chinese_kingdom_screen.dart
git commit -m "feat: give Chinese Kingdom the same journey-map experience as English"
```

---

### Task 7: Retire the flat word-grid screens

**Files:**
- Delete: `lib/screens/english_level_screen.dart`
- Delete: `lib/screens/chinese_lesson_screen.dart`
- Modify: `lib/main.dart` (remove imports + route cases)

- [ ] **Step 1: Confirm nothing else references the routes/classes being removed**

Run: `grep -rn "english_level_screen\|chinese_lesson_screen\|english-level\|chinese-lesson\|EnglishLevelScreen\|ChineseLessonScreen" lib test`
Expected: only `lib/main.dart` (import + route case for each) — `chinese_kingdom_screen.dart` no longer references `/chinese-lesson` after Task 6.

- [ ] **Step 2: Delete the two files**

```bash
git rm lib/screens/english_level_screen.dart lib/screens/chinese_lesson_screen.dart
```

- [ ] **Step 3: Remove their imports and route cases from `lib/main.dart`**

Remove these two import lines:

```dart
import 'screens/english_level_screen.dart';
```
```dart
import 'screens/chinese_lesson_screen.dart';
```

Remove these two route cases:

```dart
            case '/english-level':
              final stageNumber = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => EnglishLevelScreen(
                  stageNumber: stageNumber ?? 1,
                ),
              );
```
```dart
            case '/chinese-lesson':
              final lessonNum = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => ChineseLessonScreen(
                  lessonNumber: lessonNum ?? 1,
                ),
              );
```

- [ ] **Step 4: Run `flutter analyze` on the whole project**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "chore: delete flat word-grid screens superseded by the journey map"
```

---

### Task 8: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the full analyzer**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: `All tests passed!` (covers Tasks 1-7: `stage_data_test.dart`, `journey_path_test.dart`, `reward_calc_test.dart`, `chinese_stages_test.dart`, and the pre-existing `widget_test.dart` smoke test)

- [ ] **Step 3: Manually verify in the browser**

Run: `flutter run -d chrome`

Walk the path: World Map → English Kingdom (journey map renders, tap a completed/current/locked node, confirm the lock dialog and Lesson Overview → Start Adventure flow) → back → World Map → Chinese Kingdom (same journey map, Forest/River/Mountain nicknames, same flow). Then toggle Profile → Settings → Parent Mode on, return to either kingdom, and confirm tapping a locked lesson no longer offers "Unlock Anyway" (only "OK").

- [ ] **Step 4: Commit if the manual pass required any follow-up fixes**

Only if Step 3 surfaced an issue — fix it, then:

```bash
git add -A
git commit -m "fix: address issue found during manual journey-map verification"
```
