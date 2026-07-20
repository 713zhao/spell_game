import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';
import '../widgets/user_avatar.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedRecentUser;
  bool _useManualEntry = false;
  bool _isSubmitting = false;
  String? _errorText;

  final _usernameController = TextEditingController();
  final _manualPasswordController = TextEditingController();
  final _quickPickPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadRecentUsers();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _manualPasswordController.dispose();
    _quickPickPasswordController.dispose();
    super.dispose();
  }

  /// Tapping a quick-pick avatar tries to log in immediately using a
  /// locally-saved password (see GameProvider.loginQuick). If there's no
  /// saved password, or it's stale, this falls back to showing a
  /// password field for that user instead of a dead end.
  Future<void> _quickLogin(String name) async {
    setState(() {
      _selectedRecentUser = name;
      _isSubmitting = true;
      _errorText = null;
    });
    final ok = await context.read<GameProvider>().loginQuick(name);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  Future<void> _submit(String name, String password) async {
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a username');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final provider = context.read<GameProvider>();
    provider.init(name);
    final ok = await provider.login(password);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      setState(() => _errorText = 'Incorrect username or password');
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: DuolingoColors.neutralGray,
      contentPadding: EdgeInsets.all(DuolingoSpacing.lg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        borderSide:
            const BorderSide(color: DuolingoColors.informationBlue, width: 2),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: DuolingoColors.primaryGreen,
        padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
        ),
        elevation: 0,
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              label,
              style: DuolingoTextStyles.cardTitle.copyWith(color: Colors.white),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    // Exclude whoever this session just switched away from - after
    // GameProvider.logout(), userName still holds the previous user (logout
    // doesn't reset identity), so this keeps them out of their own
    // "switch user" picker without needing a separate flag.
    final recentUsers =
        provider.recentUsers.where((name) => name != provider.userName).toList();
    final showQuickPick = recentUsers.isNotEmpty && !_useManualEntry;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: Text('🐕', style: TextStyle(fontSize: 64))),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              'Welcome Back!',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.pageTitle,
            ),
            SizedBox(height: DuolingoSpacing.xxl),
            if (showQuickPick) ...[
              Text("Who's playing?", style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              Wrap(
                spacing: DuolingoSpacing.lg,
                runSpacing: DuolingoSpacing.lg,
                children: recentUsers.map((name) {
                  final selected = _selectedRecentUser == name;
                  return GestureDetector(
                    onTap: _isSubmitting ? null : () => _quickLogin(name),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: DuolingoColors.primaryGreen, width: 3)
                                : null,
                            boxShadow: DuolingoShadows.cardShadow,
                          ),
                          child: UserAvatar(name: name, size: 64),
                        ),
                        SizedBox(height: DuolingoSpacing.xs),
                        Text(name, style: DuolingoTextStyles.label),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (_selectedRecentUser != null) ...[
                SizedBox(height: DuolingoSpacing.xl),
                Text(
                  'Enter your password to continue',
                  style: DuolingoTextStyles.body,
                ),
                SizedBox(height: DuolingoSpacing.sm),
                TextField(
                  controller: _quickPickPasswordController,
                  obscureText: true,
                  decoration: _inputDecoration('Password for $_selectedRecentUser'),
                  onSubmitted: (_) => _submit(
                    _selectedRecentUser!,
                    _quickPickPasswordController.text,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.lg),
                _primaryButton(
                  label: 'Log In',
                  onPressed: _isSubmitting
                      ? null
                      : () => _submit(
                            _selectedRecentUser!,
                            _quickPickPasswordController.text,
                          ),
                ),
              ],
              SizedBox(height: DuolingoSpacing.lg),
              TextButton(
                onPressed: () => setState(() {
                  _useManualEntry = true;
                  _selectedRecentUser = null;
                  _errorText = null;
                }),
                child: const Text('Not you? Use a different username'),
              ),
            ] else ...[
              Text('Enter your details', style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration('Username'),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _manualPasswordController,
                obscureText: true,
                decoration: _inputDecoration('Password'),
                onSubmitted: (_) => _submit(
                  _usernameController.text.trim(),
                  _manualPasswordController.text,
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              _primaryButton(
                label: 'Log In',
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(
                          _usernameController.text.trim(),
                          _manualPasswordController.text,
                        ),
              ),
              if (recentUsers.isNotEmpty) ...[
                SizedBox(height: DuolingoSpacing.lg),
                TextButton(
                  onPressed: () => setState(() {
                    _useManualEntry = false;
                    _errorText = null;
                  }),
                  child: const Text('Back to profile picker'),
                ),
              ],
            ],
            if (_errorText != null) ...[
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                _errorText!,
                style:
                    DuolingoTextStyles.body.copyWith(color: DuolingoColors.mistakeRed),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: DuolingoSpacing.xxl),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/signup'),
                child: Text(
                  'New here? Sign Up',
                  style: DuolingoTextStyles.cardTitle
                      .copyWith(color: DuolingoColors.informationBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
