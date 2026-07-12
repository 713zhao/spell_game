import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../widgets/player_card.dart';
import '../widgets/challenge_card.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 2;
  late TabController _tabController;
  String _selectedFilter = 'global';
  final List<String> _filterOptions = ['global', 'friends', 'school', 'grade'];
  final List<String> _filterLabels = ['Global', 'Friends', 'School', 'Grade'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GameProvider>();
      provider.loadLeaderboard(filter: _selectedFilter);
      provider.loadChallenges();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshLeaderboard() async {
    final provider = context.read<GameProvider>();
    await provider.loadLeaderboard(filter: _selectedFilter);
  }

  Future<void> _refreshChallenges() async {
    final provider = context.read<GameProvider>();
    await provider.loadChallenges();
  }

  void _showChallengeDialog() {
    final nameController = TextEditingController();
    int selectedLevel = 1;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Challenge a Player'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter opponent name',
                    label: Text('Opponent Name'),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButton<int>(
                  value: selectedLevel,
                  items: List.generate(
                    10,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text('Level ${index + 1}'),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      selectedLevel = value ?? 1;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter opponent name')),
                );
                return;
              }

              final provider = context.read<GameProvider>();
              final success = await provider.createChallenge(
                nameController.text,
                selectedLevel,
              );

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Challenge sent!')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${provider.errorMessage}')),
                );
              }
            },
            child: const Text('Send Challenge'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'Challenges'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Leaderboard Tab
          Consumer<GameProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  // Filter buttons
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    child: Row(
                      children: List.generate(
                        _filterOptions.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(_filterLabels[index]),
                            selected: _selectedFilter == _filterOptions[index],
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = _filterOptions[index];
                              });
                              provider.loadLeaderboard(
                                filter: _selectedFilter,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Leaderboard list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refreshLeaderboard,
                      child: provider.isLoading && provider.leaderboard.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : provider.errorMessage != null
                              ? Center(
                                  child: Text('Error: ${provider.errorMessage}'),
                                )
                              : provider.leaderboard.isEmpty
                                  ? const Center(child: Text('No players found'))
                                  : ListView.builder(
                                      itemCount: provider.leaderboard.length,
                                      itemBuilder: (context, index) {
                                        final entry = provider.leaderboard[index];
                                        final isCurrentUser =
                                            entry.userName == provider.userName;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          child: PlayerCard(
                                            entry: entry,
                                            isCurrentUser: isCurrentUser,
                                            onTap: () {
                                              // TODO: Navigate to player profile
                                            },
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ),
                ],
              );
            },
          ),
          // Challenges Tab
          Consumer<GameProvider>(
            builder: (context, provider, _) {
              return RefreshIndicator(
                onRefresh: _refreshChallenges,
                child: provider.isLoading && provider.challenges.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.errorMessage != null
                        ? Center(
                            child: Text('Error: ${provider.errorMessage}'),
                          )
                        : provider.challenges.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.sports_esports,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('No challenges yet'),
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _showChallengeDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create Challenge'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: provider.challenges.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == provider.challenges.length) {
                                    return Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: ElevatedButton.icon(
                                        onPressed: _showChallengeDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text('New Challenge'),
                                      ),
                                    );
                                  }

                                  final challenge = provider.challenges[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: ChallengeCard(
                                      challenge: challenge,
                                      currentUserName: provider.userName,
                                      onAccept: () async {
                                        final success =
                                            await provider.acceptChallenge(
                                          challenge.id,
                                        );
                                        if (success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Challenge accepted!'),
                                            ),
                                          );
                                        }
                                      },
                                      onComplete: () async {
                                        // TODO: Show score input dialog
                                        final success =
                                            await provider.completeChallenge(
                                          challenge.id,
                                          0.95,
                                        );
                                        if (success) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Challenge completed!'),
                                            ),
                                          );
                                        }
                                      },
                                      onView: () {
                                        // TODO: Navigate to challenge details
                                      },
                                    ),
                                  );
                                },
                              ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showChallengeDialog,
        icon: const Icon(Icons.add),
        label: const Text('Challenge'),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Levels'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          BottomNavigationBarItem(icon: Icon(Icons.card_giftcard), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });

            switch (index) {
              case 0:
                Navigator.of(context).pushReplacementNamed('/');
                break;
              case 1:
                Navigator.of(context).pushReplacementNamed('/study');
                break;
              case 2:
                // Already on leaderboard
                break;
              case 3:
                Navigator.of(context).pushReplacementNamed('/rewards');
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
