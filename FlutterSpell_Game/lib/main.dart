import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/auth_gate.dart';
import 'screens/home.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
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
import 'screens/chinese_kingdom_screen.dart';
import 'screens/boss_arena_screen.dart';
import 'screens/boss_battle_screen.dart';
import 'screens/lesson_overview_screen.dart';

// Global GameProvider instance (singleton)
final gameProvider = GameProvider();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const AuthGate(),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/':
            case '/home':
              return MaterialPageRoute(
                builder: (context) => HomeScreen(userName: gameProvider.userName),
              );
            case '/login':
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            case '/signup':
              return MaterialPageRoute(
                builder: (context) => const SignupScreen(),
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
              // Lesson selection passes a StudySessionArgs; a few shortcuts
              // (Boss Battle weak-word review, Leaderboard, Rewards Shop)
              // still push '/study' with no arguments for a full-deck
              // practice session.
              final rawArgs = settings.arguments;
              final studyArgs = rawArgs is StudySessionArgs
                  ? rawArgs
                  : const StudySessionArgs(
                      tags: [],
                      lessonKey: 'practice',
                      displayName: 'Quick Practice',
                      subject: 'EN',
                    );
              return MaterialPageRoute(
                builder: (context) => StudyScreen(args: studyArgs),
              );
            case '/lesson-overview':
              final overviewArgs = settings.arguments as LessonOverviewArgs;
              return MaterialPageRoute(
                builder: (context) => LessonOverviewScreen(args: overviewArgs),
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
            case '/chinese-kingdom':
              return MaterialPageRoute(
                builder: (context) => const ChineseKingdomScreen(),
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
