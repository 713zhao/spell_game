import 'package:json_annotation/json_annotation.dart';

part 'game_models.g.dart';

@JsonSerializable()
class Level {
  final int id;
  final String name;
  final int difficulty;
  final String? description;
  final List<Word>? words;

  Level({
    required this.id,
    required this.name,
    required this.difficulty,
    this.description,
    this.words,
  });

  factory Level.fromJson(Map<String, dynamic> json) => _$LevelFromJson(json);
  Map<String, dynamic> toJson() => _$LevelToJson(this);
}

/// A word from the user's study deck with spaced-repetition state.
/// Plain class (parsed manually from the /deck endpoint).
class DeckCard {
  final Word word;
  final int repetitions;
  final String status; // new | learning | review

  DeckCard({
    required this.word,
    required this.repetitions,
    required this.status,
  });
}

@JsonSerializable()
class Word {
  final int id;
  final String text;
  final String language;
  final String? backCard;
  final String? quiz;

  Word({
    required this.id,
    required this.text,
    required this.language,
    this.backCard,
    this.quiz,
  });

  factory Word.fromJson(Map<String, dynamic> json) => _$WordFromJson(json);
  Map<String, dynamic> toJson() => _$WordToJson(this);
}

@JsonSerializable()
class LevelProgress {
  final int levelId;
  final String status;
  final int stars;
  final int studyCount;

  LevelProgress({
    required this.levelId,
    required this.status,
    required this.stars,
    required this.studyCount,
  });

  factory LevelProgress.fromJson(Map<String, dynamic> json) =>
      _$LevelProgressFromJson(json);
  Map<String, dynamic> toJson() => _$LevelProgressToJson(this);
}

@JsonSerializable()
class Unlockable {
  final int id;
  final String type;
  final String name;
  final int pointsCost;
  final String rarity;
  final bool owned;
  final bool equipped;

  Unlockable({
    required this.id,
    required this.type,
    required this.name,
    required this.pointsCost,
    required this.rarity,
    required this.owned,
    required this.equipped,
  });

  factory Unlockable.fromJson(Map<String, dynamic> json) =>
      _$UnlockableFromJson(json);
  Map<String, dynamic> toJson() => _$UnlockableToJson(this);
}

@JsonSerializable()
class UserStats {
  final int totalPoints;
  final int currentStreak;
  final String? lastLogin;
  final int? bestStreak;
  final int? levelsCompleted;
  final double? accuracy;
  final int? level;
  final String? username;
  final String? grade;
  final String? equippedCosmetic;

  UserStats({
    required this.totalPoints,
    required this.currentStreak,
    this.lastLogin,
    this.bestStreak,
    this.levelsCompleted,
    this.accuracy,
    this.level,
    this.username,
    this.grade,
    this.equippedCosmetic,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) =>
      _$UserStatsFromJson(json);
  Map<String, dynamic> toJson() => _$UserStatsToJson(this);
}

@JsonSerializable()
class Challenge {
  final int id;
  final String status;
  final int levelId;
  final int? winnerId;
  final String? challengerName;
  final String? challengeeName;

  Challenge({
    required this.id,
    required this.status,
    required this.levelId,
    this.winnerId,
    this.challengerName,
    this.challengeeName,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}

/// One lesson entry from the backend's `/lessons/{user}` endpoint: a group
/// of teacher/MOE tags for the user's grade, with real word count and
/// mastery/star progress computed from ReviewState. Plain class (parsed
/// manually, like DeckCard).
class LessonSummary {
  final String lessonKey;
  final String displayName;
  final String labelType; // TEACHER | MOE
  final List<String> tags;
  final List<String> skills;
  final int wordCount;
  final double masteryPct;
  final int stars;
  final String status; // completed | current | locked
  final String? spellDate; // raw text, e.g. "七月十四日"; null when unset

  LessonSummary({
    required this.lessonKey,
    required this.displayName,
    required this.labelType,
    required this.tags,
    required this.skills,
    required this.wordCount,
    required this.masteryPct,
    required this.stars,
    required this.status,
    this.spellDate,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
        lessonKey: json['lesson_key'] as String,
        displayName: json['display_name'] as String,
        labelType: json['label_type'] as String? ?? 'TEACHER',
        tags: (json['tags'] as List).cast<String>(),
        skills: (json['skills'] as List).cast<String>(),
        wordCount: json['word_count'] as int,
        masteryPct: (json['mastery_pct'] as num).toDouble(),
        stars: json['stars'] as int,
        status: json['status'] as String,
        spellDate: json['spell_date'] as String?,
      );
}

@JsonSerializable()
class LeaderboardEntry {
  final int rank;
  final String userName;
  final int points;
  final String? medal;

  LeaderboardEntry({
    required this.rank,
    required this.userName,
    required this.points,
    this.medal,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
  Map<String, dynamic> toJson() => _$LeaderboardEntryToJson(this);
}
