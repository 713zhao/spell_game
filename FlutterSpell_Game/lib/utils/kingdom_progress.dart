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
KingdomProgress summarizeKingdomProgress(List<LessonSummary> lessons) {
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

  return KingdomProgress(
    completed: completed,
    total: lessons.length,
    current: currentLesson?.displayName ?? 'All lessons complete! 🎉',
    stars: currentLesson?.stars ?? 3,
  );
}
