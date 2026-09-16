import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/game_models.dart';

String _prefsKey(String subject) => 'last_lesson_$subject';

Future<String?> getLastLessonKey(String subject) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefsKey(subject));
}

Future<void> setLastLessonKey(String subject, String lessonKey) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey(subject), lessonKey);
}

/// Decides which lesson (if any) a kingdom's word map should scroll to and
/// highlight on entry, so the user can pick up where they left off with a
/// single tap instead of hunting through the path - it does not navigate
/// anywhere itself.
///
/// - If a lesson was opened before, that's the default - unless a
///   different lesson is now the upcoming (next-scheduled) one, in which
///   case the user is asked first whether to switch to it to prepare
///   instead of jumping straight back into the old lesson.
/// - If no lesson has been opened yet for this subject, but an upcoming
///   lesson is known, the user is asked whether to jump to it to prepare.
///
/// Returns null when there's nothing to auto-open: no lesson has ever been
/// opened and no upcoming lesson is known, or the user declined to jump to
/// the upcoming lesson with no prior lesson to fall back to.
Future<LessonSummary?> resolveDefaultLesson({
  required BuildContext context,
  required List<LessonSummary> lessons,
  required String subject,
}) async {
  final lastKey = await getLastLessonKey(subject);

  LessonSummary? lastLesson;
  LessonSummary? upcoming;
  for (final l in lessons) {
    if (lastKey != null && l.lessonKey == lastKey) lastLesson = l;
    if (l.isUpcoming) upcoming = l;
  }

  if (lastLesson == null) {
    if (upcoming == null) return null;
    if (!context.mounted) return null;
    final jump = await askGoToUpcomingLesson(context, upcoming);
    return jump == true ? upcoming : null;
  }

  if (upcoming == null || upcoming.lessonKey == lastLesson.lessonKey) {
    return lastLesson;
  }

  if (!context.mounted) return lastLesson;
  final goUpcoming = await askGoToUpcomingLesson(context, upcoming);
  return goUpcoming == true ? upcoming : lastLesson;
}

/// Asks the user whether to switch to `upcoming` (the next-scheduled
/// lesson) to prepare for it. Shared by the word map screens (switching
/// their default/highlighted lesson) and Home (switching which lesson its
/// Kingdom card shows as "current"), so the prompt reads the same wherever
/// it appears.
Future<bool?> askGoToUpcomingLesson(
  BuildContext context,
  LessonSummary upcoming,
) {
  final dateSuffix =
      upcoming.spellDate != null && upcoming.spellDate!.isNotEmpty
          ? ' (${upcoming.spellDate})'
          : '';
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusDialog),
      ),
      title: const Text('📅 Upcoming lesson'),
      content: Text(
        'Your next scheduled lesson is "${upcoming.displayName}"$dateSuffix.\n\n'
        'Want to switch to it to prepare?',
        style: DuolingoTextStyles.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'NOT NOW',
            style: DuolingoTextStyles.label
                .copyWith(color: DuolingoColors.bodyText),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'GO TO UPCOMING LESSON',
            style: DuolingoTextStyles.label.copyWith(
              color: DuolingoColors.informationBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
