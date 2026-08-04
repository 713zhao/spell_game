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
  var unitsSoFar = 0;

  for (var i = 0; i < stages.length; i++) {
    final stage = stages[i];
    final unitCount = stage.checkpointCount <= 1 ? 1 : stage.checkpointCount;
    final anchorIndex = (unitCount - 1) ~/ 2;
    final lessonDone = stage.progress >= 1.0;
    final stageHasIncompleteUnit = !stage.isLocked && !lessonDone;
    // Guard against an out-of-range checkpointIndex (shouldn't happen given
    // how the backend derives it, but not guaranteed by the type system).
    // A plain clamp into [0, unitCount - 1] would still leave every
    // checkpoint below the clamped value marked "completed", which is the
    // same misleading overshoot this guard exists to prevent - just capped
    // instead of unbounded. Falling back to an out-of-range sentinel (-1)
    // instead makes `c > effectiveCheckpointIndex` true for every valid `c`,
    // so the lesson degrades to "every unit not yet reached (locked)", per
    // the design spec's intended behavior.
    final isValidCheckpointIndex =
        stage.checkpointIndex >= 0 && stage.checkpointIndex < unitCount;
    final effectiveCheckpointIndex =
        isValidCheckpointIndex ? stage.checkpointIndex : -1;

    for (var c = 0; c < unitCount; c++) {
      final locked =
          stage.isLocked || (!lessonDone && c > effectiveCheckpointIndex);
      final done =
          lessonDone || (!stage.isLocked && c < effectiveCheckpointIndex);

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

      unitsSoFar++;
      if (unitsSoFar % 5 == 0) {
        items.add(MilestoneItem(unlocked: state == NodeState.completed));
      }
    }

    if (stageHasIncompleteUnit) firstIncompleteAssigned = true;
  }

  return items;
}
