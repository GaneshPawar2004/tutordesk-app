import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/auth_widgets.dart';
import 'otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _mobileCtrl,
      _passCtrl,
      _confirmCtrl,
      _referralCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    // TODO(backend): register user & send OTP to email.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          email: _emailCtrl.text.trim(),
          purpose: OtpPurpose.signup,
          name: _nameCtrl.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      compactHeader: true,
      card: Form(
        key: _formKey,
        child: AuthCard(
          title: 'Create Account',
          subtitle: 'Sign up for a new account',
          children: [
            AuthTextField(
              controller: _nameCtrl,
              hint: 'Full Name',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Enter your full name'
                  : null,
            ),
            AuthTextField(
              controller: _emailCtrl,
              hint: 'Email address',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  isValidEmail(v ?? '') ? null : 'Enter a valid email address',
            ),
            AuthTextField(
              controller: _mobileCtrl,
              hint: 'Mobile number',
              icon: Icons.smartphone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => isValidMobile(v ?? '')
                  ? null
                  : 'Enter a valid 10-digit mobile number',
            ),
            AuthTextField(
              controller: _passCtrl,
              hint: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => (v == null || v.length < 6)
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            AuthTextField(
              controller: _confirmCtrl,
              hint: 'Confirm Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) =>
                  v != _passCtrl.text ? 'Passwords do not match' : null,
            ),
            AuthTextField(
              controller: _referralCtrl,
              hint: 'Referral code (mobile no.)',
              icon: Icons.card_giftcard_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return null;
                return isValidMobile(value)
                    ? null
                    : 'Referral code must be a 10-digit mobile number';
              },
            ),
            const Text.rich(
              TextSpan(
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                children: [
                  TextSpan(
                    text: 'Optional',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text:
                        ' — only if someone referred you. Leave blank to skip.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Send Verification Code',
              onPressed: _sendCode,
              loading: _loading,
            ),
            AuthSwitchLink(
              question: 'Already have an account? ',
              action: 'Sign In',
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
