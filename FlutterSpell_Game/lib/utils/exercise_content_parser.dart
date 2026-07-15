import 'dart:convert';
import '../models/game_models.dart';

/// Pulls the `Example: <sentence>` line out of a word's `back_card` text
/// and blanks out the target word, for the Sentence Fill-in exercise.
/// Returns null when there's no back_card, no Example line, or the word
/// doesn't actually appear in that sentence — callers should fall back to
/// a different exercise type in every null case.
String? parseSentenceBlank(Word word) {
  final backCard = word.backCard;
  if (backCard == null) return null;

  final exampleMatch = RegExp(
    r'Example:\s*(.+)$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(backCard);
  if (exampleMatch == null) return null;

  final sentence = exampleMatch.group(1)!.trim();
  final wordPattern = RegExp(
    r'\b' + RegExp.escape(word.text) + r'\b',
    caseSensitive: false,
  );
  if (!wordPattern.hasMatch(sentence)) return null;

  return sentence.replaceFirst(wordPattern, '_____');
}

/// A parsed Meaning Matching quiz question for one word.
class QuizData {
  final String question;
  final List<String> options;
  final String correctOption;

  QuizData(this.question, this.options, this.correctOption);
}

/// Parses a word's raw `quiz` JSON string (`{"question","options","correct"}`)
/// into [QuizData]. Returns null for missing/malformed data or an
/// out-of-range correct index — callers should skip the Meaning Matching
/// exercise for that word in every null case.
QuizData? parseQuiz(String? quizJson) {
  if (quizJson == null) return null;
  try {
    final data = jsonDecode(quizJson) as Map<String, dynamic>;
    final options = (data['options'] as List).cast<String>();
    final correctIdx = data['correct'] as int;
    if (correctIdx < 0 || correctIdx >= options.length) return null;
    return QuizData(data['question'] as String, options, options[correctIdx]);
  } catch (_) {
    return null;
  }
}
