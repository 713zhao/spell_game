import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_models.dart';
import '../models/moe_word_models.dart';
import '../config/api_config.dart';

class ApiClient {
  static const String _baseUrl = ApiConfig.baseUrl;
  final String userName;

  ApiClient({required this.userName});

  /// Verify user password against backend. Returns true when credentials match.
  Future<bool> verifyPassword(String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userName/verify-password'),
      body: {'password': password},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['verified'] == true;
    }
    return false;
  }

  /// Record a login event for streak tracking.
  Future<void> logLogin() async {
    await http.post(Uri.parse('$_baseUrl/users/$userName/login'));
  }

  /// Creates a new account. Only [name] is required - the backend defaults
  /// everything else. Throws with the backend's error detail on failure,
  /// notably a 409 when the username is already taken.
  Future<void> createUser({
    required String name,
    String? password,
    String? grade,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        if (password != null && password.isNotEmpty) 'password': password,
        if (grade != null && grade.isNotEmpty) 'grade': grade,
      }),
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      String detail = 'Failed to create account';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }

  /// Fetch the full account profile (age, grade, school, email, phone) -
  /// separate from [getUserStats], which only has game-relevant fields.
  Future<Map<String, dynamic>> getUserProfile() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/profile'),
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw Exception('Invalid response format from getUserProfile');
    }
    throw Exception('Failed to load profile');
  }

  /// Update account profile fields. Only include keys that should change -
  /// the backend leaves omitted fields untouched.
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/users/$userName/profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode != 200) {
      String detail = 'Failed to update profile';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
  }

  /// Resolves this user's numeric DB id via [getUserProfile] - SpellBackend's
  /// /settings/{user_id} endpoint keys off the numeric id, unlike most other
  /// routes in this client which key off [userName].
  Future<int> _getUserId() async {
    final profile = await getUserProfile();
    final id = profile['id'];
    if (id is int) return id;
    if (id is num) return id.toInt();
    throw Exception('User id missing from profile response');
  }

  /// Fetch this user's UserSetting row (study_words_source, num_study_words,
  /// spell_repeat_count). See SpellBackend's GET /settings/{user_id}. Falls
  /// back to the backend's own defaults if no row exists yet (404).
  Future<Map<String, dynamic>> getUserSettings() async {
    final userId = await _getUserId();
    final response = await http.get(Uri.parse('$_baseUrl/settings/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    if (response.statusCode == 404) {
      return {
        'user_id': userId,
        'study_words_source': 'ALL_TAGS',
        'num_study_words': 10,
        'spell_repeat_count': 1,
      };
    }
    throw Exception('Failed to load settings');
  }

  /// Update this user's settings. Only pass the fields that should change;
  /// the backend's POST /settings/{user_id} takes them as query params and
  /// leaves omitted ones untouched. Returns the updated row.
  Future<Map<String, dynamic>> updateUserSettings({
    String? studyWordsSource,
    int? numStudyWords,
    int? spellRepeatCount,
  }) async {
    final userId = await _getUserId();
    final params = <String, String>{
      if (studyWordsSource != null) 'study_words_source': studyWordsSource,
      if (numStudyWords != null) 'num_study_words': numStudyWords.toString(),
      if (spellRepeatCount != null)
        'spell_repeat_count': spellRepeatCount.toString(),
    };
    final uri = Uri.parse(
      '$_baseUrl/settings/$userId',
    ).replace(queryParameters: params);
    final response = await http.post(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update settings');
  }

  /// Whether Home's daily treasure chest is still claimable today (UTC).
  Future<bool> getChestStatus() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/chest'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load chest status');
    }
    final decoded = jsonDecode(response.body);
    return decoded['available'] == true;
  }

  /// Claims today's treasure chest, granting points server-side. Throws on
  /// failure, notably a 400 if it was already claimed today (e.g. a second
  /// tap that raced ahead of the UI disabling itself).
  Future<Map<String, dynamic>> claimChest() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userName/chest/claim'),
    );
    if (response.statusCode != 200) {
      String detail = 'Failed to claim chest';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Every achievement's unlock state (Progress screen's Milestones list).
  Future<List<Map<String, dynamic>>> getAchievements() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/achievements'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load achievements');
    }
    final decoded = jsonDecode(response.body);
    return (decoded['achievements'] as List).cast<Map<String, dynamic>>();
  }

  /// Boss ids this user has ever defeated (Boss Arena).
  Future<List<int>> getDefeatedBosses() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/bosses'),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load defeated bosses');
    }
    final decoded = jsonDecode(response.body);
    return (decoded['defeated'] as List).cast<int>();
  }

  /// Records a boss win server-side. Idempotent per boss - only the first
  /// defeat grants points; repeats report `first_time: false` and no
  /// additional reward.
  Future<Map<String, dynamic>> defeatBoss(int bossId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userName/bosses/$bossId/defeat'),
    );
    if (response.statusCode != 200) {
      String detail = 'Failed to record boss defeat';
      try {
        detail = jsonDecode(response.body)['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Why a vocab quiz's correct answer is right, as one kid-friendly
  /// sentence (AI-generated once per word, then cached server-side - see
  /// SpellBackend's `/words/{id}/quiz-explanation`). Returns null on any
  /// failure (network error, word has no quiz, backend AI outage, etc.) -
  /// callers should fall back to just naming the correct option instead of
  /// blocking on this.
  Future<String?> getQuizExplanation(int wordId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/words/$wordId/quiz-explanation'),
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      final explanation = decoded is Map ? decoded['explanation'] : null;
      return explanation is String && explanation.isNotEmpty
          ? explanation
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch the user's study deck (their real assigned words) including
  /// spaced-repetition state used for adaptive difficulty. When [tags] is
  /// given, the deck is scoped to those tags (joined for the backend to
  /// split); a lesson spanning multiple tag variants (e.g. Chinese
  /// ::read + ::write) is passed as a multi-element list.
  Future<List<DeckCard>> getDeckCards({
    List<String>? tags,
    int limit = 10,
    int? checkpoint,
    bool review = false,
  }) async {
    final tagParam = (tags != null && tags.isNotEmpty)
        ? '&tag=${Uri.encodeComponent(tags.join(","))}'
        : '';
    final checkpointParam = checkpoint != null ? '&checkpoint=$checkpoint' : '';
    final modeParam = review ? '&mode=review' : '';
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/users/$userName/deck?limit=$limit$tagParam$checkpointParam$modeParam',
      ),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final cards = json['cards'] as List;
      return cards.map((c) {
        final state = c['state'] as Map<String, dynamic>? ?? {};
        return DeckCard(
          word: Word(
            id: c['word_id'] as int,
            text: c['text'] as String,
            language: (c['language'] ?? 'english') as String,
            backCard: c['back_card'] as String?,
            quiz: c['quiz'] as String?,
          ),
          repetitions: (state['repetitions'] ?? 0) as int,
          status: (state['status'] ?? 'new') as String,
        );
      }).toList();
    }
    throw Exception('Failed to load deck');
  }

  /// All words (any user, global) that have quiz data - most words in the
  /// database don't, so a given user's own deck may have none even when
  /// the deck itself isn't empty. Used by Word Snake's Knowledge Stones as
  /// a fallback so there's always vocab-quiz content available to play.
  Future<List<Word>> getQuizWordPool({int limit = 100}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/words/quiz-pool?limit=$limit'),
    );
    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List;
      return list
          .map(
            (w) => Word(
              id: w['word_id'] as int,
              text: w['text'] as String,
              language: (w['language'] ?? 'english') as String,
              backCard: w['back_card'] as String?,
              quiz: w['quiz'] as String?,
            ),
          )
          .toList();
    }
    throw Exception('Failed to load quiz word pool');
  }

  /// List the user's grade-filtered lessons for a subject (EN or CN), built
  /// from teacher/MOE tags on the backend.
  Future<List<LessonSummary>> getLessons(
    String subject, {
    String? labelType,
  }) async {
    final labelParam = labelType != null
        ? '&label_type=${Uri.encodeComponent(labelType)}'
        : '';
    final response = await http.get(
      Uri.parse('$_baseUrl/lessons/$userName?subject=$subject$labelParam'),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final lessons = json['lessons'] as List;
      return lessons
          .map((l) => LessonSummary.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load lessons');
  }

  /// Record that the user completed a study session on a lesson's
  /// checkpoint ([checkpointIndex] >= 0) or its review node (-1), which is
  /// what advances the journey path.
  Future<void> markCheckpointPassed(
    String subject,
    String lessonKey,
    int checkpointIndex,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/lessons/$userName/checkpoint-pass'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'subject': subject,
        'lesson_key': lessonKey,
        'checkpoint_index': checkpointIndex,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to record checkpoint');
    }
  }

  /// Submit a single word's review outcome (SM-2 quality 0/1/3/5) so the
  /// backend's spaced-repetition state — and therefore lesson mastery/stars
  /// on next fetch — advances.
  Future<void> submitReview(int wordId, int quality) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/$userName/review'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'word_id': wordId, 'quality': quality}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to submit review');
    }
  }

  Future<List<Level>> getLevelList() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/levels/users/$userName'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final levelsData = json['levels'] as List;
        return levelsData
            .map((l) => Level.fromJson(l as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load levels');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Level> getLevelDetails(int levelId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/levels/$levelId'));

      if (response.statusCode == 200) {
        return Level.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load level');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeLevelStudy(
    int levelId,
    double accuracy,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/levels/users/$userName/progress/$levelId/complete?accuracy=$accuracy',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to complete level');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Unlockable>> getUnlockables() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/unlockables/?user_name=$userName'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final available = json['available'] as List;
        return available
            .map((u) => Unlockable.fromJson(u as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load unlockables');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> redeemUnlockable(int unlockableId) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/unlockables/$unlockableId/redeem?user_name=$userName',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to redeem unlockable');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Game store catalog: coins balance plus each game's unlock status.
  Future<Map<String, dynamic>> getMiniGames() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/minigames/?user_name=$userName'),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'games': (json['games'] as List)
            .map((g) => MiniGame.fromJson(g as Map<String, dynamic>))
            .toList(),
        'coins': json['coins'] as int,
      };
    }
    throw Exception('Failed to load games');
  }

  /// Spends coins to permanently unlock a game. Throws with the backend's
  /// message on failure (e.g. "Not enough coins").
  Future<Map<String, dynamic>> unlockMiniGame(int gameId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/minigames/$gameId/unlock?user_name=$userName'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractDetail(response.body, 'Failed to unlock game'));
  }

  /// Spends the per-play cost and returns the game's embeddable URL.
  Future<Map<String, dynamic>> playMiniGame(int gameId) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/minigames/$gameId/play?user_name=$userName'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractDetail(response.body, 'Failed to start game'));
  }

  /// Where this user stands against the daily combined minigame play time
  /// cap: {usedSeconds, limitSeconds, remainingSeconds, locked}.
  Future<Map<String, dynamic>> getPlaytimeStatus() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/minigames/playtime?user_name=$userName'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(_extractDetail(response.body, 'Failed to load play time'));
  }

  /// Reports elapsed play seconds since the last heartbeat, accumulating
  /// toward the daily cap. Returns the same status shape as
  /// [getPlaytimeStatus] so the caller can lock the game out mid-session.
  Future<Map<String, dynamic>> sendPlaytimeHeartbeat(int seconds) async {
    final response = await http.post(
      Uri.parse(
        '$_baseUrl/minigames/playtime/heartbeat?user_name=$userName&seconds=$seconds',
      ),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception(
      _extractDetail(response.body, 'Failed to report play time'),
    );
  }

  /// MOE curriculum word cards for [grade] (currently only "P1" is
  /// backed by real data; other grades come back with `supported: false`
  /// and an empty lesson list, not an error, so the caller can show a
  /// "coming soon" state). Includes this user's practiced_count per
  /// character.
  Future<MoeWordCardsResult> getMoeWords({String grade = 'P1'}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/moe-words?grade=$grade&user_name=$userName'),
    );
    if (response.statusCode == 200) {
      return MoeWordCardsResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Failed to load MOE word cards');
  }

  String _extractDetail(String body, String fallback) {
    try {
      return jsonDecode(body)['detail'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<UserStats> getUserStats() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/streaks/$userName'));

      if (response.statusCode == 200) {
        return UserStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createChallenge(
    String challengeeName,
    int levelId,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/challenges/create?challenger_name=$userName&challengee_name=$challengeeName&level_id=$levelId',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create challenge');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<LeaderboardEntry>> getLeaderboard({
    String filter = 'global',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/leaderboard/?filter=$filter'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final entries = json['entries'] as List;
        return entries
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load leaderboard');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Challenge>> getChallenges() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/challenges/?user_name=$userName'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final challenges = json['challenges'] as List;
        return challenges
            .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load challenges');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptChallenge(int challengeId) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/challenges/$challengeId/accept?user_name=$userName',
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to accept challenge');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeChallenge(
    int challengeId,
    double accuracy,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/challenges/$challengeId/complete?user_name=$userName',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accuracy': accuracy}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to complete challenge');
      }
    } catch (e) {
      rethrow;
    }
  }
}
