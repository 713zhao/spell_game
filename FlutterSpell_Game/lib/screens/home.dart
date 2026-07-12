import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/level_card.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GameProvider>();
      provider.init(widget.userName);
      provider.loadLevels();
      provider.loadUserStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spell Adventure'),
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.levels.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          return CustomScrollView(
            slivers: [
              // Streak banner
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.orange[300],
                leading: const SizedBox(),
                leadingWidth: 0,
                title: Center(
                  child: Column(
                    children: [
                      Text(
                        '🔥 ${provider.userStats?.currentStreak ?? 0} Days',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Keep it going!',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              // Points
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text('Points'),
                              Text(
                                '${provider.userStats?.totalPoints ?? 0}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text('Levels'),
                              Text(
                                '${provider.levels.length}',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Levels list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final level = provider.levels[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: LevelCard(
                        level: level,
                        isLocked: level.id > 1, // Simplified; use actual logic
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/level-select',
                            arguments: level.id,
                          );
                        },
                      ),
                    );
                  },
                  childCount: provider.levels.length,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Levels'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          // TODO: Navigate to other screens
        },
      ),
    );
  }
}
