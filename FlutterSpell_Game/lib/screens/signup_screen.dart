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

  @override
  Widget build(BuildContext context) {
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
            const Center(child: Text('🎒', style: TextStyle(fontSize: 64))),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              'Create Your Account',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.pageTitle,
            ),
            SizedBox(height: DuolingoSpacing.xxl),
            TextField(
              controller: _usernameController,
              decoration: _inputDecoration('Username'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration('Password (optional)'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            Text('Grade (optional)', style: DuolingoTextStyles.sectionTitle),
            SizedBox(height: DuolingoSpacing.sm),
            Wrap(
              spacing: DuolingoSpacing.sm,
              runSpacing: DuolingoSpacing.sm,
              children: _grades.map((grade) {
                final selected = _selectedGrade == grade;
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedGrade = selected ? null : grade,
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: DuolingoSpacing.lg,
                      vertical: DuolingoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? DuolingoColors.primaryGreen
                          : DuolingoColors.neutralGray,
                      borderRadius:
                          BorderRadius.circular(DuolingoSpacing.radiusButton),
                    ),
                    child: Text(
                      grade,
                      style: DuolingoTextStyles.cardTitle.copyWith(
                        color: selected
                            ? DuolingoColors.backgroundWhite
                            : DuolingoColors.darkText,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      'Create Account',
                      style:
                          DuolingoTextStyles.cardTitle.copyWith(color: Colors.white),
                    ),
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
