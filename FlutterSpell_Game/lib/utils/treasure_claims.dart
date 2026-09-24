import 'package:shared_preferences/shared_preferences.dart';

String _prefsKey(String subject) => 'claimed_treasures_$subject';

/// Milestone chest indices (see [MilestoneItem.index]) the user already
/// tapped open in this subject's path - persisted locally so a chest only
/// ever pays out its reward once, instead of replaying the celebration
/// (and its XP/coin pop) on every tap.
Future<Set<int>> getClaimedTreasures(String subject) async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getStringList(_prefsKey(subject)) ?? const [])
      .map(int.tryParse)
      .whereType<int>()
      .toSet();
}

Future<void> addClaimedTreasure(String subject, int index) async {
  final prefs = await SharedPreferences.getInstance();
  final current = await getClaimedTreasures(subject);
  if (current.contains(index)) return;
  await prefs.setStringList(_prefsKey(subject), [
    ...current,
    index,
  ].map((e) => e.toString()).toList());
}
