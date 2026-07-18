import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../design_system/design_system.dart';
import '../providers/game_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedGrade;
  bool _isSubmitting = false;
  String? _errorText;

  static const _grades = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6'];

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _usernameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a username');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    final ok = await context.read<GameProvider>().signup(
          name: name,
          password:
              _passwordController.text.isEmpty ? null : _passwordController.text,
          grade: _selectedGrade,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      setState(() {
        _errorText =
            context.read<GameProvider>().errorMessage ?? 'Could not create account';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DuolingoColors.backgroundWhite,
      appBar: AppBar(
        title: Text('Sign Up', style: DuolingoTextStyles.pageTitle),
        backgroundColor: DuolingoColors.backgroundWhite,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(DuolingoSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            DropdownButtonFormField<String>(
              value: _selectedGrade,
              decoration: InputDecoration(
                labelText: 'Grade (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
              items: _grades
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedGrade = value),
            ),
            SizedBox(height: DuolingoSpacing.xl),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: DuolingoColors.primaryGreen,
                padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create Account'),
            ),
            if (_errorText != null) ...[
              SizedBox(height: DuolingoSpacing.lg),
              Text(
                _errorText!,
                style:
                    DuolingoTextStyles.body.copyWith(color: DuolingoColors.mistakeRed),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
