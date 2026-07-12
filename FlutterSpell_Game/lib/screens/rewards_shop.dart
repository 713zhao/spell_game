import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game_models.dart';
import '../widgets/cosmetic_card.dart';
import '../services/sound_service.dart';

class RewardsShopScreen extends StatefulWidget {
  const RewardsShopScreen({Key? key}) : super(key: key);

  @override
  State<RewardsShopScreen> createState() => _RewardsShopScreenState();
}

class _RewardsShopScreenState extends State<RewardsShopScreen> {
  bool _isRedeeming = false;
  late SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = SoundService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GameProvider>();
      provider.loadUnlockables();
      provider.loadUserStats();
    });
  }

  Future<void> _handleRedeem(
    BuildContext context,
    GameProvider provider,
    Unlockable cosmetic,
  ) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Redemption'),
          content: Text(
            'Redeem ${cosmetic.name} for ${cosmetic.pointsCost} points?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Check if user has enough points
    if (provider.userStats == null ||
        provider.userStats!.totalPoints < cosmetic.pointsCost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Insufficient points'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Proceed with redemption
    if (mounted) {
      setState(() => _isRedeeming = true);
    }

    final success = await provider.redeemUnlockable(cosmetic.id);

    if (mounted) {
      setState(() => _isRedeeming = false);

      if (success) {
        _soundService.playPointRedemption();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cosmetic.name} redeemed!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to redeem: ${provider.errorMessage}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards Shop'),
        centerTitle: true,
      ),
      body: Consumer<GameProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.unlockables.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.unlockables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.errorMessage}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.loadUnlockables();
                      provider.loadUserStats();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Separate cosmetics into owned and available
          final available =
              provider.unlockables.where((u) => !u.owned).toList();
          final owned = provider.unlockables.where((u) => u.owned).toList();

          return CustomScrollView(
            slivers: [
              // Points balance header
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.amber[300],
                leading: const SizedBox(),
                leadingWidth: 0,
                title: Center(
                  child: Column(
                    children: [
                      const Text(
                        'Points Balance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        '${provider.userStats?.totalPoints ?? 0}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Available cosmetics section
              if (available.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'Available Cosmetics (${available.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cosmetic = available[index];
                        return Stack(
                          children: [
                            CosmeticCard(
                              cosmetic: cosmetic,
                              isOwned: false,
                              onRedeem: _isRedeeming
                                  ? null
                                  : () => _handleRedeem(
                                        context,
                                        provider,
                                        cosmetic,
                                      ),
                            ),
                            if (_isRedeeming)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                      childCount: available.length,
                    ),
                  ),
                ),
              ],

              // Owned cosmetics section
              if (owned.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Text(
                      'My Cosmetics (${owned.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cosmetic = owned[index];
                        return CosmeticCard(
                          cosmetic: cosmetic,
                          isOwned: true,
                          onEquip: !cosmetic.equipped
                              ? () {
                                  // TODO: Implement equip functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${cosmetic.name} equipped!',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : null,
                        );
                      },
                      childCount: owned.length,
                    ),
                  ),
                ),
                // Bottom padding
                SliverToBoxAdapter(
                  child: const SizedBox(height: 24),
                ),
              ],

              // Empty state
              if (available.isEmpty && owned.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.card_giftcard,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No cosmetics available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final provider = context.read<GameProvider>();
          provider.loadUnlockables();
          provider.loadUserStats();
        },
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
