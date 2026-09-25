import 'package:shared_preferences/shared_preferences.dart';

String _prefsKey(String subject) => 'practice_sessions_$subject';

/// Free-practice sessions completed per lesson (lessonKey -> count), for a
/// completed lesson that hasn't hit 3 stars yet - drives the "Session N"
/// label on its practice node (see stage_data.dart's buildPathItems) so
/// repeated practice reads as forward progress instead of a static node
/// that never changes.
Future<Map<String, int>> getPracticeSessionCounts(String subject) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_prefsKey(subject)) ?? const [];
  final out = <String, int>{};
  for (final entry in raw) {
    final i = entry.lastIndexOf('#');
    if (i < 0) continue;
    final count = int.tryParse(entry.substring(i + 1));
    if (count == null) continue;
    out[entry.substring(0, i)] = count;
  }
  return out;
}

Future<void> incrementPracticeSessionCount(
  String subject,
  String lessonKey,
) async {
  final prefs = await SharedPreferences.getInstance();
  final counts = await getPracticeSessionCounts(subject);
  counts[lessonKey] = (counts[lessonKey] ?? 0) + 1;
  await prefs.setStringList(_prefsKey(subject), [
    for (final entry in counts.entries) '${entry.key}#${entry.value}',
  ]);
}
