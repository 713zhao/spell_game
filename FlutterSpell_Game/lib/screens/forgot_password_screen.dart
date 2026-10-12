import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design_system/design_system.dart';

/// Password recovery without a mail server: builds a ready-to-send email to
/// the support address. The parent only checks the pre-filled details and
/// taps Send; support then resets the password on the backend.
class ForgotPasswordScreen extends StatefulWidget {
  final String initialUsername;
  const ForgotPasswordScreen({super.key, this.initialUsername = ''});

  static const supportEmail = '713.zhao@gmail.com';

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _usernameController =
      TextEditingController(text: widget.initialUsername);
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _subject => 'AI Spell Game password reset';

  String get _body {
    final note = _noteController.text.trim();
    return 'Hello,\n\n'
        'Please help me reset my AI Spell Game password.\n\n'
        'Username: ${_usernameController.text.trim()}\n'
        'Email used at sign-up (if any): ${_emailController.text.trim()}\n'
        '${note.isEmpty ? '' : 'Other details: $note\n'}'
        '\nThank you!';
  }

  Future<void> _send() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorText = 'Enter the username');
      return;
    }
    setState(() => _errorText = null);
    final uri = Uri(
      scheme: 'mailto',
      path: ForgotPasswordScreen.supportEmail,
      query: 'subject=${Uri.encodeComponent(_subject)}'
          '&body=${Uri.encodeComponent(_body)}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(
          text: 'To: ${ForgotPasswordScreen.supportEmail}\n$_subject\n\n$_body'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'No email app found. The message was copied - paste it into an email to 713.zhao@gmail.com'),
      ));
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
            const Center(child: Text('🔑', style: TextStyle(fontSize: 64))),
            SizedBox(height: DuolingoSpacing.md),
            Text('Forgot Password?',
                textAlign: TextAlign.center,
                style: DuolingoTextStyles.pageTitle),
            SizedBox(height: DuolingoSpacing.md),
            Text(
              'A parent can send us a reset request. Fill in the details and '
              'tap the button - your email app opens with the message ready '
              'to send. We will reply with a new password.',
              textAlign: TextAlign.center,
              style: DuolingoTextStyles.body,
            ),
            SizedBox(height: DuolingoSpacing.xl),
            TextField(
              controller: _usernameController,
              decoration: _inputDecoration('Username'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration('Email used at sign-up (if any)'),
            ),
            SizedBox(height: DuolingoSpacing.lg),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: _inputDecoration('Anything else we should know (optional)'),
            ),
            SizedBox(height: DuolingoSpacing.xl),
            ElevatedButton(
              onPressed: _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: DuolingoColors.primaryGreen,
                padding: EdgeInsets.symmetric(vertical: DuolingoSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(DuolingoSpacing.radiusButton),
                ),
                elevation: 0,
              ),
              child: Text('Prepare Reset Email',
                  style:
                      DuolingoTextStyles.cardTitle.copyWith(color: Colors.white)),
            ),
            if (_errorText != null) ...[
              SizedBox(height: DuolingoSpacing.lg),
              Text(_errorText!,
                  textAlign: TextAlign.center,
                  style: DuolingoTextStyles.body
                      .copyWith(color: DuolingoColors.mistakeRed)),
            ],
          ],
        ),
      ),
    );
  }
}
