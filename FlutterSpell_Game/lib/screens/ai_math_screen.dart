import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spell_game/design_system/design_system.dart';
import 'package:spell_game/providers/game_provider.dart';
import 'package:spell_game/widgets/game_iframe.dart';

/// Embeds the AI Math web app (aimath.pages.dev) full-screen, signed in as
/// the same player: the username (and age, when known) go in the URL and AI
/// Math uses them instead of asking for a profile.
class AiMathScreen extends StatefulWidget {
  static const String baseUrl = String.fromEnvironment(
    'AIMATH_URL',
    defaultValue: 'https://aimath.pages.dev/',
  );

  const AiMathScreen({Key? key}) : super(key: key);

  @override
  State<AiMathScreen> createState() => _AiMathScreenState();
}

class _AiMathScreenState extends State<AiMathScreen> {
  String? _url;
  Timer? _goalTimer;
  static const _heartbeat = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _buildUrl();
    // AI Math is an external app, so time spent on this screen is what
    // counts toward its daily goal.
    final game = context.read<GameProvider>();
    _goalTimer = Timer.periodic(
      _heartbeat,
      (_) => game.reportMathTime(_heartbeat.inSeconds),
    );
  }

  @override
  void dispose() {
    _goalTimer?.cancel();
    super.dispose();
  }

  Future<void> _buildUrl() async {
    final game = context.read<GameProvider>();
    final params = <String, String>{};
    // GUEST is a shared fallback identity, not a person - let AI Math ask.
    if (game.userName.isNotEmpty && game.userName.toUpperCase() != 'GUEST') {
      params['user'] = game.userName;
      try {
        final profile = await game.apiClient.getUserProfile();
        final age = int.tryParse('${profile['age']}');
        if (age != null) params['age'] = '$age';
      } catch (_) {}
    }
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    if (!mounted) return;
    setState(() => _url = '${AiMathScreen.baseUrl}$query#/main');
  }

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
      body: SafeArea(
        child: _url == null
            ? const Center(child: CircularProgressIndicator())
            : GameIframe(htmlUrl: _url!),
      ),
    );
  }
}
