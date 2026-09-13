import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/widgets/game_iframe.dart';

class GamePlayArgs {
  final String name;
  final String htmlUrl;

  GamePlayArgs({required this.name, required this.htmlUrl});
}

/// Full-screen embedded play view for a game store title.
class GamePlayScreen extends StatelessWidget {
  final GamePlayArgs args;

  const GamePlayScreen({Key? key, required this.args}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(args.name, style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GameIframe(htmlUrl: args.htmlUrl),
      ),
    );
  }
}
