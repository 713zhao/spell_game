import 'package:flutter_test/flutter_test.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/utils/exercise_content_parser.dart';

void main() {
  group('parseSentenceBlank', () {
    test('blanks the target word out of the Example sentence', () {
      final word = Word(
        id: 1,
        text: 'photosynthesis',
        language: 'english',
        backCard: 'memorization tip: tip text\n'
            'Explanation: some explanation\n'
            'Similar words: a, b, c\n'
            'Example: Photosynthesis is essential for life on Earth.',
      );

      final blanked = parseSentenceBlank(word);

      expect(blanked, '_____ is essential for life on Earth.');
    });

    test('returns null when there is no back_card', () {
      final word = Word(id: 1, text: 'apple', language: 'english');
      expect(parseSentenceBlank(word), isNull);
    });

    test('returns null when there is no Example line', () {
      final word = Word(
        id: 1,
        text: 'apple',
        language: 'english',
        backCard: 'memorization tip: tip text\nExplanation: some text',
      );
      expect(parseSentenceBlank(word), isNull);
    });

    test('returns null when the word is not present in the example sentence', () {
      final word = Word(
        id: 1,
        text: 'apple',
        language: 'english',
        backCard: 'Example: Oranges are tasty too.',
      );
      expect(parseSentenceBlank(word), isNull);
    });
  });

  group('parseQuiz', () {
    test('parses a well-formed quiz JSON string', () {
      final quizData = parseQuiz(
        '{"question":"What does it mean?","options":["A","B","C"],"correct":1}',
      );

      expect(quizData, isNotNull);
      expect(quizData!.question, 'What does it mean?');
      expect(quizData.options, ['A', 'B', 'C']);
      expect(quizData.correctOption, 'B');
    });

    test('returns null for null input', () {
      expect(parseQuiz(null), isNull);
    });

    test('returns null for malformed JSON', () {
      expect(parseQuiz('not json'), isNull);
    });

    test('returns null when correct index is out of range', () {
      expect(
        parseQuiz('{"question":"Q","options":["A","B"],"correct":5}'),
        isNull,
      );
    });
  });
}
