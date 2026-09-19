import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
import '../providers/game_provider.dart';

// Levels-completed thresholds to unlock each boss - matches the
// "Unlock after Stage N" copy this screen already showed when a boss was
// locked, now backed by the real levelsCompleted count instead of the
// bosses just always being locked.
const int _phoenixUnlockStage = 10;
const int _viperUnlockStage = 15;

class BossArenaScreen extends StatefulWidget {
  const BossArenaScreen({Key? key}) : super(key: key);

  @override
  State<BossArenaScreen> createState() => _BossArenaScreenState();
}

class _BossArenaScreenState extends State<BossArenaScreen> {
  late GameProvider gameProvider;

  @override
  void initState() {
    super.initState();
    gameProvider = context.read<GameProvider>();
    gameProvider.addListener(_onGameProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      gameProvider.loadUserStats();
      gameProvider.loadDefeatedBosses();
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
    final levelsCompleted = gameProvider.userStats?.levelsCompleted ?? 0;
    final defeated = gameProvider.defeatedBossIds;
    final phoenixUnlocked = levelsCompleted >= _phoenixUnlockStage;
    final viperUnlocked = levelsCompleted >= _viperUnlockStage;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Boss Arena', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            children: [
              SizedBox(height: DuolingoSpacing.md),
              Text(
                'Challenge Legendary Bosses',
                style: DuolingoTextStyles.sectionTitle,
              ),
              SizedBox(height: DuolingoSpacing.xl),
              _BossCard(
                name: 'Spelling Dragon',
                difficulty: 'Easy',
                rewards: '100 XP, Rare Item',
                icon: '🐉',
                isUnlocked: true,
                defeated: defeated.contains(1),
                currentHp: 3,
                maxHp: 4,
                onTap: () {
                  Navigator.pushNamed(context, '/boss-battle', arguments: 1);
                },
              ),
              SizedBox(height: DuolingoSpacing.lg),
              _BossCard(
                name: 'Phoneme Phoenix',
                difficulty: 'Medium',
                rewards: '200 XP, Epic Item',
                icon: '🔥',
                isUnlocked: phoenixUnlocked,
                defeated: defeated.contains(2),
                onTap: phoenixUnlocked
                    ? () {
                        Navigator.pushNamed(
                          context,
                          '/boss-battle',
                          arguments: 2,
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Unlock after Stage $_phoenixUnlockStage',
                            ),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              SizedBox(height: DuolingoSpacing.lg),
              _BossCard(
                name: 'Vocab Viper',
                difficulty: 'Hard',
                rewards: '300 XP, Legendary Item',
                icon: '🐍',
                isUnlocked: viperUnlocked,
                defeated: defeated.contains(3),
                onTap: viperUnlocked
                    ? () {
                        Navigator.pushNamed(
                          context,
                          '/boss-battle',
                          arguments: 3,
                        );
                      }
                    : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Unlock after Stage $_viperUnlockStage',
                            ),
                            backgroundColor: Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              SizedBox(height: DuolingoSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _BossCard extends StatelessWidget {
  final String name;
  final String difficulty;
  final String rewards;
  final String icon;
  final bool isUnlocked;
  final bool defeated;
  final int? currentHp;
  final int? maxHp;
  final VoidCallback onTap;

  const _BossCard({
    required this.name,
    required this.difficulty,
    required this.rewards,
    required this.icon,
    required this.isUnlocked,
    required this.defeated,
    required this.onTap,
    this.currentHp,
    this.maxHp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: isUnlocked
              ? const LinearGradient(
                  colors: DuolingoColors.bossArenaGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    DuolingoColors.neutralGray,
                    DuolingoColors.secondaryButtonGray,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
          boxShadow: DuolingoShadows.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 48)),
                  SizedBox(width: DuolingoSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: DuolingoTextStyles.cardTitle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: DuolingoSpacing.xs),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: DuolingoSpacing.sm,
                            vertical: DuolingoSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(difficulty),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            difficulty,
                            style: DuolingoTextStyles.label.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (defeated)
                    Icon(Icons.check_circle, color: DuolingoColors.primaryGreen)
                  else if (isUnlocked)
                    Icon(Icons.lock_open, color: DuolingoColors.primaryGreen)
                  else
                    Icon(Icons.lock, color: DuolingoColors.neutralGray),
                ],
              ),
              if (isUnlocked && currentHp != null && maxHp != null) ...[
                SizedBox(height: DuolingoSpacing.md),
                // HP Bar
                Row(
                  children: [
                    Text(
                      'HP: $currentHp/$maxHp',
                      style: DuolingoTextStyles.body,
                    ),
                    SizedBox(width: DuolingoSpacing.md),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: currentHp! / maxHp!,
                          minHeight: 8,
                          backgroundColor: DuolingoColors.mistakeRed.withValues(
                            alpha: 0.3,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getHpBarColor(currentHp!, maxHp!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: DuolingoSpacing.md),
              // Rewards
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.md,
                  vertical: DuolingoSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.yellow.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.card_giftcard,
                      size: 16,
                      color: DuolingoColors.rewardYellow,
                    ),
                    SizedBox(width: DuolingoSpacing.sm),
                    Expanded(
                      child: Text(
                        'Rewards: $rewards',
                        style: DuolingoTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnlocked) ...[
                SizedBox(height: DuolingoSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DuolingoColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: DuolingoSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          DuolingoSpacing.radiusButton,
                        ),
                      ),
                    ),
                    onPressed: onTap,
                    child: Text(
                      defeated ? 'Battle Again' : 'Battle',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Easy':
        return DuolingoColors.primaryGreen;
      case 'Medium':
        return DuolingoColors.streakOrange;
      case 'Hard':
        return DuolingoColors.mistakeRed;
      default:
        return Colors.grey;
    }
  }

  Color _getHpBarColor(int current, int max) {
    final percentage = current / max;
    if (percentage > 0.5) {
      return DuolingoColors.primaryGreen;
    } else if (percentage > 0.25) {
      return DuolingoColors.streakOrange;
    } else {
      return DuolingoColors.mistakeRed;
    }
  }
}
