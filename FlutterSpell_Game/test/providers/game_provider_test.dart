import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spell_game/models/game_models.dart';
import 'package:spell_game/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GameProvider session management', () {
    test('restoreSession sets isLoggedIn and persists last_user + recent_users',
        () async {
      SharedPreferences.setMockInitialValues({});
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.restoreSession('ERIC');

      expect(provider.isLoggedIn, true);
      expect(provider.userName, 'ERIC');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_user'), 'ERIC');
      expect(prefs.getStringList('recent_users'), ['ERIC']);
    });

    test('restoreSession moves an already-recent user to the front without duplicating',
        () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['HELLEN', 'ERIC'],
      });
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.restoreSession('ERIC');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_users'), ['ERIC', 'HELLEN']);
    });

    test('recent_users is capped at 5, dropping the oldest', () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['A', 'B', 'C', 'D', 'E'],
      });
      final provider = GameProvider();
      provider.init('F');

      await provider.restoreSession('F');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recent_users'), ['F', 'A', 'B', 'C', 'D']);
    });

    test('loadRecentUsers populates recentUsers from storage', () async {
      SharedPreferences.setMockInitialValues({
        'recent_users': ['ERIC', 'HELLEN'],
      });
      final provider = GameProvider();
      provider.init('ERIC');

      await provider.loadRecentUsers();

      expect(provider.recentUsers, ['ERIC', 'HELLEN']);
    });

    test('logout clears session and cached data but keeps recent_users',
        () async {
      SharedPreferences.setMockInitialValues({
        'last_user': 'ERIC',
        'recent_users': ['ERIC'],
      });
      final provider = GameProvider();
      provider.init('ERIC');
      provider.isLoggedIn = true;
      provider.userStats = UserStats(totalPoints: 100, currentStreak: 5);
      provider.errorMessage = 'stale error';

      await provider.logout();

      expect(provider.isLoggedIn, false);
      expect(provider.userStats, isNull);
      expect(provider.errorMessage, isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_user'), isNull);
      expect(prefs.getStringList('recent_users'), ['ERIC']);
    });
  });
}
