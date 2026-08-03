import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';

void main() {
  group('LessonSummary.fromJson checkpoint fields', () {
    test('parses checkpoint_index and checkpoint_count when present', () {
      final lesson = LessonSummary.fromJson({
        'lesson_key': 'Week1',
        'display_name': 'Week 1',
        'label_type': 'TEACHER',
        'tags': ['T::P1::EN::Week1'],
        'skills': [],
        'word_count': 12,
        'mastery_pct': 0.5,
        'stars': 2,
        'status': 'current',
        'checkpoint_index': 1,
        'checkpoint_count': 3,
      });

      expect(lesson.checkpointIndex, 1);
      expect(lesson.checkpointCount, 3);
    });

    test('defaults checkpoint fields from word_count when the backend omits them', () {
      final lesson = LessonSummary.fromJson({
        'lesson_key': 'Week1',
        'display_name': 'Week 1',
        'label_type': 'TEACHER',
        'tags': ['T::P1::EN::Week1'],
        'skills': [],
        'word_count': 12,
        'mastery_pct': 0.5,
        'stars': 2,
        'status': 'current',
      });

      expect(lesson.checkpointIndex, 0);
      expect(lesson.checkpointCount, 3); // ceil(12 / 5)
    });
  });
}
