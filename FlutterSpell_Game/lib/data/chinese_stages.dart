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
