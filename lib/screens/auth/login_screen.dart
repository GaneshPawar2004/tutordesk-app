import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api.dart';
import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';
import '../account/plan_screens.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await appState.login(_idCtrl.text.trim(), _passCtrl.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.code == 'EMAIL_NOT_VERIFIED' && isValidEmail(_idCtrl.text)) {
        // Unfinished signup: send a fresh code and verify now.
        final email = _idCtrl.text.trim().toLowerCase();
        appState.resendOtp(email, 'signup').ignore();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OtpScreen(email: email, purpose: OtpPurpose.signup),
          ),
        );
      }
      showError(context, e.message);
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeAfterSignIn()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      card: Form(
        key: _formKey,
        child: AuthCard(
          title: 'Welcome Back',
          subtitle: 'Sign in to your account',
          children: [
            const Center(child: _IndianUsersChip()),
            const SizedBox(height: 4),
            AuthTextField(
              controller: _idCtrl,
              hint: 'Mobile number or email',
              icon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Enter your mobile number or email';
                if (!isValidEmail(value) && !isValidMobile(value)) {
                  return 'Enter a valid 10-digit mobile number or email';
                }
                return null;
              },
            ),
            AuthTextField(
              controller: _passCtrl,
              hint: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _signIn(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Sign In',
              onPressed: _signIn,
              loading: _loading,
            ),
            AuthSwitchLink(
              question: 'Not an existing user? ',
              action: 'Create Account',
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
            ),
          ],
        ),
      ),
      footer: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              _FooterLink(
                'Privacy Policy',
                onTap: () => _openPage(context, 'privacy'),
              ),
              const Text(' · ', style: TextStyle(color: AppColors.textMuted)),
              _FooterLink(
                'Terms & Conditions',
                onTap: () => _openPage(context, 'terms'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '© Intellectual Digital Solutions',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Opens the privacy policy / terms page on the Kaksha website.
Future<void> _openPage(BuildContext context, String page) async {
  final ok = await launchUrl(
    Uri.parse('$siteBaseUrl/$page'),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) showError(context, 'Could not open the page.');
}

class _FooterLink extends StatelessWidget {
  const _FooterLink(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _IndianUsersChip extends StatelessWidget {
  const _IndianUsersChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB4BBE6), width: 1.5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _IndiaFlag(),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'For Indian users only',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IndiaFlag extends StatelessWidget {
  const _IndiaFlag();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 20,
        height: 14,
        child: Column(
          children: [
            Expanded(child: Container(color: const Color(0xFFFF9933))),
            Expanded(
              child: Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF000080)),
                  ),
                ),
              ),
            ),
            Expanded(child: Container(color: const Color(0xFF138808))),
          ],
        ),
      ),
    );
  }
}
