import 'package:flutter/material.dart';
import '../design_system/design_system.dart';
import '../widgets/celebration.dart';
import '../main.dart' show gameProvider;
import '../widgets/cards/journey_card.dart';
import '../widgets/cards/treasure_chest_card.dart';
import '../widgets/cards/boss_battle_card.dart';
import '../widgets/cards/stat_card.dart';
import 'lesson_overview_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _mascotController;
  late Animation<double> _mascotAnimation;

  @override
  void initState() {
    super.initState();
    _initializeMascotAnimation();
    gameProvider.addListener(_onGameProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.loadLevels();
      gameProvider.loadUserStats();
    });
  }

  void _onGameProviderChanged() {
    if (mounted) setState(() {});
  }

  void _initializeMascotAnimation() {
    _mascotController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _mascotAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _mascotController, curve: Curves.elasticInOut),
    );
    _mascotController.forward();
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onGameProviderChanged);
    _mascotController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 18) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Adventure World', style: DuolingoTextStyles.pageTitle),
        centerTitle: true,
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
      ),
      body: Builder(
        builder: (context) {
          if (gameProvider.isLoading && gameProvider.userStats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (gameProvider.errorMessage != null) {
            return Center(child: Text('Error: ${gameProvider.errorMessage}'));
          }

          // Mock data if API not ready yet
          final streak = gameProvider.userStats?.currentStreak ?? 8;
          final xp = gameProvider.userStats?.totalPoints ?? 250;
          final coins = 85;
          final gems = 12;
          final userName = gameProvider.userName;

          // Check if weak words exist for boss battle
          final hasWeakWords = gameProvider.userStats?.accuracy != null &&
              gameProvider.userStats!.accuracy! < 0.8;
          final weakWords = ['because', 'beautiful', 'responsible'];

          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(DuolingoSpacing.lg),
              child: Column(
                children: [
                  // Animated mascot
                  Center(
                    child: ScaleTransition(
                      scale: _mascotAnimation,
                      child: const Text(
                        '🐕',
                        style: TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                  SizedBox(height: DuolingoSpacing.lg),

                  // Greeting + Streak
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $userName!',
                            style: DuolingoTextStyles.pageTitle.copyWith(
                              color: DuolingoColors.darkText,
                            ),
                          ),
                          SizedBox(height: DuolingoSpacing.xs),
                          Text(
                            'Continue your adventure...',
                            style: DuolingoTextStyles.body.copyWith(
                              color: DuolingoColors.bodyText,
                            ),
                          ),
                        ],
                      ),
                      // Streak Badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: DuolingoSpacing.md,
                          vertical: DuolingoSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: DuolingoColors.streakGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            DuolingoSpacing.radiusButton,
                          ),
                          boxShadow: DuolingoShadows.cardShadow,
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 20)),
                            SizedBox(width: DuolingoSpacing.xs),
                            Text(
                              '$streak',
                              style: DuolingoTextStyles.cardTitle.copyWith(
                                color: DuolingoColors.streakOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: DuolingoSpacing.lg),

                  // Quick stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      StatCard(
                        icon: '⭐',
                        label: 'XP',
                        value: '$xp',
                      ),
                      StatCard(
                        icon: '💰',
                        label: 'Coins',
                        value: '$coins',
                      ),
                      StatCard(
                        icon: '💎',
                        label: 'Gems',
                        value: '$gems',
                      ),
                    ],
                  ),

                  SizedBox(height: DuolingoSpacing.xl),

                  // English Kingdom Card
                  JourneyCard(
                    kingdom: 'english',
                    icon: '🏰',
                    label: 'English Kingdom',
                    current: 'Stage 5',
                    completed: 8,
                    total: 10,
                    stars: 2,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/lesson-overview',
                        arguments: const LessonOverviewArgs(
                          levelId: 1,
                          kingdom: KingdomTheme.english,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: DuolingoSpacing.lg),

                  // Chinese Kingdom Card
                  JourneyCard(
                    kingdom: 'chinese',
                    icon: '🐉',
                    label: 'Chinese Kingdom',
                    current: 'Forest Stage 7',
                    completed: 7,
                    total: 10,
                    stars: 2,
                    onTap: () {
                      Navigator.of(context).pushNamed('/chinese-kingdom');
                    },
                  ),
                  SizedBox(height: DuolingoSpacing.lg),

                  // Daily Treasure Chest Card
                  TreasureChestCard(
                    isAvailable: true,
                    reward: '+50 XP, +20 Coins',
                    onTap: () {
                      Celebration.reward(context);
                      Celebration.xpPop(context, 50);
                    },
                  ),
                  SizedBox(height: DuolingoSpacing.lg),

                  // Boss Battle Card (if weak words exist)
                  if (hasWeakWords)
                    BossBattleCard(
                      bossName: 'Vocabulary Champion',
                      weakWordsCount: weakWords.length,
                      weakWords: weakWords,
                      onTap: () {
                        Navigator.of(context).pushNamed('/study');
                      },
                    ),

                  if (hasWeakWords)
                    SizedBox(height: DuolingoSpacing.lg),

                  // Bottom padding (account for bottom nav bar ~56dp + extra spacing)
                  SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: DuolingoColors.backgroundWhite,
        selectedItemColor: DuolingoColors.primaryGreen,
        unselectedItemColor: DuolingoColors.neutralGray,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'World Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Backpack',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });

            switch (index) {
              case 0:
                // Already on home
                break;
              case 1:
                Navigator.of(context).pushReplacementNamed('/world-map');
                break;
              case 2:
                Navigator.of(context).pushReplacementNamed('/backpack');
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/progress');
                break;
              case 4:
                Navigator.of(context).pushReplacementNamed('/profile');
                break;
            }
          }
        },
      ),
    );
  }
}
