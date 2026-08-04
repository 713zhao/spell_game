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

    test('an out-of-range checkpointIndex degrades to every unit locked, not every unit completed', () {
      final stages = [
        StageData(
          stageNumber: 1,
          title: 'Week 1',
          progress: 0.4,
          stars: 1,
          isLocked: false,
          checkpointIndex: 99, // out of range for checkpointCount: 3
          checkpointCount: 3,
        ),
      ];

      final units = buildPathItems(stages).whereType<LessonItem>().toList();

      expect(units.length, 3);
      expect(
        units.every((u) => u.state == NodeState.locked),
        isTrue,
        reason: 'an invalid checkpointIndex should never render every '
            'checkpoint as completed',
      );
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
