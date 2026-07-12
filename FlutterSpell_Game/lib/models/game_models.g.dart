// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Level _$LevelFromJson(Map<String, dynamic> json) => Level(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  difficulty: (json['difficulty'] as num).toInt(),
  description: json['description'] as String?,
  words: (json['words'] as List<dynamic>?)
      ?.map((e) => Word.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$LevelToJson(Level instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'difficulty': instance.difficulty,
  'description': instance.description,
  'words': instance.words,
};

Word _$WordFromJson(Map<String, dynamic> json) => Word(
  id: (json['id'] as num).toInt(),
  text: json['text'] as String,
  language: json['language'] as String,
);

Map<String, dynamic> _$WordToJson(Word instance) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'language': instance.language,
};

LevelProgress _$LevelProgressFromJson(Map<String, dynamic> json) =>
    LevelProgress(
      levelId: (json['levelId'] as num).toInt(),
      status: json['status'] as String,
      stars: (json['stars'] as num).toInt(),
      studyCount: (json['studyCount'] as num).toInt(),
    );

Map<String, dynamic> _$LevelProgressToJson(LevelProgress instance) =>
    <String, dynamic>{
      'levelId': instance.levelId,
      'status': instance.status,
      'stars': instance.stars,
      'studyCount': instance.studyCount,
    };

Unlockable _$UnlockableFromJson(Map<String, dynamic> json) => Unlockable(
  id: (json['id'] as num).toInt(),
  type: json['type'] as String,
  name: json['name'] as String,
  pointsCost: (json['pointsCost'] as num).toInt(),
  rarity: json['rarity'] as String,
  owned: json['owned'] as bool,
  equipped: json['equipped'] as bool,
);

Map<String, dynamic> _$UnlockableToJson(Unlockable instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'name': instance.name,
      'pointsCost': instance.pointsCost,
      'rarity': instance.rarity,
      'owned': instance.owned,
      'equipped': instance.equipped,
    };

UserStats _$UserStatsFromJson(Map<String, dynamic> json) => UserStats(
  totalPoints: (json['totalPoints'] as num).toInt(),
  currentStreak: (json['currentStreak'] as num).toInt(),
  lastLogin: json['lastLogin'] as String?,
  bestStreak: (json['bestStreak'] as num?)?.toInt(),
  levelsCompleted: (json['levelsCompleted'] as num?)?.toInt(),
  accuracy: (json['accuracy'] as num?)?.toDouble(),
  level: (json['level'] as num?)?.toInt(),
  username: json['username'] as String?,
  grade: json['grade'] as String?,
  equippedCosmetic: json['equippedCosmetic'] as String?,
);

Map<String, dynamic> _$UserStatsToJson(UserStats instance) => <String, dynamic>{
  'totalPoints': instance.totalPoints,
  'currentStreak': instance.currentStreak,
  'lastLogin': instance.lastLogin,
  'bestStreak': instance.bestStreak,
  'levelsCompleted': instance.levelsCompleted,
  'accuracy': instance.accuracy,
  'level': instance.level,
  'username': instance.username,
  'grade': instance.grade,
  'equippedCosmetic': instance.equippedCosmetic,
};

Challenge _$ChallengeFromJson(Map<String, dynamic> json) => Challenge(
  id: (json['id'] as num).toInt(),
  status: json['status'] as String,
  levelId: (json['levelId'] as num).toInt(),
  winnerId: (json['winnerId'] as num?)?.toInt(),
  challengerName: json['challengerName'] as String?,
  challengeeName: json['challengeeName'] as String?,
);

Map<String, dynamic> _$ChallengeToJson(Challenge instance) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'levelId': instance.levelId,
  'winnerId': instance.winnerId,
  'challengerName': instance.challengerName,
  'challengeeName': instance.challengeeName,
};

LeaderboardEntry _$LeaderboardEntryFromJson(Map<String, dynamic> json) =>
    LeaderboardEntry(
      rank: (json['rank'] as num).toInt(),
      userName: json['userName'] as String,
      points: (json['points'] as num).toInt(),
      medal: json['medal'] as String?,
    );

Map<String, dynamic> _$LeaderboardEntryToJson(LeaderboardEntry instance) =>
    <String, dynamic>{
      'rank': instance.rank,
      'userName': instance.userName,
      'points': instance.points,
      'medal': instance.medal,
    };
