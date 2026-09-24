/// checkpointIndex used for a lesson's review node (the node after its last
/// checkpoint). Same value the backend stores for it.
const int reviewNodeIndex = -1;

/// One lesson's data within a kingdom's journey path.
class StageData {
  final int stageNumber;
  final String title;
  final double progress; // 0.0 to 1.0 mastery (drives the stars)
  final int stars; // 0 to 3
  final bool isLocked; // the lesson is behind the track's current lesson
  final bool isCompleted; // every checkpoint and the review node are passed
  final String? spellDate; // raw text, e.g. "七月十四日"; null when unset
  final int checkpointIndex; // 0-based index of the current checkpoint
  final int checkpointCount; // total checkpoints; 0 means no words yet
  final List<bool> checkpointPassed; // per checkpoint
  final bool reviewPassed;
  final int reviewDueCount; // words due for spaced review today
  // Nodes the user chose to "unlock anyway": checkpoint indices, and
  // [reviewNodeIndex] for the review node.
  final Set<int> unlockedNodes;
  final String? labelBadge; // emoji for the lesson's label type; null hides it

  const StageData({
    required this.stageNumber,
    required this.title,
    required this.progress,
    required this.stars,
    required this.isLocked,
    this.isCompleted = false,
    this.spellDate,
    this.checkpointIndex = 0,
    this.checkpointCount = 0,
    this.checkpointPassed = const [],
    this.reviewPassed = false,
    this.reviewDueCount = 0,
    this.unlockedNodes = const {},
    this.labelBadge,
  });

  /// The lesson the user should be working on now in this track.
  bool get isCurrent => !isLocked && !isCompleted;

  bool isCheckpointPassed(int index) =>
      index >= 0 && index < checkpointPassed.length && checkpointPassed[index];
}

enum NodeState { completed, current, available, locked }

/// An entry in the winding path: either one checkpoint's node within a
/// lesson, or a milestone chest shown every 5 checkpoint nodes.
abstract class PathItem {}

/// One node on the path: a checkpoint, a lesson's review node, or - for a
/// lesson that isn't expanded - a single node standing for the whole lesson.
class LessonItem extends PathItem {
  final int stageIndex; // index into the stages list passed to buildPathItems
  // 0-based checkpoint within the lesson, [reviewNodeIndex] for its review
  // node, or 0 for a collapsed single-node lesson (see [isCollapsed]).
  final int checkpointIndex;
  final NodeState state;
  final bool isLabelAnchor; // the node carrying the lesson's title/stars
  // The node the "look here" pointer targets when this lesson is highlighted
  // - the next not-yet-passed node, which may be the review node (and so
  // may differ from [isLabelAnchor], which never lands on the review node
  // since it'd collide with the review node's own "Review" label).
  final bool isPointerAnchor;
  final bool isCollapsed;

  LessonItem({
    required this.stageIndex,
    required this.checkpointIndex,
    required this.state,
    required this.isLabelAnchor,
    this.isPointerAnchor = false,
    this.isCollapsed = false,
  });

  bool get isReview => checkpointIndex == reviewNodeIndex;
}

class MilestoneItem extends PathItem {
  final bool unlocked;
  // Stable across rebuilds (the Nth chest overall, 0-based) so the app can
  // remember which chests were already claimed - see treasure_claims.dart.
  final int index;
  MilestoneItem({required this.unlocked, required this.index});
}

/// Flattens the lessons into path nodes, in order.
///
/// Only the track's current lesson (and any lesson with a node the user
/// unlocked ahead) is expanded into its checkpoint nodes followed by a
/// review node. Every other lesson collapses to one node - done, or still
/// locked - so the path stays short.
///
/// Within an expanded lesson a node is completed once passed; the first
/// unpassed node of the current lesson is "current" (finishing it makes the
/// next one current automatically); a later node is "available" only if the
/// user unlocked it, otherwise locked.
///
/// A milestone chest follows every 5th node overall.
List<PathItem> buildPathItems(List<StageData> stages) {
  final items = <PathItem>[];
  var unitsSoFar = 0;
  var milestonesSoFar = 0;

  void addUnit(LessonItem item) {
    items.add(item);
    unitsSoFar++;
    if (unitsSoFar % 5 == 0) {
      items.add(
        MilestoneItem(
          unlocked: item.state == NodeState.completed,
          index: milestonesSoFar++,
        ),
      );
    }
  }

  for (var i = 0; i < stages.length; i++) {
    final stage = stages[i];
    final expanded =
        !stage.isCompleted &&
        stage.checkpointCount > 0 &&
        (stage.isCurrent || stage.unlockedNodes.isNotEmpty);

    if (!expanded) {
      addUnit(
        LessonItem(
          stageIndex: i,
          checkpointIndex: 0,
          state: stage.isCompleted
              ? NodeState.completed
              : stage.isLocked
              ? NodeState.locked
              : NodeState.current,
          isLabelAnchor: true,
          isPointerAnchor: true,
          isCollapsed: true,
        ),
      );
      continue;
    }

    final nodeCount = stage.checkpointCount + 1; // + the review node
    bool passedAt(int n) => n < stage.checkpointCount
        ? stage.isCheckpointPassed(n)
        : stage.reviewPassed;
    var firstUnpassed = 0;
    while (firstUnpassed < nodeCount && passedAt(firstUnpassed)) {
      firstUnpassed++;
    }
    // The lesson's label normally anchors to the midpoint of its checkpoint
    // nodes. But for the current lesson, or one the user unlocked their way
    // into, it instead tracks the node that's tappable right now - so the
    // named node isn't a locked one, and actually moves on as checkpoints
    // pass rather than sitting on whichever node happened to be the
    // midpoint (e.g. always node 0 for a 2-checkpoint lesson). It's capped
    // at the last checkpoint rather than the review node, since the review
    // node has its own "Review" label that the title/stars would collide
    // with; the "look here" pointer tracks separately below so it can still
    // reach the review node once every checkpoint's passed.
    final midpoint = (stage.checkpointCount - 1) ~/ 2;
    final active = stage.isCurrent || stage.unlockedNodes.isNotEmpty;
    final labelAnchor = active
        ? firstUnpassed.clamp(0, stage.checkpointCount - 1)
        : midpoint;
    final pointerAnchor = active ? firstUnpassed.clamp(0, nodeCount - 1) : -1;

    for (var n = 0; n < nodeCount; n++) {
      final index = n < stage.checkpointCount ? n : reviewNodeIndex;
      final NodeState state;
      if (passedAt(n)) {
        state = NodeState.completed;
      } else if (stage.isCurrent && n == firstUnpassed) {
        state = NodeState.current;
      } else if (stage.unlockedNodes.contains(index) ||
          (n == firstUnpassed && stage.unlockedNodes.isNotEmpty)) {
        // The lesson itself is still locked (otherwise it'd be isCurrent
        // above), but the user unlocked their way into it - once that
        // node's passed, the next one should open up the same way a
        // current lesson's would, instead of demanding another "unlock
        // anyway" tap for every single node.
        state = NodeState.available;
      } else {
        state = NodeState.locked;
      }
      addUnit(
        LessonItem(
          stageIndex: i,
          checkpointIndex: index,
          state: state,
          isLabelAnchor: n == labelAnchor,
          isPointerAnchor: n == pointerAnchor,
        ),
      );
    }
  }

  return items;
}
