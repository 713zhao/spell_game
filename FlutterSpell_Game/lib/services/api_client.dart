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

  /// Fetch the user's study deck (their real assigned words).
  Future<List<Word>> getDeckWords() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/users/$userName/deck'),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final cards = json['cards'] as List;
      return cards
          .map((c) => Word(
                id: c['word_id'] as int,
                text: c['text'] as String,
                language: (c['language'] ?? 'english') as String,
              ))
          .toList();
    }
    throw Exception('Failed to load deck');
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
