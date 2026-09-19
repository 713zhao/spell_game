import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
import '../providers/game_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late GameProvider gameProvider;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    gameProvider.addListener(_onGameProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.loadUserStats();
      gameProvider.loadDefeatedBosses();
      gameProvider.loadAchievements();
    });
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onGameProviderChanged);
    super.dispose();
  }

  void _onGameProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final stats = gameProvider.userStats;
    final xp = stats?.totalPoints ?? 0;
    // "Coins" and "Gems" are the same points balance as XP - there's no
    // separate coin/gem currency in the backend (see home.dart).
    final coins = stats?.totalPoints ?? 0;
    final gems = stats?.totalPoints ?? 0;
    final streak = stats?.currentStreak ?? 0;
    final levelsCompleted = stats?.levelsCompleted ?? 0;
    final bossesDefeated = gameProvider.defeatedBossIds.length;
    final achievements = gameProvider.achievements;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Progress', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        actions: const [AccountAvatarButton()],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Grid
              Text('Stats', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.md),
              GridView(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: DuolingoSpacing.md,
                  mainAxisSpacing: DuolingoSpacing.md,
                  childAspectRatio: 1.4,
                ),
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _StatCard('$xp', 'Total XP', DuolingoColors.rewardYellow),
                  _StatCard(
                    '$streak',
                    'Current Streak',
                    DuolingoColors.streakOrange,
                  ),
                  _StatCard(
                    '$coins',
                    'Total Coins',
                    DuolingoColors.primaryGreen,
                  ),
                  _StatCard('$gems', 'Total Gems', DuolingoColors.treasureGold),
                  _StatCard(
                    '$levelsCompleted',
                    'Levels Completed',
                    DuolingoColors.informationBlue,
                  ),
                  _StatCard(
                    '$bossesDefeated',
                    'Bosses Defeated',
                    DuolingoColors.mistakeRed,
                  ),
                ],
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Milestones
              Text('Milestones', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.md),
              for (final achievement in achievements)
                _MilestoneItem(
                  achievement['icon'] as String? ?? '🏁',
                  achievement['label'] as String? ?? '',
                  achievement['completed'] as bool? ?? false,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 3,
        type: BottomNavigationBarType.fixed,
        backgroundColor: DuolingoColors.backgroundWhite,
        selectedItemColor: DuolingoColors.primaryGreen,
        unselectedItemColor: DuolingoColors.navInactiveGray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.backpack),
            label: 'Backpack',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              Navigator.of(context).pushReplacementNamed('/');
              break;
            case 1:
              Navigator.of(context).pushReplacementNamed('/world-map');
              break;
            case 2:
              Navigator.of(context).pushReplacementNamed('/backpack');
              break;
            case 3:
              // Already on progress
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/profile');
              break;
          }
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: DuolingoTextStyles.pageTitle.copyWith(color: color),
          ),
          SizedBox(height: DuolingoSpacing.xs),
          Text(
            label,
            style: DuolingoTextStyles.label,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool completed;

  const _MilestoneItem(this.icon, this.label, this.completed);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: DuolingoSpacing.md),
      padding: EdgeInsets.all(DuolingoSpacing.md),
      decoration: BoxDecoration(
        color: completed
            ? DuolingoColors.primaryGreen.withOpacity(0.1)
            : Colors.grey[200],
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        border: Border(
          left: BorderSide(
            color: completed ? DuolingoColors.primaryGreen : Colors.grey,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 24)),
          SizedBox(width: DuolingoSpacing.md),
          Expanded(
            child: Text(
              label,
              style: DuolingoTextStyles.body.copyWith(
                color: completed ? DuolingoColors.darkText : Colors.grey[600],
                fontWeight: completed ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (completed)
            Text(
              '✓',
              style: TextStyle(
                color: DuolingoColors.primaryGreen,
                fontSize: 20,
              ),
            ),
        ],
      ),
    );
  }
}
