import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/utils/lesson_label_filter.dart';

LessonSummary _lesson(String key, String type) => LessonSummary(
  lessonKey: key,
  displayName: key,
  labelType: type,
  tags: const [],
  skills: const [],
  wordCount: 5,
  masteryPct: 0,
  stars: 0,
  status: 'current',
);

void main() {
  final lessons = [
    _lesson('a', 'TEACHER'),
    _lesson('b', 'MOE'),
    _lesson('c', 'TEACHER'),
  ];

  test('labelTypesOf returns distinct types in first-seen order', () {
    expect(labelTypesOf(lessons), ['TEACHER', 'MOE']);
  });
}
