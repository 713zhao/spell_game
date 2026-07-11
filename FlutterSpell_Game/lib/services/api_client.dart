import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_models.dart';

class ApiClient {
  static const String _baseUrl = 'http://localhost:8000';
  final String userName;

  ApiClient({required this.userName});

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
      print('Error loading levels: $e');
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
      print('Error loading level: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeLevelStudy(
    int levelId,
    double accuracy,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/levels/users/$userName/progress/$levelId/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'accuracy': accuracy}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to complete level');
      }
    } catch (e) {
      print('Error completing level: $e');
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
      print('Error loading unlockables: $e');
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
      print('Error redeeming: $e');
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
      print('Error loading stats: $e');
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
      print('Error creating challenge: $e');
      rethrow;
    }
  }
}
