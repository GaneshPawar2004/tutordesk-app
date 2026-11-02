import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../../data/app_state.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';

/// Shown after the reset OTP is verified: choose a new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  final String email;

  /// Proof from the server that the reset code was verified.
  final String resetToken;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await appState.resetPassword(widget.resetToken, _passCtrl.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showError(context, e.message);
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Password reset successfully. Please sign in.',
          style: TextStyle(fontSize: 13),
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
          title: 'Reset Password',
          subtitle: 'Create a new password for your account',
          children: [
            AuthTextField(
              controller: _passCtrl,
              hint: 'New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (v) => (v == null || v.length < 6)
                  ? 'Password must be at least 6 characters'
                  : null,
            ),
            AuthTextField(
              controller: _confirmCtrl,
              hint: 'Confirm New Password',
              icon: Icons.lock_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              validator: (v) =>
                  v != _passCtrl.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 12),
            GradientButton(
              label: 'Reset Password',
              onPressed: _save,
              loading: _loading,
            ),
            AuthSwitchLink(
              question: 'Changed your mind? ',
              action: 'Sign In',
              onTap: () async {
                final leave = await confirmDialog(
                  context,
                  title: 'Cancel reset?',
                  message: 'Your password will not be changed.',
                  confirmLabel: 'YES',
                );
                if (leave && context.mounted) {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
