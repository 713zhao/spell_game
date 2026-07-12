import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/cards/journey_card.dart';
import '../widgets/cards/treasure_chest_card.dart';
import '../widgets/cards/boss_battle_card.dart';
import '../widgets/cards/stat_card.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GameProvider>();
      provider.init(widget.userName);
      provider.loadLevels();
      provider.loadUserStats();
    });
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
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.userStats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          // Mock data if API not ready yet
          final streak = provider.userStats?.currentStreak ?? 8;
          final xp = provider.userStats?.totalPoints ?? 250;
          final coins = 85;
          final gems = 12;
          final userName = 'Alex';

          // Check if weak words exist for boss battle
          final hasWeakWords = provider.userStats?.accuracy != null &&
              provider.userStats!.accuracy! < 0.8;
          final weakWords = ['because', 'beautiful', 'responsible'];

          return CustomScrollView(
            slivers: [
              // Header Section (No Scroll)
              SliverAppBar(
                backgroundColor: DuolingoColors.backgroundWhite,
                elevation: 0,
                floating: false,
                pinned: true,
                toolbarHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: Padding(
                    padding: EdgeInsets.only(
                      left: DuolingoSpacing.lg,
                      right: DuolingoSpacing.lg,
                      top: DuolingoSpacing.xl,
                      bottom: DuolingoSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Animated mascot
                        Center(
                          child: ScaleTransition(
                            scale: _mascotAnimation,
                            child: const Text(
                              '🏰',
                              style: TextStyle(fontSize: 72),
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
                            Expanded(
                              child: StatCard(
                                icon: '⭐',
                                label: 'XP',
                                value: '$xp',
                              ),
                            ),
                            SizedBox(width: DuolingoSpacing.md),
                            Expanded(
                              child: StatCard(
                                icon: '💰',
                                label: 'Coins',
                                value: '$coins',
                              ),
                            ),
                            SizedBox(width: DuolingoSpacing.md),
                            Expanded(
                              child: StatCard(
                                icon: '💎',
                                label: 'Gems',
                                value: '$gems',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Scrollable Content Section
              SliverToBoxAdapter(
                child: SizedBox(height: DuolingoSpacing.lg),
              ),

              // English Kingdom Card
              SliverToBoxAdapter(
                child: JourneyCard(
                  kingdom: 'english',
                  icon: '🏰',
                  label: 'English Kingdom',
                  current: 'Stage 5',
                  completed: 8,
                  total: 10,
                  stars: 2,
                  onTap: () {
                    Navigator.of(context).pushNamed('/study');
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: DuolingoSpacing.lg),
              ),

              // Chinese Kingdom Card
              SliverToBoxAdapter(
                child: JourneyCard(
                  kingdom: 'chinese',
                  icon: '🐉',
                  label: 'Chinese Kingdom',
                  current: 'Forest Stage 7',
                  completed: 7,
                  total: 10,
                  stars: 2,
                  onTap: () {
                    Navigator.of(context).pushNamed('/study');
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: DuolingoSpacing.lg),
              ),

              // Daily Treasure Chest Card
              SliverToBoxAdapter(
                child: TreasureChestCard(
                  isAvailable: true,
                  reward: '+50 XP, +20 Coins',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Treasure opened!')),
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: DuolingoSpacing.lg),
              ),

              // Boss Battle Card (if weak words exist)
              if (hasWeakWords)
                SliverToBoxAdapter(
                  child: BossBattleCard(
                    bossName: 'Vocabulary Champion',
                    weakWordsCount: weakWords.length,
                    weakWords: weakWords,
                    onTap: () {
                      Navigator.of(context).pushNamed('/study');
                    },
                  ),
                ),

              if (hasWeakWords)
                SliverToBoxAdapter(
                  child: SizedBox(height: DuolingoSpacing.lg),
                ),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(height: DuolingoSpacing.xxl),
              ),
            ],
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
                Navigator.of(context).pushReplacementNamed('/leaderboard');
                break;
              case 2:
                Navigator.of(context).pushReplacementNamed('/rewards');
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/study');
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
