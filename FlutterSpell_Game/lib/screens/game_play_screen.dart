import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/utils/playtime_guard.dart';
import 'package:spell_game/widgets/game_iframe.dart';

class GamePlayArgs {
  final String name;
  final String htmlUrl;

  GamePlayArgs({required this.name, required this.htmlUrl});
}

/// Full-screen embedded play view for a game store title.
class GamePlayScreen extends StatefulWidget {
  final GamePlayArgs args;

  const GamePlayScreen({Key? key, required this.args}) : super(key: key);

  @override
  State<GamePlayScreen> createState() => _GamePlayScreenState();
}

class _GamePlayScreenState extends State<GamePlayScreen>
    with PlaytimeGuardMixin<GamePlayScreen> {
  bool _playtimeLocked = false;

  @override
  void initState() {
    super.initState();
    startPlaytimeGuard();
  }

  @override
  void onPlaytimeLocked() {
    if (!mounted) return;
    setState(() => _playtimeLocked = true);
  }

  @override
  void dispose() {
    disposePlaytimeGuard();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.args.name, style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            GameIframe(htmlUrl: widget.args.htmlUrl),
            if (_playtimeLocked) _buildPlaytimeLockedOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaytimeLockedOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 48)),
              SizedBox(height: DuolingoSpacing.sm),
              Text('Time\'s up for today!',
                  style: DuolingoTextStyles.sectionTitle
                      .copyWith(color: Colors.white)),
              SizedBox(height: DuolingoSpacing.sm),
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: DuolingoSpacing.lg),
                child: Text(
                  'You\'ve used your 15 minutes of game time for today. '
                  'Come back tomorrow!',
                  textAlign: TextAlign.center,
                  style: DuolingoTextStyles.label
                      .copyWith(color: Colors.white70),
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
