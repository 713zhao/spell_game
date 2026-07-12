import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home.dart';
import 'screens/rewards_shop.dart';

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
        routes: {
          '/level-select': (context) => const LevelSelectScreen(),
          '/study': (context) => const StudyScreen(),
          '/rewards': (context) => const RewardsShopScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
          '/profile': (context) => const ProfileScreen(),
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

class StudyScreen extends StatelessWidget {
  const StudyScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Study')));
  }
}


class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Leaderboard')));
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Profile')));
  }
}
