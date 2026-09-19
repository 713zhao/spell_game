import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/stage_data.dart';

StageData _stage({
  int number = 1,
  bool locked = false,
  bool completed = false,
  int count = 3,
  List<bool>? passed,
  bool reviewPassed = false,
  Set<int> unlocked = const {},
}) => StageData(
  stageNumber: number,
  title: 'Stage $number',
  progress: 0,
  stars: 0,
  isLocked: locked,
  isCompleted: completed,
  checkpointCount: count,
  checkpointPassed: passed ?? List.filled(count, completed),
  reviewPassed: reviewPassed || completed,
  unlockedNodes: unlocked,
);

List<LessonItem> _nodes(List<StageData> stages) =>
    buildPathItems(stages).whereType<LessonItem>().toList();

void main() {
  group('the current lesson', () {
    test('expands into its checkpoints plus a review node', () {
      final nodes = _nodes([_stage(count: 3)]);

      expect(nodes.map((n) => n.checkpointIndex), [0, 1, 2, reviewNodeIndex]);
      expect(nodes.last.isReview, isTrue);
      expect(nodes.every((n) => !n.isCollapsed), isTrue);
    });

    test(
      'passed points are completed, the first unpassed is current, the rest locked',
      () {
        final nodes = _nodes([
          _stage(count: 3, passed: [true, false, false]),
        ]);

        expect(nodes.map((n) => n.state), [
          NodeState.completed,
          NodeState.current,
          NodeState.locked,
          NodeState.locked,
        ]);
      },
    );

    test('passing the current point makes the next one current', () {
      final nodes = _nodes([
        _stage(count: 3, passed: [true, true, false]),
      ]);

      expect(nodes[1].state, NodeState.completed);
      expect(nodes[2].state, NodeState.current);
    });

    test('the review node becomes current once every point is passed', () {
      final nodes = _nodes([
        _stage(count: 2, passed: [true, true]),
      ]);

      expect(nodes.last.isReview, isTrue);
      expect(nodes.last.state, NodeState.current);
    });

    test('a point the user unlocked ahead is available, not current', () {
      final nodes = _nodes([
        _stage(count: 4, passed: [false, false, false, false], unlocked: {2}),
      ]);

      expect(nodes[0].state, NodeState.current);
      expect(nodes[1].state, NodeState.locked);
      expect(nodes[2].state, NodeState.available);
    });

    test('an unlocked review node is available', () {
      final nodes = _nodes([
        _stage(count: 2, unlocked: {reviewNodeIndex}),
      ]);

      expect(nodes.last.state, NodeState.available);
    });
  });

  group('other lessons', () {
    test('a completed lesson collapses to one completed node', () {
      final nodes = _nodes([_stage(completed: true, count: 4)]);

      expect(nodes, hasLength(1));
      expect(nodes.single.isCollapsed, isTrue);
      expect(nodes.single.state, NodeState.completed);
    });

    test('a locked lesson collapses to one locked node', () {
      final nodes = _nodes([_stage(locked: true, count: 4)]);

      expect(nodes, hasLength(1));
      expect(nodes.single.isCollapsed, isTrue);
      expect(nodes.single.state, NodeState.locked);
    });

    test('a locked lesson expands once the user unlocks one of its nodes', () {
      final nodes = _nodes([
        _stage(locked: true, count: 3, unlocked: {0}),
      ]);

      expect(nodes, hasLength(4));
      expect(nodes[0].state, NodeState.available);
      expect(nodes.skip(1).every((n) => n.state == NodeState.locked), isTrue);
      expect(nodes.any((n) => n.state == NodeState.current), isFalse);
    });

    test('a lesson with no words stays a single node', () {
      final nodes = _nodes([_stage(count: 0)]);

      expect(nodes, hasLength(1));
      expect(nodes.single.isCollapsed, isTrue);
      expect(nodes.single.state, NodeState.current);
    });

    test('the track reads done, current expanded, then locked', () {
      final nodes = _nodes([
        _stage(number: 1, completed: true),
        _stage(number: 2, count: 2),
        _stage(number: 3, locked: true),
      ]);

      // 1 collapsed + (2 points + review) + 1 collapsed
      expect(nodes, hasLength(5));
      expect(nodes.map((n) => n.stageIndex), [0, 1, 1, 1, 2]);
    });
  });

  group('label anchor', () {
    test('sits on the middle checkpoint of a lesson not yet started', () {
      for (final count in [1, 2, 3, 4, 5, 8]) {
        final nodes = _nodes([
          _stage(locked: true, count: count, unlocked: {0}),
        ]);
        final anchors = [
          for (var i = 0; i < nodes.length; i++)
            if (nodes[i].isLabelAnchor) i,
        ];
        expect(anchors, [(count - 1) ~/ 2], reason: 'count=$count');
      }
    });

    test('never lands past the current point of the current lesson', () {
      final nodes = _nodes([_stage(count: 5)]);
      final anchor = nodes.indexWhere((n) => n.isLabelAnchor);

      expect(nodes[anchor].state, isNot(NodeState.locked));
    });
  });

  group('milestones', () {
    test('one chest follows every 5th node, counting all nodes', () {
      // 12 collapsed lessons -> chests after node 5 and node 10.
      final stages = List.generate(
        12,
        (i) => _stage(number: i + 1, completed: i < 5, locked: i >= 5),
      );

      final items = buildPathItems(stages);

      expect(items, hasLength(14));
      expect(items[5], isA<MilestoneItem>());
      expect((items[5] as MilestoneItem).unlocked, isTrue);
      expect(items[11], isA<MilestoneItem>());
      expect((items[11] as MilestoneItem).unlocked, isFalse);
    });
  });
}
