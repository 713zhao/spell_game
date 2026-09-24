/// A single MOE curriculum character with its metadata for the "Chinese
/// Word Cards" flip-card feature (see SpellBackend's GET /moe-words).
class MoeCharacter {
  final int id;
  final String text;
  final String? pinyin;
  final String? meaning;
  final bool writeRequired;
  final int practicedCount;

  MoeCharacter({
    required this.id,
    required this.text,
    required this.pinyin,
    required this.meaning,
    required this.writeRequired,
    required this.practicedCount,
  });

  factory MoeCharacter.fromJson(Map<String, dynamic> json) => MoeCharacter(
        id: json['id'] as int,
        text: json['text'] as String,
        pinyin: json['pinyin'] as String?,
        meaning: json['meaning'] as String?,
        writeRequired: json['write_required'] == true,
        practicedCount: (json['practiced_count'] ?? 0) as int,
      );

  MoeCharacter copyWith({int? practicedCount}) => MoeCharacter(
        id: id,
        text: text,
        pinyin: pinyin,
        meaning: meaning,
        writeRequired: writeRequired,
        practicedCount: practicedCount ?? this.practicedCount,
      );
}

/// One MOE lesson (e.g. "第一课") with its ordered list of characters.
class MoeLesson {
  final String lessonKey;
  final String term; // "上" or "下"
  final String displayName;
  final List<MoeCharacter> characters;

  MoeLesson({
    required this.lessonKey,
    required this.term,
    required this.displayName,
    required this.characters,
  });

  factory MoeLesson.fromJson(Map<String, dynamic> json) => MoeLesson(
        lessonKey: json['lesson_key'] as String,
        term: json['term'] as String,
        displayName: json['display_name'] as String,
        characters: (json['characters'] as List)
            .map((c) => MoeCharacter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// The full response from GET /moe-words for a given grade.
class MoeWordCardsResult {
  final String grade;
  final bool supported;
  final List<MoeLesson> lessons;

  MoeWordCardsResult({
    required this.grade,
    required this.supported,
    required this.lessons,
  });

  factory MoeWordCardsResult.fromJson(Map<String, dynamic> json) =>
      MoeWordCardsResult(
        grade: json['grade'] as String,
        supported: json['supported'] == true,
        lessons: (json['lessons'] as List)
            .map((l) => MoeLesson.fromJson(l as Map<String, dynamic>))
            .toList(),
      );

  int get totalCharacters =>
      lessons.fold(0, (sum, l) => sum + l.characters.length);
}
