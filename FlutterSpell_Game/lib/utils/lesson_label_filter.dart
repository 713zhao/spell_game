import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/models/game_models.dart';

/// Helpers for filtering a kingdom's lessons by `labelType` (TEACHER, MOE,
/// ...). The filtered track itself comes from the backend
/// (`/lessons/{user}?label_type=`), where each type has its own lock order.

String _prefsKey(String subject) => 'lesson_label_filter_$subject';

/// The saved filter for [subject], or null for "All".
Future<String?> getLabelFilter(String subject) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefsKey(subject));
}

Future<void> setLabelFilter(String subject, String? labelType) async {
  final prefs = await SharedPreferences.getInstance();
  if (labelType == null) {
    await prefs.remove(_prefsKey(subject));
  } else {
    await prefs.setString(_prefsKey(subject), labelType);
  }
}

/// Distinct label types in [lessons], in first-seen order.
List<String> labelTypesOf(List<LessonSummary> lessons) =>
    {for (final l in lessons) l.labelType}.toList();

String labelTypeEmoji(String labelType) {
  switch (labelType) {
    case 'TEACHER':
      return '🏫';
    case 'MOE':
      return '📘';
    default:
      return '🏷️';
  }
}

String labelTypeName(String labelType) {
  switch (labelType) {
    case 'TEACHER':
      return 'Teacher';
    case 'MOE':
      return 'MOE';
    default:
      return labelType.isEmpty
          ? labelType
          : labelType[0] + labelType.substring(1).toLowerCase();
  }
}
