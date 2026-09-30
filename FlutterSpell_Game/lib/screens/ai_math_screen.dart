import 'package:flutter/material.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/widgets/game_iframe.dart';

/// Embeds the AI Math web app (aimath.pages.dev) full-screen.
class AiMathScreen extends StatelessWidget {
  static const String url = 'https://aimath.pages.dev/#/main';

  const AiMathScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('AI Math', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DuolingoColors.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SafeArea(child: GameIframe(htmlUrl: url)),
    );
  }
}
