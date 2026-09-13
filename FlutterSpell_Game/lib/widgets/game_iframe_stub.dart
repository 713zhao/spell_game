import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';

/// Non-web platforms have no in-app browser view wired up yet; the game
/// store itself still works there, just not playing embedded games.
class GameIframe extends StatelessWidget {
  final String htmlUrl;

  const GameIframe({Key? key, required this.htmlUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Text(
          'This game is only playable in the web app for now.',
          textAlign: TextAlign.center,
          style: DuolingoTextStyles.body,
        ),
      ),
    );
  }
}
