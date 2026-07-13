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
