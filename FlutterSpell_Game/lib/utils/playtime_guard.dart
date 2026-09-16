import 'dart:async';
import 'package:flutter/widgets.dart';
import '../main.dart' show gameProvider;

/// Mix into a game-playing screen's State to enforce the daily combined
/// minigame play-time cap (backend-tracked, see MiniGameManager): sends a
/// heartbeat of elapsed seconds every [heartbeatInterval] while the screen
/// is alive, and calls [onPlaytimeLocked] the moment the cap is reached -
/// including immediately, if it was already reached before this screen
/// opened.
mixin PlaytimeGuardMixin<T extends StatefulWidget> on State<T> {
  Timer? _playtimeTimer;
  static const heartbeatInterval = Duration(seconds: 10);

  /// Called once when the cap is (or becomes) reached. Implementations
  /// should stop/pause gameplay and show a lock message.
  void onPlaytimeLocked();

  void startPlaytimeGuard() {
    _checkInitialStatus();
    _playtimeTimer = Timer.periodic(heartbeatInterval, (_) => _tick());
  }

  Future<void> _checkInitialStatus() async {
    await gameProvider.loadPlaytimeStatus();
    if (!mounted) return;
    if (gameProvider.playtimeLocked) onPlaytimeLocked();
  }

  Future<void> _tick() async {
    final locked =
        await gameProvider.sendPlaytimeHeartbeat(heartbeatInterval.inSeconds);
    if (!mounted) return;
    if (locked) {
      _playtimeTimer?.cancel();
      onPlaytimeLocked();
    }
  }

  void disposePlaytimeGuard() {
    _playtimeTimer?.cancel();
  }
}
