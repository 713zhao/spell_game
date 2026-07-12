import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/cards/daily_goal_card.dart';
import '../widgets/cards/level_card.dart';
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

  String _getDifficultyString(int difficulty) {
    switch (difficulty) {
      case 1:
        return 'Easy';
      case 2:
        return 'Medium';
      case 3:
        return 'Hard';
      default:
        return 'Medium';
    }
  }

  String _getLevelIcon(int levelId) {
    final icons = ['🎯', '🌟', '🔥', '⚡', '💎', '👑', '🚀', '🎪'];
    return icons[levelId % icons.length];
  }

  bool _isLevelUnlocked(int levelId, int levelsCompleted) {
    // A level is unlocked if it's the first level or if the previous level has been completed
    return levelId <= levelsCompleted + 1;
  }

  int _getCompletedLessonsToday(GameProvider provider) {
    // Get from user stats - represents total levels completed
    return provider.userStats?.levelsCompleted ?? 0;
  }

  int _getDailyGoalTarget() {
    // Daily goal configuration - can be made configurable via API in future
    const int dailyGoalTarget = 5;
    return dailyGoalTarget;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.levels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          final completedToday = _getCompletedLessonsToday(provider);
          final dailyGoalTarget = _getDailyGoalTarget();

          return CustomScrollView(
            slivers: [
              // Header with dog mascot and greeting
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: DuolingoSpacing.lg,
                    vertical: DuolingoSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dog mascot with bounce animation
                      Center(
                        child: ScaleTransition(
                          scale: _mascotAnimation,
                          child: const Text(
                            '🦮',
                            style: TextStyle(fontSize: 80),
                          ),
                        ),
                      ),
                      SizedBox(height: DuolingoSpacing.lg),

                      // Greeting message
                      Text(
                        'Let\'s Learn!',
                        style: DuolingoTextStyles.pageTitle.copyWith(
                          color: DuolingoColors.primaryGreen,
                        ),
                      ),
                      SizedBox(height: DuolingoSpacing.sm),

                      // Progress indicator
                      Text(
                        completedToday >= dailyGoalTarget
                            ? '🎉 Daily goal reached!'
                            : '$completedToday lessons completed today',
                        style: DuolingoTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),

              // Stats cards row (Streak + Points)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: StatCard(
                          icon: '🔥',
                          label: 'Streak',
                          value: '${provider.userStats?.currentStreak ?? 0} days',
                        ),
                      ),
                      SizedBox(width: DuolingoSpacing.lg),
                      Expanded(
                        child: StatCard(
                          icon: '⭐',
                          label: 'Points',
                          value: '${provider.userStats?.totalPoints ?? 0} XP',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: DuolingoSpacing.xl)),

              // Daily goal card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
                  child: DailyGoalCard(
                    completed: completedToday,
                    total: dailyGoalTarget,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: DuolingoSpacing.xl)),

              // Lessons section title
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
                  child: Text(
                    'LESSONS',
                    style: DuolingoTextStyles.sectionTitle,
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: DuolingoSpacing.md)),

              // Levels list
              provider.levels.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            EdgeInsets.all(DuolingoSpacing.xl),
                        child: Center(
                          child: Text(
                            'No lessons available yet',
                            style: DuolingoTextStyles.body,
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final level = provider.levels[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: DuolingoSpacing.lg,
                              vertical: DuolingoSpacing.md,
                            ),
                            child: LevelCard(
                              icon: _getLevelIcon(level.id),
                              name: level.name,
                              difficulty: _getDifficultyString(level.difficulty),
                              wordCount: level.words?.length ?? 0,
                              starsEarned: 0, // Would come from progress data
                              isLocked: !_isLevelUnlocked(level.id, provider.userStats?.levelsCompleted ?? 0),
                              isCompleted: false, // Would come from progress data
                              onPlayTap: () {
                                Navigator.of(context).pushNamed(
                                  '/study',
                                  arguments: level.id,
                                );
                              },
                              onReviewTap: () {
                                Navigator.of(context).pushNamed(
                                  '/study',
                                  arguments: level.id,
                                );
                              },
                            ),
                          );
                        },
                        childCount: provider.levels.length,
                      ),
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
            icon: Icon(Icons.book),
            label: 'Study',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.card_giftcard),
            label: 'Rewards',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
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
                Navigator.of(context).pushReplacementNamed('/study');
                break;
              case 2:
                Navigator.of(context).pushReplacementNamed('/rewards');
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/leaderboard');
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
