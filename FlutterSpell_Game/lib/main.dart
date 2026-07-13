import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home.dart';
import 'screens/study.dart';
import 'screens/rewards_shop.dart';
import 'screens/leaderboard.dart';
import 'screens/profile.dart';
import 'screens/progress_screen.dart';
import 'screens/world_map_screen.dart';
import 'screens/backpack_screen.dart';
import 'screens/treasure_island_screen.dart';
import 'screens/review_cave_screen.dart';
import 'screens/english_castle_screen.dart';
import 'screens/english_level_screen.dart';
import 'screens/chinese_kingdom_screen.dart';
import 'screens/chinese_lesson_screen.dart';
import 'screens/boss_arena_screen.dart';
import 'screens/boss_battle_screen.dart';
import 'screens/lesson_overview_screen.dart';

// Global GameProvider instance (singleton)
final gameProvider = GameProvider();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  gameProvider.init('ERIC');
  // Login to backend (fire-and-forget; screens react via notifyListeners)
  gameProvider.login('123');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameProvider>.value(
      value: gameProvider,
      child: MaterialApp(
        title: 'Spell Adventure',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(userName: 'ERIC'),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
            case '/home':
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(userName: 'ERIC'),
              );
            case '/world-map':
              return MaterialPageRoute(
                builder: (context) => const WorldMapScreen(),
              );
            case '/backpack':
              return MaterialPageRoute(
                builder: (context) => const BackpackScreen(),
              );
            case '/progress':
              return MaterialPageRoute(
                builder: (context) => const ProgressScreen(),
              );
            case '/profile':
              return MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              );
            case '/study':
              final levelId = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => StudyScreen(
                  levelId: levelId ?? 1,
                ),
              );
            case '/lesson-overview':
              final overviewLevelId = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => LessonOverviewScreen(
                  levelId: overviewLevelId ?? 1,
                ),
              );
            case '/rewards':
              return MaterialPageRoute(
                builder: (context) => const RewardsShopScreen(),
              );
            case '/leaderboard':
              return MaterialPageRoute(
                builder: (context) => const LeaderboardScreen(),
              );
            case '/treasure-island':
              return MaterialPageRoute(
                builder: (context) => const TreasureIslandScreen(),
              );
            case '/review-cave':
              return MaterialPageRoute(
                builder: (context) => const ReviewCaveScreen(),
              );
            case '/english-castle':
              return MaterialPageRoute(
                builder: (context) => const EnglishCastleScreen(),
              );
            case '/english-level':
              final stageNumber = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => EnglishLevelScreen(
                  stageNumber: stageNumber ?? 1,
                ),
              );
            case '/chinese-kingdom':
              return MaterialPageRoute(
                builder: (context) => const ChineseKingdomScreen(),
              );
            case '/chinese-lesson':
              final lessonNum = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => ChineseLessonScreen(
                  lessonNumber: lessonNum ?? 1,
                ),
              );
            case '/boss-arena':
              return MaterialPageRoute(
                builder: (context) => const BossArenaScreen(),
              );
            case '/boss-battle':
              final bossId = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => BossBattleScreen(
                  bossId: bossId ?? 1,
                ),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}
