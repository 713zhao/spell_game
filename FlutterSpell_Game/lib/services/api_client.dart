import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_models.dart';
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

  /// Fetch the user's study deck (their real assigned words) including
  /// spaced-repetition state used for adaptive difficulty. When [tags] is
  /// given, the deck is scoped to those tags (joined for the backend to
  /// split); a lesson spanning multiple tag variants (e.g. Chinese
  /// ::read + ::write) is passed as a multi-element list.
  Future<List<DeckCard>> getDeckCards({List<String>? tags, int limit = 10, int? checkpoint}) async {
    final tagParam = (tags != null && tags.isNotEmpty)
        ? '&tag=${Uri.encodeComponent(tags.join(","))}'
        : '';
    final checkpointParam = checkpoint != null ? '&checkpoint=$checkpoint' : '';
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/deck?limit=$limit$tagParam$checkpointParam'),
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

  /// List the user's grade-filtered lessons for a subject (EN or CN), built
  /// from teacher/MOE tags on the backend.
  Future<List<LessonSummary>> getLessons(String subject) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/lessons/$userName?subject=$subject'),
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
      final response = await http.get(
        Uri.parse('$_baseUrl/levels/$levelId'),
      );

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
        Uri.parse('$_baseUrl/unlockables/$unlockableId/redeem?user_name=$userName'),
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

  Future<UserStats> getUserStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/streaks/$userName'),
      );

      if (response.statusCode == 200) {
        return UserStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createChallenge(String challengeeName, int levelId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/create?challenger_name=$userName&challengee_name=$challengeeName&level_id=$levelId'),
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

  Future<List<LeaderboardEntry>> getLeaderboard({String filter = 'global'}) async {
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
        Uri.parse('$_baseUrl/challenges/$challengeId/accept?user_name=$userName'),
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

  Future<Map<String, dynamic>> completeChallenge(int challengeId, double accuracy) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/challenges/$challengeId/complete?user_name=$userName'),
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
