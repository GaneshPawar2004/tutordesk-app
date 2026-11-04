import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/api.dart';
import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/common.dart';
import '../account/plan_screens.dart';
import 'reset_password_screen.dart';

enum OtpPurpose { signup, resetPassword }

/// Screen 4 (and signup verification): 6-digit code sent to the email.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    required this.purpose,
    this.name,
  });

  final String email;
  final OtpPurpose purpose;
  final String? name;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _length = 6;
  static const _resendSeconds = 30;

  final _ctrls = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _loading = false;
  String? _error;

  String get _code => _ctrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _nodes.first.requestFocus(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
  }

  void _onChanged(int index, String value) {
    setState(() => _error = null);
    // Handle paste of the full code into any box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < _length; i++) {
        _ctrls[i].text = i < digits.length ? digits[i] : '';
      }
      final next = digits.length.clamp(0, _length - 1);
      _nodes[next].requestFocus();
      if (digits.length >= _length) _verify();
      return;
    }
    if (value.isNotEmpty) {
      if (index < _length - 1) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
        _verify();
      }
    }
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctrls[index].text.isEmpty &&
        index > 0) {
      _ctrls[index - 1].clear();
      _nodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String get _purposeName =>
      widget.purpose == OtpPurpose.signup ? 'signup' : 'reset';

  Future<void> _resend() async {
    try {
      await appState.resendOtp(widget.email, _purposeName);
    } on ApiException catch (e) {
      if (mounted) showError(context, e.message);
      return;
    }
    if (!mounted) return;
    for (final c in _ctrls) {
      c.clear();
    }
    _nodes.first.requestFocus();
    _startTimer();
    showSuccess(
      context,
      'A new code has been sent to ${maskEmail(widget.email)}',
    );
  }

  Future<void> _verify() async {
    if (_code.length != _length) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    String? resetToken;
    try {
      if (widget.purpose == OtpPurpose.signup) {
        await appState.verifyEmail(widget.email, _code);
      } else {
        resetToken = await appState.verifyResetOtp(widget.email, _code);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    switch (widget.purpose) {
      case OtpPurpose.signup:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => homeAfterSignIn()),
          (_) => false,
        );
      case OtpPurpose.resetPassword:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: widget.email,
              resetToken: resetToken!,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.purpose == OtpPurpose.signup
        ? 'Verify Email'
        : 'Enter OTP';
    return AuthScaffold(
      compactHeader: true,
      showBack: true,
      card: AuthCard(
        title: title,
        subtitle: 'We\'ve sent a 6-digit verification code to',
        children: [
          Transform.translate(
            offset: const Offset(0, -14),
            child: Text(
              maskEmail(widget.email),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < _length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _buildBox(i)),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          const SizedBox(height: 15),
          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Resend code in 00:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  )
                : TextButton(
                    onPressed: _resend,
                    child: const Text(
                      'Resend Code',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 15),
          GradientButton(
            label: widget.purpose == OtpPurpose.signup
                ? 'Verify & Continue'
                : 'Verify OTP',
            onPressed: _verify,
            loading: _loading,
          ),
          AuthSwitchLink(
            question: 'Wrong email? ',
            action: 'Change',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBox(int i) {
    return SizedBox(
      child: Focus(
        onKeyEvent: (_, e) => _onKey(i, e),
        child: TextField(
          controller: _ctrls[i],
          focusNode: _nodes[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          onChanged: (v) => _onChanged(i, v),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.fieldFill,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(
                color: _error != null
                    ? AppColors.danger
                    : AppColors.fieldBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
