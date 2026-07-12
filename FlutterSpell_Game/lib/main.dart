import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home.dart';
import 'screens/study.dart';
import 'screens/rewards_shop.dart';
import 'screens/leaderboard.dart';
import 'screens/profile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: MaterialApp(
        title: 'Spell Adventure',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const HomeScreen(userName: 'alice'),
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/level-select':
              return MaterialPageRoute(
                builder: (context) => const LevelSelectScreen(),
              );
            case '/study':
              final levelId = settings.arguments as int?;
              return MaterialPageRoute(
                builder: (context) => StudyScreen(
                  levelId: levelId ?? 1,
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
            case '/profile':
              return MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}

// Placeholder screens
class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Level Select')));
  }
}
