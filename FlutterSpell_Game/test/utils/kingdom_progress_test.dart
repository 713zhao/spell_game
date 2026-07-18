import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/utils/kingdom_progress.dart';

LessonSummary _lesson({
  required String displayName,
  required String status,
  int stars = 0,
}) {
  return LessonSummary(
    lessonKey: displayName,
    displayName: displayName,
    labelType: 'TEACHER',
    tags: const [],
    skills: const [],
    wordCount: 8,
    masteryPct: 0.0,
    stars: stars,
    status: status,
  );
}

void main() {
  group('summarizeKingdomProgress', () {
    test('empty lesson list shows a "no lessons yet" fallback', () {
      final progress = summarizeKingdomProgress([]);

      expect(progress.completed, 0);
      expect(progress.total, 0);
      expect(progress.current, 'No lessons yet');
      expect(progress.stars, 0);
    });

    test('counts completed lessons and surfaces the current one', () {
      final lessons = [
        _lesson(displayName: 'Week 1', status: 'completed', stars: 3),
        _lesson(displayName: 'Week 2', status: 'completed', stars: 2),
        _lesson(displayName: 'Week 3', status: 'current', stars: 1),
        _lesson(displayName: 'Week 4', status: 'locked'),
      ];

      final progress = summarizeKingdomProgress(lessons);

      expect(progress.completed, 2);
      expect(progress.total, 4);
      expect(progress.current, 'Week 3');
      expect(progress.stars, 1);
    });

    test('when every lesson is completed, shows a finished message with full stars',
        () {
      final lessons = [
        _lesson(displayName: 'Week 1', status: 'completed', stars: 3),
        _lesson(displayName: 'Week 2', status: 'completed', stars: 3),
      ];

      final progress = summarizeKingdomProgress(lessons);

      expect(progress.completed, 2);
      expect(progress.total, 2);
      expect(progress.current, 'All lessons complete! 🎉');
      expect(progress.stars, 3);
    });

    test('a single not-yet-started lesson is the current one', () {
      final lessons = [
        _lesson(displayName: 'Week 1', status: 'current', stars: 0),
      ];

      final progress = summarizeKingdomProgress(lessons);

      expect(progress.completed, 0);
      expect(progress.total, 1);
      expect(progress.current, 'Week 1');
      expect(progress.stars, 0);
    });
  });
}
