import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_provider.dart';
import 'screens/home.dart';
import 'screens/study.dart';
import 'screens/rewards_shop.dart';
import 'screens/leaderboard.dart';
import 'screens/profile.dart';
import 'screens/progress_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = GameProvider();
            provider.init('alice');
            return provider;
          },
        ),
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
            case '/':
              return MaterialPageRoute(
                builder: (context) => const HomeScreen(userName: 'alice'),
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
            case '/progress':
              return MaterialPageRoute(
                builder: (context) => const ProgressScreen(),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}
