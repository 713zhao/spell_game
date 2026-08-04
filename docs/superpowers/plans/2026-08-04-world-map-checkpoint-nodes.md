# World Map Checkpoint Nodes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the World Map's barely-visible "Checkpoint N/M" text caption with an actual chain of full-size checkpoint nodes per lesson — the same visual treatment Duolingo uses — so checkpoint progress is legible at a glance instead of only readable as text.

**Architecture:** All logic moves into two files. `stage_data.dart`'s `buildPathItems` is rewritten to flatten each lesson into `max(1, checkpointCount)` node units (state, milestone placement, and label-anchor selection all computed once, per unit, in this pure function) instead of the old one-node-per-lesson model. `journey_path.dart` is updated to consume the new `LessonItem` shape directly (no more separate `deriveNodeState` call), drop the per-node progress ring entirely, gate the title/date/star-row label to the one "anchor" node per lesson, and split locked-node tap handling into "whole lesson locked" (existing dialog) vs. "checkpoint not yet reached" (a lightweight hint, no navigation).

**Tech Stack:** Flutter, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-04-world-map-checkpoint-nodes-design.md`

---

## Task 1: Flatten lessons into checkpoint units in `stage_data.dart`

**Files:**
- Modify: `FlutterSpell_Game/lib/models/stage_data.dart` (full-file replacement)
- Modify: `FlutterSpell_Game/test/models/stage_data_test.dart` (full-file replacement)

- [ ] **Step 1: Replace the test file with tests for the new flattening/state logic**

Replace the entire contents of `FlutterSpell_Game/test/models/stage_data_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/stage_data.dart';

List<StageData> _stages() => [
      StageData(stageNumber: 1, title: 'One', progress: 1.0, stars: 3, isLocked: false),
      StageData(stageNumber: 2, title: 'Two', progress: 0.5, stars: 1, isLocked: false),
      StageData(stageNumber: 3, title: 'Three', progress: 0.0, stars: 0, isLocked: false),
      StageData(stageNumber: 4, title: 'Four', progress: 0.0, stars: 0, isLocked: true),
    ];

