import '../models/game_models.dart';

/// Aggregated Kingdom summary shown on Home's JourneyCard: how many
/// lessons are done, which one is next, and its star rating.
class KingdomProgress {
  final int completed;
  final int total;
  final String current;
  final int stars;

  const KingdomProgress({
    required this.completed,
    required this.total,
    required this.current,
    required this.stars,
  });
}

/// Summarizes a subject's lesson list for Home's Kingdom card: how many
/// lessons are completed, the display name of the one currently in
/// progress, and its star rating. Falls back to a friendly message when
/// there's nothing assigned yet, or everything's already finished.
///
/// [displayOverride], when set, is shown instead of the mastery-progress
/// "current" lesson - used to keep this card in sync with whichever lesson
/// the user last opened from the kingdom's word map (e.g. after agreeing to
/// switch to the upcoming lesson there), even though its own mastery status
/// hasn't changed.
KingdomProgress summarizeKingdomProgress(
  List<LessonSummary> lessons, {
  LessonSummary? displayOverride,
}) {
  if (lessons.isEmpty) {
    return const KingdomProgress(
      completed: 0,
      total: 0,
      current: 'No lessons yet',
      stars: 0,
    );
  }

  final completed = lessons.where((l) => l.status == 'completed').length;

  LessonSummary? currentLesson;
  for (final lesson in lessons) {
    if (lesson.status == 'current') {
      currentLesson = lesson;
      break;
    }
  }

  final displayLesson = displayOverride ?? currentLesson;

  return KingdomProgress(
    completed: completed,
    total: lessons.length,
    current: displayLesson?.displayName ?? 'All lessons complete! 🎉',
    stars: displayLesson?.stars ?? 3,
  );
}
