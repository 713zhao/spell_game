import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

class BossBattleScreen extends StatefulWidget {
  final int bossId;

  const BossBattleScreen({
    Key? key,
    required this.bossId,
  }) : super(key: key);

  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen>
    with TickerProviderStateMixin {
  bool _isVictory = false;
  late AnimationController _bossAnimController;

  @override
  void initState() {
    super.initState();
    _bossAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _bossAnimController.dispose();
    super.dispose();
  }

  void _handleFight() {
    // Animate boss
    _bossAnimController.forward().then((_) {
      _bossAnimController.reverse();
    });

    // After a brief delay, show victory
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isVictory = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final boss = _getBossData(widget.bossId);

    if (_isVictory) {
      return _VictoryScreen(
        bossName: boss['name'] as String,
        rewards: boss['rewards'] as String,
        xp: boss['xp'] as int,
        onContinue: () {
          Navigator.popUntil(context, ModalRoute.withName('/boss-arena'));
        },
      );
    }

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text(boss['name'] as String, style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(DuolingoSpacing.lg),
          child: Column(
            children: [
              SizedBox(height: DuolingoSpacing.xl),
              // Boss Character with animation
              ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                  CurvedAnimation(parent: _bossAnimController, curve: Curves.elasticInOut),
                ),
                child: Text(
                  boss['icon'] as String,
                  style: const TextStyle(fontSize: 120),
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
              // Boss Name and Difficulty
              Text(
                boss['name'] as String,
                style: DuolingoTextStyles.pageTitle,
              ),
              SizedBox(height: DuolingoSpacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DuolingoSpacing.md,
                  vertical: DuolingoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _getDifficultyColor(boss['difficulty'] as String),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  boss['difficulty'] as String,
                  style: DuolingoTextStyles.label.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.xxl),
              // Boss HP Bar
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  color: DuolingoColors.neutralGray,
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boss Health',
                      style: DuolingoTextStyles.sectionTitle,
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${boss['currentHp']}/${boss['maxHp']} HP',
                          style: DuolingoTextStyles.largeValue.copyWith(
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          '${((boss['currentHp'] as int) / (boss['maxHp'] as int) * 100).toStringAsFixed(0)}%',
                          style: DuolingoTextStyles.body,
                        ),
                      ],
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (boss['currentHp'] as int) / (boss['maxHp'] as int),
                        minHeight: 24,
                        backgroundColor: DuolingoColors.mistakeRed.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getHpBarColor(
                            boss['currentHp'] as int,
                            boss['maxHp'] as int,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xxl),
              // Challenge Info
              Container(
                padding: EdgeInsets.all(DuolingoSpacing.lg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: DuolingoColors.infoGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                  boxShadow: DuolingoShadows.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Challenge',
                      style: DuolingoTextStyles.sectionTitle,
                    ),
                    SizedBox(height: DuolingoSpacing.md),
                    Text(
                      'Spell 10 words correctly to defeat the boss!',
                      style: DuolingoTextStyles.body.copyWith(
                        fontSize: 14,
                        color: DuolingoColors.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: DuolingoSpacing.xxl),
              // Fight Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.mistakeRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: DuolingoSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _handleFight,
                  icon: const Icon(Icons.flash_on, size: 24),
                  label: const Text(
                    'Fight ▶',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getBossData(int bossId) {
    switch (bossId) {
      case 1:
        return {
          'name': 'Spelling Dragon',
          'icon': '🐉',
          'difficulty': 'Easy',
          'currentHp': 3,
          'maxHp': 4,
          'rewards': '100 XP, Rare Item',
          'xp': 100,
        };
      case 2:
        return {
          'name': 'Phoneme Phoenix',
          'icon': '🔥',
          'difficulty': 'Medium',
          'currentHp': 4,
          'maxHp': 5,
          'rewards': '200 XP, Epic Item',
          'xp': 200,
        };
      case 3:
        return {
          'name': 'Vocab Viper',
          'icon': '🐍',
          'difficulty': 'Hard',
          'currentHp': 5,
          'maxHp': 6,
          'rewards': '300 XP, Legendary Item',
          'xp': 300,
        };
      default:
        return {
          'name': 'Unknown Boss',
          'icon': '❓',
          'difficulty': 'Unknown',
          'currentHp': 1,
          'maxHp': 1,
          'rewards': '0 XP',
          'xp': 0,
        };
    }
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

class _VictoryScreen extends StatelessWidget {
  final String bossName;
  final String rewards;
  final int xp;
  final VoidCallback onContinue;

  const _VictoryScreen({
    required this.bossName,
    required this.rewards,
    required this.xp,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        onContinue();
        return false;
      },
      child: Scaffold(
        backgroundColor: DuolingoColors.backgroundWhite,
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(DuolingoSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                // Victory Emoji
                Text(
                  '🎉',
                  style: const TextStyle(fontSize: 80),
                ),
                SizedBox(height: DuolingoSpacing.xl),
                // Victory Text
                Text(
                  'Victory!',
                  style: DuolingoTextStyles.pageTitle.copyWith(
                    fontSize: 32,
                    color: DuolingoColors.primaryGreen,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.md),
                Text(
                  'You defeated $bossName',
                  style: DuolingoTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: DuolingoSpacing.xxl),
                // Rewards Card
                Container(
                  padding: EdgeInsets.all(DuolingoSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: DuolingoColors.rewardGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
                    boxShadow: DuolingoShadows.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Rewards Earned',
                        style: DuolingoTextStyles.sectionTitle,
                      ),
                      SizedBox(height: DuolingoSpacing.lg),
                      // XP Reward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '⭐',
                            style: const TextStyle(fontSize: 24),
                          ),
                          SizedBox(width: DuolingoSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Experience Points',
                                style: DuolingoTextStyles.label,
                              ),
                              Text(
                                '+$xp XP',
                                style: DuolingoTextStyles.largeValue.copyWith(
                                  color: DuolingoColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: DuolingoSpacing.lg),
                      Divider(
                        height: 1,
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                      SizedBox(height: DuolingoSpacing.lg),
                      // Item Reward
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🎁',
                            style: const TextStyle(fontSize: 24),
                          ),
                          SizedBox(width: DuolingoSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Special Item',
                                  style: DuolingoTextStyles.label,
                                ),
                                Text(
                                  rewards,
                                  style: DuolingoTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: DuolingoSpacing.xxl),
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DuolingoColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: DuolingoSpacing.lg,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(DuolingoSpacing.radiusButton),
                      ),
                    ),
                    onPressed: onContinue,
                    child: const Text(
                      'Back to Arena',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: DuolingoSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
