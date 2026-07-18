import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final recentUsers = context.watch<GameProvider>().recentUsers;
    final showQuickPick = recentUsers.isNotEmpty && !_useManualEntry;

    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Welcome Back', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showQuickPick) ...[
              Text("Who's playing?", style: DuolingoTextStyles.sectionTitle),
              SizedBox(height: DuolingoSpacing.lg),
              Wrap(
                spacing: DuolingoSpacing.lg,
                runSpacing: DuolingoSpacing.lg,
                children: recentUsers.map((name) {
                  final selected = _selectedRecentUser == name;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedRecentUser = name;
                      _errorText = null;
                    }),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? DuolingoColors.primaryGreen
                                : DuolingoColors.neutralGray,
                            border: selected
                                ? Border.all(
                                    color: DuolingoColors.primaryGreenLight,
                                    width: 3)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: DuolingoTextStyles.cardTitle.copyWith(
                              color: selected
                                  ? DuolingoColors.backgroundWhite
                                  : DuolingoColors.darkText,
                              fontSize: 20,
                            ),
                          ),
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
                TextField(
                  controller: _quickPickPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password for $_selectedRecentUser',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                  ),
                  onSubmitted: (_) => _submit(
                    _selectedRecentUser!,
                    _quickPickPasswordController.text,
                  ),
                ),
                SizedBox(height: DuolingoSpacing.lg),
                ElevatedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => _submit(
                            _selectedRecentUser!,
                            _quickPickPasswordController.text,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DuolingoColors.primaryGreen,
                    padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Log In'),
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
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              TextField(
                controller: _manualPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
                onSubmitted: (_) => _submit(
                  _usernameController.text.trim(),
                  _manualPasswordController.text,
                ),
              ),
              SizedBox(height: DuolingoSpacing.lg),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(
                          _usernameController.text.trim(),
                          _manualPasswordController.text,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DuolingoColors.primaryGreen,
                  padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(DuolingoSpacing.radiusButton),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Log In'),
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
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: const Text('New here? Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
