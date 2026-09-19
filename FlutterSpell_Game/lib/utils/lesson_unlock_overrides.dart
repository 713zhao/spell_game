import 'package:shared_preferences/shared_preferences.dart';

String _prefsKey(String subject) => 'unlocked_nodes_$subject';

String _nodeKey(String lessonKey, int checkpointIndex) =>
    '$lessonKey#$checkpointIndex';

/// Journey-path nodes (a lesson's checkpoint, or its review node at
/// the review node's index (-1)) the user chose to "unlock anyway" ahead of the normal
/// progression (see JourneyPath's unlock dialog). Persisted locally so the
/// path doesn't ask again for a node already unlocked this way - the
/// backend's own progress only advances when a checkpoint is actually
/// completed, so skipping ahead never changes what it reports.
Future<Set<String>> getUnlockedNodes(String subject) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_prefsKey(subject)) ?? const []).toSet();
}

Future<void> addUnlockedNode(
  String subject,
  String lessonKey,
  int checkpointIndex,
) async {
  final prefs = await SharedPreferences.getInstance();
  final current = prefs.getStringList(_prefsKey(subject)) ?? const [];
  final key = _nodeKey(lessonKey, checkpointIndex);
  if (current.contains(key)) return;
  await prefs.setStringList(_prefsKey(subject), [...current, key]);
}

/// The checkpoint indices of [lessonKey] present in [unlocked] (the set
/// returned by [getUnlockedNodes]).
Set<int> unlockedIndicesFor(Set<String> unlocked, String lessonKey) {
  final prefix = '$lessonKey#';
  return unlocked
      .where((k) => k.startsWith(prefix))
      .map((k) => int.tryParse(k.substring(prefix.length)))
      .whereType<int>()
      .toSet();
}
