import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';

/// Screen 3: user enters registered email to receive a password-reset OTP.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // TODO(backend): send password-reset OTP to email.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: _emailCtrl.text.trim(),
          purpose: OtpPurpose.resetPassword,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      card: Form(
        key: _formKey,
        child: AuthCard(
          title: 'Forgot Password',
          subtitle:
              'Enter your registered email and we\'ll send you a '
              'verification code to reset your password.',
          children: [
            AuthTextField(
              controller: _emailCtrl,
              hint: 'Registered email address',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendOtp(),
              validator: (v) =>
                  isValidEmail(v ?? '') ? null : 'Enter a valid email address',
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Send OTP',
              onPressed: _sendOtp,
              loading: _loading,
            ),
            AuthSwitchLink(
              question: 'Remember your password? ',
              action: 'Sign In',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
      footer: const Text(
        'The code will be sent to your email inbox.\nCheck your spam folder if you don\'t see it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
    );
  }
}
