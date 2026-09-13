import 'package:flutter/material.dart';
import 'package:spell_game/widgets/account_avatar_button.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/models/game_models.dart';
import '../main.dart' show gameProvider;
import 'game_play_screen.dart' show GamePlayArgs;
import 'word_snake_screen.dart';

/// Game store: a catalog of embeddable mini-games. Each game has a one-time
/// coin cost to unlock and a smaller coin cost every time it's played,
/// mirroring the Rewards Shop's coin-spend pattern.
class GameStoreScreen extends StatefulWidget {
  const GameStoreScreen({Key? key}) : super(key: key);

  @override
  State<GameStoreScreen> createState() => _GameStoreScreenState();
}

class _GameStoreScreenState extends State<GameStoreScreen> {
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    gameProvider.addListener(_onChanged);
    _load();
  }

  Future<void> _load() async {
    await gameProvider.loadMiniGames();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    gameProvider.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _onUnlock(MiniGame game) async {
    setState(() => _busy = true);
    final success = await gameProvider.unlockMiniGame(game.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? '${game.name} unlocked!'
            : gameProvider.errorMessage ?? 'Could not unlock game'),
      ),
    );
  }

  Future<void> _onPlay(MiniGame game) async {
    setState(() => _busy = true);
    final result = await gameProvider.playMiniGame(game.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gameProvider.errorMessage ?? 'Could not start game'),
        ),
      );
      return;
    }
    if (result['gameType'] == 'native' && result['nativeKey'] == 'word_snake') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const WordSnakeScreen()),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      '/game-play',
      arguments: GamePlayArgs(
        name: game.name,
        htmlUrl: result['htmlUrl'] as String,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Game Store', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [AccountAvatarButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCoinsBanner(),
                Expanded(
                  child: gameProvider.minigames.isEmpty
                      ? Center(
                          child: Text(
                            'No games available yet.\nCheck back soon!',
                            textAlign: TextAlign.center,
                            style: DuolingoTextStyles.body,
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.all(DuolingoSpacing.lg),
                          itemCount: gameProvider.minigames.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(height: DuolingoSpacing.lg),
                          itemBuilder: (context, index) =>
                              _buildGameCard(gameProvider.minigames[index]),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        backgroundColor: DuolingoColors.backgroundWhite,
        selectedItemColor: DuolingoColors.primaryGreen,
        unselectedItemColor: DuolingoColors.navInactiveGray,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'World Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.backpack), label: 'Backpack'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: 'Progress'),
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
              Navigator.of(context).pushReplacementNamed('/progress');
              break;
            case 4:
              Navigator.of(context).pushReplacementNamed('/profile');
              break;
          }
        },
      ),
    );
  }

  Widget _buildCoinsBanner() {
    return Container(
      margin: EdgeInsets.fromLTRB(
          DuolingoSpacing.lg, DuolingoSpacing.md, DuolingoSpacing.lg, 0),
      padding: EdgeInsets.symmetric(
        horizontal: DuolingoSpacing.lg,
        vertical: DuolingoSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: DuolingoColors.rewardGradient),
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        boxShadow: DuolingoShadows.cardShadow,
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 28)),
          SizedBox(width: DuolingoSpacing.sm),
          Text('Your Coins', style: DuolingoTextStyles.body),
          const Spacer(),
          Text(
            '${gameProvider.coins}',
            style: DuolingoTextStyles.cardTitle
                .copyWith(color: DuolingoColors.treasureGold),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(MiniGame game) {
    final canAffordUnlock = gameProvider.coins >= game.unlockCost;
    final canAffordPlay = gameProvider.coins >= game.playCost;

    return Container(
      padding: EdgeInsets.all(DuolingoSpacing.lg),
      decoration: BoxDecoration(
        color: DuolingoColors.neutralGray,
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusCard),
        boxShadow: DuolingoShadows.cardShadow,
      ),
      child: Row(
        children: [
          Text(game.icon, style: const TextStyle(fontSize: 44)),
          SizedBox(width: DuolingoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(game.name, style: DuolingoTextStyles.cardTitle),
                if (game.description != null) ...[
                  SizedBox(height: DuolingoSpacing.xs),
                  Text(
                    game.description!,
                    style: DuolingoTextStyles.label
                        .copyWith(color: DuolingoColors.bodyText),
                  ),
                ],
                SizedBox(height: DuolingoSpacing.sm),
                Text(
                  game.unlocked
                      ? '💰 ${game.playCost} coins to play'
                      : '🔒 ${game.unlockCost} coins to unlock',
                  style: DuolingoTextStyles.label,
                ),
              ],
            ),
          ),
          SizedBox(width: DuolingoSpacing.sm),
          _buildActionButton(
            game: game,
            enabled: !_busy &&
                (game.unlocked ? canAffordPlay : canAffordUnlock),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required MiniGame game, required bool enabled}) {
    final label = game.unlocked ? 'Play' : 'Unlock';
    return ElevatedButton(
      onPressed: enabled
          ? () => game.unlocked ? _onPlay(game) : _onUnlock(game)
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            game.unlocked ? DuolingoColors.primaryGreen : DuolingoColors.informationBlue,
        foregroundColor: Colors.white,
        disabledBackgroundColor: DuolingoColors.secondaryButtonGray,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        ),
      ),
      child: Text(label),
    );
  }
}
