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

@JsonSerializable()
class Word {
  final int id;
  final String text;
  final String language;

  Word({
    required this.id,
    required this.text,
    required this.language,
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

  UserStats({
    required this.totalPoints,
    required this.currentStreak,
    this.lastLogin,
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

  Challenge({
    required this.id,
    required this.status,
    required this.levelId,
    this.winnerId,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) =>
      _$ChallengeFromJson(json);
  Map<String, dynamic> toJson() => _$ChallengeToJson(this);
}
