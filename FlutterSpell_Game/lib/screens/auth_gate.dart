import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show gameProvider;
import 'home.dart';

/// Startup gate: silently restores a previously-persisted session (see
/// GameProvider.restoreSession) if one exists on this device, otherwise
/// enters as Guest (see GameProvider.loginAsGuest) so Home is always the
/// default screen - never a forced login. The account button on Home
/// (and every other main screen) is how a Guest actually signs in.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String _homeUser = 'GUEST';

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUser = prefs.getString('last_user');
      if (lastUser != null && lastUser.isNotEmpty) {
        gameProvider.init(lastUser);
        await gameProvider.restoreSession(lastUser);
        _homeUser = lastUser;
      } else {
        await gameProvider.loginAsGuest();
      }
    } catch (_) {
      // Restoring the previous session (or setting up Guest) failed for
      // some reason - fall back to Guest either way, so the user always
      // lands on Home instead of being stuck on the loading spinner.
      try {
        await gameProvider.loginAsGuest();
      } catch (_) {
        // Even Guest setup failed (e.g. backend unreachable) - still show
        // Home; its own data loads will surface the underlying error.
      }
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeScreen(userName: _homeUser);
  }
}