void main() {
  group('buildPathItems - single-checkpoint (legacy) lessons', () {
    test('degrades to one node per lesson with the same state rules as before', () {
      final items = buildPathItems(_stages()).whereType<LessonItem>().toList();

      expect(items.length, 4);
      expect(items[0].state, NodeState.completed);
      expect(items[1].state, NodeState.current);
      expect(items[2].state, NodeState.available);
      expect(items[3].state, NodeState.locked);
    });

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

  group('buildPathItems - multi-checkpoint lessons', () {
    test('a partially-mastered lesson yields completed/current/locked units', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 0.4,
          stars: 1,
          isLocked: false,
          checkpointIndex: 1,
          checkpointCount: 3,
        ),
      ];

      final units = buildPathItems(stages).whereType<LessonItem>().toList();

      expect(units.length, 3);
      expect(units[0].state, NodeState.completed);
      expect(units[1].state, NodeState.current);
      expect(units[2].state, NodeState.locked);
    });

    test('a fully-mastered lesson marks every checkpoint completed', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 1.0,
          stars: 3,
          isLocked: false,
          checkpointIndex: 2, // parked on the last chunk once fully mastered
          checkpointCount: 3,
        ),
      ];

      final units = buildPathItems(stages).whereType<LessonItem>().toList();

      expect(units.every((u) => u.state == NodeState.completed), isTrue);
    });

    test('a locked lesson marks every checkpoint locked regardless of checkpointIndex', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 0.0,
          stars: 0,
          isLocked: true,
          checkpointIndex: 1,
          checkpointCount: 3,
        ),
      ];

      final units = buildPathItems(stages).whereType<LessonItem>().toList();

      expect(units.every((u) => u.state == NodeState.locked), isTrue);
    });

    test('an unlocked lesson after the current one is available, not locked', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 0.4,
          stars: 1,
          isLocked: false,
          checkpointIndex: 0,
          checkpointCount: 1,
        ),
        StageData(
          stageNumber: 2,
          title: 'Week 2',
          progress: 0.0,
          stars: 0,
          isLocked: false, // unlocked (e.g. via "Unlock Anyway") but not yet started
          checkpointIndex: 0,
          checkpointCount: 3,
        ),
      ];

      final units = buildPathItems(stages).whereType<LessonItem>().toList();

      expect(units[0].state, NodeState.current); // Week 1's only checkpoint
      expect(units[1].state, NodeState.available); // Week 2's first checkpoint
      expect(units[2].state, NodeState.locked); // Week 2's second checkpoint (not reached)
      expect(units[3].state, NodeState.locked); // Week 2's third checkpoint (not reached)
    });

    test('milestones count checkpoint nodes, not lessons, so they can fall mid-lesson', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 1.0,
          stars: 3,
          isLocked: false,
          checkpointIndex: 2,
          checkpointCount: 3,
        ),
        StageData(
          stageNumber: 2,
          title: 'Week 2',
          progress: 0.4,
          stars: 1,
          isLocked: false,
          checkpointIndex: 1,
          checkpointCount: 3,
        ),
      ];

      final items = buildPathItems(stages);

      // 6 checkpoint units total (3 + 3); a milestone falls after the 5th
      // one, which is Week 2's 2nd checkpoint (index 4 in the flat list) -
      // i.e. mid-lesson, not aligned to the Week 1/Week 2 boundary.
      expect(items.length, 7); // 6 LessonItems + 1 MilestoneItem
      expect(items[5], isA<MilestoneItem>());
      final unitBeforeMilestone = items[4] as LessonItem;
      expect(unitBeforeMilestone.stageIndex, 1); // Week 2
      expect(unitBeforeMilestone.checkpointIndex, 1); // its 2nd checkpoint
    });
  });

  group('buildPathItems - label anchor placement', () {
    test('the label anchor is the middle checkpoint for a range of checkpoint counts', () {
      final anchorIndexByCount = <int, int>{
        1: 0,
        2: 0,
        3: 1,
        4: 1,
        5: 2,
      };

      for (final entry in anchorIndexByCount.entries) {
        final stages = [
          StageData(
            stageNumber: 1,
            title: 'Week 1',
            progress: 0.0,
            stars: 0,
            isLocked: false,
            checkpointIndex: 0,
            checkpointCount: entry.key,
          ),
        ];

        final units = buildPathItems(stages).whereType<LessonItem>().toList();
        final anchors = units.where((u) => u.isLabelAnchor).toList();

        expect(anchors.length, 1,
            reason: 'checkpointCount=${entry.key} should have exactly one label anchor');
        expect(anchors.single.checkpointIndex, entry.value,
            reason: 'checkpointCount=${entry.key} should anchor at checkpoint ${entry.value}');
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd FlutterSpell_Game
flutter test test/models/stage_data_test.dart
```

Expected: FAIL to compile — `LessonItem` doesn't yet have `.state`/`.checkpointIndex`/`.isLabelAnchor`, and `deriveNodeState` (referenced nowhere in this new test file) has been silently orphaned by removing the old `group('deriveNodeState', ...)` block from the test file, but the implementation hasn't changed yet, so `LessonItem(this.index)`'s single-int constructor doesn't match the new tests' expectations at all (analyzer errors, not runtime failures).

- [ ] **Step 3: Replace the implementation**

Replace the entire contents of `FlutterSpell_Game/lib/models/stage_data.dart` with:

```dart
/// One lesson node's data within a kingdom's journey path.
class StageData {
  final int stageNumber;
  final String title;
  final double progress; // 0.0 to 1.0
  final int stars; // 0 to 3
  bool isLocked;
  final String? spellDate; // raw text, e.g. "七月十四日"; null when unset
  final int checkpointIndex; // 0-based index of the current unlocked checkpoint
  final int checkpointCount; // total checkpoints; <= 1 means this lesson renders as a single node

  StageData({
    required this.stageNumber,
    required this.title,
    required this.progress,
    required this.stars,
    required this.isLocked,
    this.spellDate,
    this.checkpointIndex = 0,
    this.checkpointCount = 0,
  });
}

enum NodeState { completed, current, available, locked }

/// An entry in the winding path: either one checkpoint's node within a
/// lesson, or a milestone chest shown every 5 checkpoint nodes.
abstract class PathItem {}

/// One checkpoint's node on the path. A lesson with `checkpointCount`
/// checkpoints contributes that many consecutive LessonItems; a lesson with
/// `checkpointCount <= 1` (legacy/no-checkpoint data) contributes exactly
/// one, matching the original one-node-per-lesson behavior.
class LessonItem extends PathItem {
  final int stageIndex; // index into the stages list passed to buildPathItems
  final int checkpointIndex; // 0-based position within this lesson's cluster
  final NodeState state;
  final bool isLabelAnchor; // true only for the middle node of this lesson's cluster

  LessonItem({
    required this.stageIndex,
    required this.checkpointIndex,
    required this.state,
    required this.isLabelAnchor,
  });
}

class MilestoneItem extends PathItem {
  final bool unlocked;
  MilestoneItem({required this.unlocked});
}

/// Flattens every lesson into its checkpoint-node units (in stage order),
/// deriving each unit's locked/current/completed/available state the same
/// way the map's lesson-level state used to be derived, just at checkpoint
/// granularity: a unit is locked if its lesson is locked, or if it's a
/// checkpoint not yet reached; completed if its lesson is fully mastered, or
/// it's an earlier checkpoint than the lesson's current one; the first unit
/// that's neither locked nor completed is "current", any later one is
/// "available" (replaying an already-unlocked lesson/checkpoint).
///
/// Interleaves a milestone treasure chest every 5 checkpoint nodes overall
/// (not every 5 lessons - a lesson with more checkpoints reaches the next
/// chest sooner in node-count terms, so cadence stays roughly steady
/// regardless of lesson length).
List<PathItem> buildPathItems(List<StageData> stages) {
  final items = <PathItem>[];
  var firstIncompleteAssigned = false;

  for (var i = 0; i < stages.length; i++) {
    final stage = stages[i];
    final unitCount = stage.checkpointCount <= 1 ? 1 : stage.checkpointCount;
    final anchorIndex = (unitCount - 1) ~/ 2;
    final lessonDone = stage.progress >= 1.0;
    final stageHasIncompleteUnit = !stage.isLocked && !lessonDone;

    for (var c = 0; c < unitCount; c++) {
      final locked = stage.isLocked || (!lessonDone && c > stage.checkpointIndex);
      final done = lessonDone || (!stage.isLocked && c < stage.checkpointIndex);

      NodeState state;
      if (locked) {
        state = NodeState.locked;
      } else if (done) {
        state = NodeState.completed;
      } else if (!firstIncompleteAssigned) {
        state = NodeState.current;
      } else {
        state = NodeState.available;
      }

      items.add(LessonItem(
        stageIndex: i,
        checkpointIndex: c,
        state: state,
        isLabelAnchor: c == anchorIndex,
      ));

      if (items.whereType<LessonItem>().length % 5 == 0) {
        items.add(MilestoneItem(unlocked: state == NodeState.completed));
      }
    }

    if (stageHasIncompleteUnit) firstIncompleteAssigned = true;
  }

  return items;
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd FlutterSpell_Game
flutter test test/models/stage_data_test.dart
```

Expected: PASS (9 tests: 2 legacy-degradation + 5 multi-checkpoint + 1 label-anchor loop covering 5 cases + the milestone-mid-lesson test — exact count depends on how the test runner reports the `for` loop inside the label-anchor test, which is one `test()` block asserting 5 cases, not 5 separate tests).

- [ ] **Step 5: Commit**

```bash
git add FlutterSpell_Game/lib/models/stage_data.dart FlutterSpell_Game/test/models/stage_data_test.dart
git commit -m "feat: flatten lessons into per-checkpoint path units in buildPathItems"
```

---

## Task 2: Render checkpoint units as full nodes in `journey_path.dart`

**Files:**
- Modify: `FlutterSpell_Game/lib/widgets/journey_path.dart` (full-file replacement)
- Modify: `FlutterSpell_Game/test/widgets/journey_path_test.dart` (full-file replacement)

This task depends on Task 1 being complete (`LessonItem` must already have `.stageIndex`/`.checkpointIndex`/`.state`/`.isLabelAnchor` for this file to compile against it).

- [ ] **Step 1: Replace the test file**

Replace the entire contents of `FlutterSpell_Game/test/widgets/journey_path_test.dart` with:

```dart
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
  List<StageData>? stages,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: JourneyPath(
          stages: stages ?? _stages(),
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

  testWidgets(
      'a multi-checkpoint lesson renders one node per checkpoint with distinct states',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (_) {}, stages: stages);

    // checkpoint 0 done (check), checkpoint 1 current (fire), checkpoint 2
    // not yet reached (lock) - three distinct full-size nodes, not one node
    // with a caption.
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('🔥'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsOneWidget);
  });

  testWidgets(
      'tapping a not-yet-reached checkpoint shows a hint instead of navigating',
      (tester) async {
    int? selected;
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (n) => selected = n, stages: stages);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();

    expect(find.text('Clear checkpoint 2 first!'), findsOneWidget);
    expect(selected, isNull);
  });

  testWidgets(
      'tapping a checkpoint node in a fully locked lesson still offers Unlock Anyway',
      (tester) async {
    int? selected;
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.0,
        stars: 0,
        isLocked: true,
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (n) => selected = n, stages: stages);

    // All three checkpoint nodes render locked; tapping any of them is a
    // whole-lesson lock, not a "checkpoint not reached" hint.
    expect(find.byIcon(Icons.lock), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.lock).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('UNLOCK ANYWAY'), findsOneWidget);
    expect(find.textContaining('Clear checkpoint'), findsNothing);

    await tester.tap(find.text('UNLOCK ANYWAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selected, 1);
  });

  testWidgets(
      'title, date, and star row appear once per lesson, not once per checkpoint',
      (tester) async {
    final stages = [
      StageData(
        stageNumber: 1,
        title: 'Week 1',
        progress: 0.4,
        stars: 1,
        isLocked: false,
        spellDate: '七月十四日',
        checkpointIndex: 1,
        checkpointCount: 3,
      ),
    ];
    await _pump(tester, (_) {}, stages: stages);

    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('七月十四日'), findsOneWidget);
  });
}
```

Note what's deliberately gone from the old test file: the two progress-ring tests (`a partially-mastered current node shows a progress ring...`, `a locked node shows no progress ring...`) — the ring is removed by design, not a bug to preserve. The two `Checkpoint N/M` caption tests are also gone — the caption is superseded by the node chain itself. The three tap-handling tests at the top are carried over **unchanged**, verbatim, from the old file — they exercise the legacy 1-checkpoint-per-lesson degenerate case and must keep passing exactly as before, proving the flattening didn't regress today's behavior.

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd FlutterSpell_Game
flutter test test/widgets/journey_path_test.dart
```

Expected: FAIL — the new multi-checkpoint/tap-hint/label-anchor tests won't pass against the current implementation (which still renders one node per lesson with a text caption and a ring), and depending on how far Task 1's changes propagated, this may also fail to compile until Step 3 below is done (the current `journey_path.dart` calls `deriveNodeState`, which no longer exists after Task 1).

- [ ] **Step 3: Replace the implementation**

Replace the entire contents of `FlutterSpell_Game/lib/widgets/journey_path.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/stage_data.dart';
import 'package:spell_game/widgets/celebration.dart';

/// A vertical, zig-zagging Duolingo-style map of checkpoint nodes connected
/// by a dashed trail, with a milestone treasure chest every 5 checkpoint
/// nodes. Shared by every kingdom's lesson-selection screen so node styling,
/// star ratings, and the lock dialog stay consistent across kingdoms.
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

  void _handleNodeTap(LessonItem item) {
    if (item.state != NodeState.locked) {
      widget.onSelectLesson(widget.stages[item.stageIndex].stageNumber);
      return;
    }
    if (widget.stages[item.stageIndex].isLocked) {
      _showUnlockDialog(item.stageIndex);
      return;
    }
    // The whole lesson is unlocked, but this checkpoint hasn't been reached
    // yet - there's no "skip a checkpoint" feature, just tell the user why
    // this node looks locked.
    final currentCheckpoint = widget.stages[item.stageIndex].checkpointIndex + 1;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Clear checkpoint $currentCheckpoint first!')),
    );
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

    final lessonItem = item as LessonItem;
    final stage = widget.stages[lessonItem.stageIndex];
    final state = lessonItem.state;

    // _LessonNode's outer footprint is always _nodeSize + 10 (matches the
    // fixed bounding box every node reports, regardless of state) so
    // Positioned offsets computed here stay centered on `center`.
    const outerSize = _nodeSize + 10;

    final labelWidgets = <Widget>[];
    if (lessonItem.isLabelAnchor) {
      if (stage.stars > 0) {
        labelWidgets.add(
          Positioned(
            top: center.dy - _nodeSize / 2 - 22,
            left: (center.dx - 40).clamp(0, width - 80),
            width: 80,
            child:
                _StarRow(stars: stage.stars, dimmed: state == NodeState.locked),
          ),
        );
      }
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
            ],
          ),
        ),
      );
    }

    return [
      Positioned(
        left: center.dx - outerSize / 2,
        top: center.dy - outerSize / 2,
        child: _LessonNode(
          state: state,
          pulse: _pulseController,
          onTap: () => _handleNodeTap(lessonItem),
        ),
      ),
      ...labelWidgets,
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

    // Keep the node's outer footprint state-invariant (size + 10, matching
    // the old ring-reserving box) so `Positioned` offsets computed by the
    // caller stay centered on `center` for every state.
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd FlutterSpell_Game
flutter test test/widgets/journey_path_test.dart
```

Expected: PASS (7 tests: 3 carried-over tap tests + 4 new).

- [ ] **Step 5: Run the full frontend test suite and static analysis**

```bash
cd FlutterSpell_Game
flutter analyze
flutter test
```

Expected: `flutter analyze` shows no new issues. `flutter test` passes with no regressions beyond this codebase's known pre-existing baseline (7 unrelated failures: `game_provider_test.dart`'s `restoreSession` test, 6 in `home_screen_test.dart`).

- [ ] **Step 6: Commit**

```bash
git add FlutterSpell_Game/lib/widgets/journey_path.dart FlutterSpell_Game/test/widgets/journey_path_test.dart
git commit -m "feat: render each checkpoint as a full path node, dropping the ring and text caption"
```

---

## Final Verification (manual, after both tasks)

- [ ] Start the app (`restart-dev.bat`), open a kingdom's World Map, and confirm a lesson with multiple checkpoints renders as a chain of full-size nodes (not a single node with a caption), matching the reviewed mockup.
- [ ] Confirm the title/star row/date appear exactly once per lesson, positioned near the middle of that lesson's node cluster.
- [ ] Tap a checkpoint node you haven't reached yet (within an unlocked lesson) and confirm you get the "Clear checkpoint N first!" message, not the lesson-locked dialog, and that it doesn't navigate anywhere.
- [ ] Tap a node in a fully locked lesson and confirm the existing "This lesson is designed to build on previous skills... Unlock Anyway?" dialog still appears.
- [ ] Confirm the treasure chest appears after every 5th checkpoint node along the path, not necessarily aligned to a lesson boundary.
- [ ] Confirm a lesson with no checkpoint data (or `checkpointCount <= 1`) still renders as a single node, identical to before this change.
