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
