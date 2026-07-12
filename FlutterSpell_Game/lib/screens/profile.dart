import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/game_provider.dart';
import '../models/game_models.dart';
import '../widgets/stat_card.dart';
import '../widgets/achievement_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late SharedPreferences _prefs;
  bool _soundEnabled = true;
  bool _notificationsEnabled = true;
  bool _parentMode = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _loadProfileData();
  }

  void _initializeSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = _prefs.getBool('sound_enabled') ?? true;
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? true;
      _parentMode = _prefs.getBool('parent_mode') ?? false;
    });
  }

  void _loadProfileData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GameProvider>();
      provider.loadUserStats();
      provider.loadUnlockables();
    });
  }

  void _updateSoundSetting(bool value) async {
    setState(() => _soundEnabled = value);
    await _prefs.setBool('sound_enabled', value);
  }

  void _updateNotificationSetting(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _prefs.setBool('notifications_enabled', value);
  }

  void _updateParentModeSetting(bool value) async {
    setState(() => _parentMode = value);
    await _prefs.setBool('parent_mode', value);
  }

  Future<void> _equipCosmetic(GameProvider provider, int cosmeticId) async {
    final success = await provider.redeemUnlockable(cosmeticId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cosmetic equipped!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to equip cosmetic')),
      );
    }
  }

  // Helper method to calculate level from points
  int _calculateLevel(int points) {
    return (points / 100).floor() + 1;
  }

  // Helper method to calculate best streak (using currentStreak for now)
  int _calculateBestStreak(int currentStreak) {
    return currentStreak; // In a real app, this would come from the API
  }

  // Helper method to calculate accuracy percentage
  double _calculateAccuracy(int totalPoints) {
    return (totalPoints % 100) * 0.9 + 75; // Mock calculation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.userStats == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = provider.userStats;
          final username = stats?.username ?? 'Player';
          final level = _calculateLevel(stats?.totalPoints ?? 0);
          final totalPoints = stats?.totalPoints ?? 0;
          final currentStreak = stats?.currentStreak ?? 0;
          final bestStreak = stats?.bestStreak ?? _calculateBestStreak(currentStreak);
          final accuracy = stats?.accuracy ?? _calculateAccuracy(totalPoints);
          final levelsCompleted = stats?.levelsCompleted ?? provider.levels.length;
          final grade = stats?.grade ?? 'Not Set';

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadUserStats();
              await provider.loadUnlockables();
              await provider.loadLevels();
            },
            child: CustomScrollView(
              slivers: [
                // Profile Header Section
                SliverAppBar(
                  floating: true,
                  backgroundColor: Colors.blue[600],
                  leading: const SizedBox(),
                  leadingWidth: 0,
                  title: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          // Avatar/Cosmetic Display
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                stats?.equippedCosmetic ?? '👤',
                                style: const TextStyle(fontSize: 50),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            username,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Level $level | Grade: $grade',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats Grid Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stats',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              label: 'Total Points',
                              value: totalPoints.toString(),
                              icon: '⭐',
                              backgroundColor: Colors.amber[50],
                            ),
                            StatCard(
                              label: 'Current Streak',
                              value: '$currentStreak days',
                              icon: '🔥',
                              backgroundColor: Colors.orange[50],
                            ),
                            StatCard(
                              label: 'Best Streak',
                              value: '$bestStreak days',
                              icon: '🏆',
                              backgroundColor: Colors.yellow[50],
                            ),
                            StatCard(
                              label: 'Levels Completed',
                              value: '$levelsCompleted/${provider.levels.length}',
                              icon: '📚',
                              backgroundColor: Colors.blue[50],
                            ),
                            StatCard(
                              label: 'Accuracy',
                              value: '${accuracy.toStringAsFixed(1)}%',
                              icon: '🎯',
                              backgroundColor: Colors.green[50],
                            ),
                            StatCard(
                              label: 'Daily Points',
                              value: (totalPoints ~/ 10).toString(),
                              icon: '📊',
                              backgroundColor: Colors.purple[50],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Achievements Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Achievements',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 0.8,
                          children: _buildAchievements(
                            levelsCompleted,
                            currentStreak,
                            accuracy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cosmetics Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cosmetics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (provider.unlockables.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'No cosmetics available yet',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.8,
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.unlockables.length,
                            itemBuilder: (context, index) {
                              final cosmetic = provider.unlockables[index];
                              return _buildCosmeticCard(
                                cosmetic,
                                provider,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Settings Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.volume_up),
                                title: const Text('Sound'),
                                trailing: Switch(
                                  value: _soundEnabled,
                                  onChanged: _updateSoundSetting,
                                ),
                              ),
                              Divider(height: 0, color: Colors.grey[300]),
                              ListTile(
                                leading: const Icon(Icons.notifications),
                                title: const Text('Notifications'),
                                trailing: Switch(
                                  value: _notificationsEnabled,
                                  onChanged: _updateNotificationSetting,
                                ),
                              ),
                              Divider(height: 0, color: Colors.grey[300]),
                              ListTile(
                                leading: const Icon(Icons.security),
                                title: const Text('Parent Mode'),
                                trailing: Switch(
                                  value: _parentMode,
                                  onChanged: _updateParentModeSetting,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Version 1.0.0',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom spacing
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildAchievements(
    int levelsCompleted,
    int currentStreak,
    double accuracy,
  ) {
    return [
      // Level Milestones
      AchievementBadge(
        icon: '5️⃣',
        name: '5 Levels',
        description: 'Complete 5 levels',
        unlocked: levelsCompleted >= 5,
        progress: levelsCompleted / 5,
        progressLabel: '$levelsCompleted/5',
      ),
      AchievementBadge(
        icon: '🔟',
        name: '10 Levels',
        description: 'Complete 10 levels',
        unlocked: levelsCompleted >= 10,
        progress: levelsCompleted / 10,
        progressLabel: '$levelsCompleted/10',
      ),

      // Streak Badges
      AchievementBadge(
        icon: '7️⃣',
        name: '7-Day Streak',
        description: 'Maintain 7-day streak',
        unlocked: currentStreak >= 7,
        progress: currentStreak / 7,
        progressLabel: '$currentStreak/7',
      ),
      AchievementBadge(
        icon: '3️⃣0️⃣',
        name: '30-Day Streak',
        description: 'Maintain 30-day streak',
        unlocked: currentStreak >= 30,
        progress: currentStreak / 30,
        progressLabel: '$currentStreak/30',
      ),

      // Accuracy Badges
      AchievementBadge(
        icon: '9️⃣',
        name: '90% Accuracy',
        description: 'Achieve 90% accuracy',
        unlocked: accuracy >= 90,
        progress: accuracy / 100,
        progressLabel: '${accuracy.toStringAsFixed(1)}%',
      ),
      AchievementBadge(
        icon: '💯',
        name: 'Perfect Score',
        description: 'Achieve 100% accuracy',
        unlocked: accuracy >= 99.9,
        progress: accuracy / 100,
        progressLabel: '${accuracy.toStringAsFixed(1)}%',
      ),
    ];
  }

  Widget _buildCosmeticCard(Unlockable cosmetic, GameProvider provider) {
    final isOwned = cosmetic.owned;
    final isEquipped = cosmetic.equipped;

    Color rarityColor;
    switch (cosmetic.rarity.toLowerCase()) {
      case 'legendary':
        rarityColor = Colors.orange[300]!;
        break;
      case 'epic':
        rarityColor = Colors.purple[300]!;
        break;
      case 'rare':
        rarityColor = Colors.blue[300]!;
        break;
      default:
        rarityColor = Colors.grey[400]!;
    }

    return Card(
      color: isEquipped ? Colors.amber[50] : Colors.white,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cosmetic Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: rarityColor,
                  ),
                  child: Center(
                    child: Text(
                      cosmetic.name[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Name
                Text(
                  cosmetic.name,
                  style: Theme.of(context).textTheme.labelLarge,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Rarity
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 2.0,
                  ),
                  decoration: BoxDecoration(
                    color: rarityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cosmetic.rarity,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),

                // Button
                if (isOwned)
                  ElevatedButton(
                    onPressed: () => _equipCosmetic(provider, cosmetic.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEquipped ? Colors.green : Colors.blue,
                      minimumSize: const Size(double.infinity, 32),
                    ),
                    child: Text(
                      isEquipped ? 'Equipped' : 'Equip',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: null,
                    child: Text(
                      '${cosmetic.pointsCost} pts',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),

          // Equipped badge
          if (isEquipped)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green[400],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
