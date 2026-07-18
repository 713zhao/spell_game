import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show gameProvider;
import 'home.dart';
import 'login_screen.dart';

/// Startup gate: silently restores a previously-persisted session (see
/// GameProvider.restoreSession) if one exists on this device, otherwise
/// shows the login screen. Replaces the old hardcoded-ERIC startup.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  String? _restoredUser;

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
        _restoredUser = lastUser;
      }
    } catch (_) {
      // If restoring the session fails for any reason, fall through to
      // the login screen rather than leaving the user stuck on the
      // loading spinner forever.
      _restoredUser = null;
    }
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoredUser != null) {
      return HomeScreen(userName: _restoredUser!);
    }
    return const LoginScreen();
  }
}
