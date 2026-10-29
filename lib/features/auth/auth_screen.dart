import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/widgets/widgets.dart';

enum _Mode { login, register, invite }

/// Sign in, register a new tuition, or accept a staff invitation.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialError});

  /// Shown when restoring a saved session failed (e.g. server unreachable).
  final String? initialError;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  var _mode = _Mode.login;
  var _busy = false;
  var _showServer = false;
  var _hidePassword = true;

  late final _server = TextEditingController(text: context.appRead.serverUrl);
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _tuitionName = TextEditingController();
  final _city = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _code = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialError != null) {
      _showServer = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AppToast.show(context, widget.initialError!, type: ToastType.error);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _server,
      _identifier,
      _password,
      _confirm,
      _tuitionName,
      _city,
      _name,
      _phone,
      _email,
      _code,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String what) =>
      (v ?? '').trim().isEmpty ? 'Enter $what' : null;

  String? _passwordRule(String? v) {
    if ((v ?? '').length < 8) return 'Use at least 8 characters';
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final app = context.appRead;
    final server = _server.text.trim();
    try {
      switch (_mode) {
        case _Mode.login:
          await app.login(
            server: server,
            identifier: _identifier.text.trim(),
            password: _password.text,
          );
        case _Mode.register:
          await app.registerTuition(
            server: server,
            tuitionName: _tuitionName.text.trim(),
            city: _city.text.trim(),
            adminName: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
          );
        case _Mode.invite:
          await app.acceptInvite(
            server: server,
            phone: _phone.text.trim(),
            code: _code.text.trim(),
            password: _password.text,
          );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.status == 0) _showServer = true;
      });
      AppToast.show(context, e.message, type: ToastType.error);
    }
    // On success the root gate swaps this screen for the app.
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.login => 'Welcome back',
      _Mode.register => 'Register your tuition',
      _Mode.invite => 'Join your tuition',
    };
    final subtitle = switch (_mode) {
      _Mode.login => 'Log in with your mobile number or email.',
      _Mode.register => 'Create your tuition account. You will be its admin.',
      _Mode.invite =>
        'Enter the invite code your admin shared and choose a password.',
    };

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.onAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(text: 'Tutor'),
                        TextSpan(
                          text: 'Desk',
                          style: TextStyle(color: AppColors.accent),
                        ),
                      ],
                    ),
                    style: AppTextStyles.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(title, style: AppTextStyles.display.copyWith(fontSize: 30)),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTextStyles.bodyMuted),
              const SizedBox(height: Gap.lg),
              SegmentedChoice<_Mode>(
                options: const [
                  SelectOption(_Mode.login, 'Log in'),
                  SelectOption(_Mode.register, 'Register tuition'),
                  SelectOption(_Mode.invite, 'I have an invite code'),
                ],
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: Gap.lg),
              ..._fields(),
              const SizedBox(height: Gap.lg),
              PrimaryButton(
                label: switch (_mode) {
                  _Mode.login => 'Log in',
                  _Mode.register => 'Create tuition account',
                  _Mode.invite => 'Set password & join',
                },
                icon: Icons.arrow_forward_rounded,
                loading: _busy,
                onPressed: _submit,
              ),
              const SizedBox(height: Gap.lg),
              InkWell(
                onTap: () => setState(() => _showServer = !_showServer),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.dns_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Server: ${_server.text}',
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _showServer
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showServer) ...[
                const SizedBox(height: 8),
                CustomTextField(
                  label: 'Server address',
                  controller: _server,
                  keyboardType: TextInputType.url,
                  hint: 'http://192.168.0.117:4000',
                  helper:
                      'The address of the computer running the TutorDesk backend, on the same Wi‑Fi.',
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (!t.startsWith('http://') && !t.startsWith('https://')) {
                      return 'Start with http:// or https://';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields() {
    final password = CustomTextField(
      label: _mode == _Mode.login ? 'Password' : 'Choose a password',
      controller: _password,
      hint: _mode == _Mode.login ? null : 'At least 8 characters',
      validator: _mode == _Mode.login
          ? (v) => _required(v, 'your password')
          : _passwordRule,
      obscureText: _hidePassword,
      suffix: IconButton(
        tooltip: _hidePassword ? 'Show password' : 'Hide password',
        icon: Icon(
          _hidePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => _hidePassword = !_hidePassword),
      ),
    );
    final confirm = CustomTextField(
      label: 'Confirm password',
      controller: _confirm,
      obscureText: _hidePassword,
      textInputAction: TextInputAction.done,
      validator: (v) => v != _password.text ? 'Passwords do not match' : null,
    );

    return switch (_mode) {
      _Mode.login => [
        CustomTextField(
          label: 'Mobile number or email',
          controller: _identifier,
          hint: '98765 43210',
          keyboardType: TextInputType.emailAddress,
          validator: (v) => _required(v, 'your mobile number or email'),
        ),
        const SizedBox(height: Gap.md),
        password,
      ],
      _Mode.register => [
        CustomTextField(
          label: 'Tuition name',
          controller: _tuitionName,
          hint: 'e.g. Bright Future Classes',
          textCapitalization: TextCapitalization.words,
          validator: (v) => _required(v, 'the tuition name'),
        ),
        const SizedBox(height: Gap.md),
        CustomTextField(
          label: 'City',
          controller: _city,
          optional: true,
          hint: 'e.g. Nashik',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: Gap.md),
        CustomTextField(
          label: 'Your name',
          controller: _name,
          hint: 'e.g. Rahul Sharma',
          textCapitalization: TextCapitalization.words,
          validator: (v) => _required(v, 'your name'),
        ),
        const SizedBox(height: Gap.md),
        PhoneField(label: 'Your mobile number', controller: _phone),
        const SizedBox(height: Gap.md),
        CustomTextField(
          label: 'Email',
          controller: _email,
          optional: true,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                ? null
                : 'Enter a valid email';
          },
        ),
        const SizedBox(height: Gap.md),
        password,
        const SizedBox(height: Gap.md),
        confirm,
      ],
      _Mode.invite => [
        PhoneField(label: 'Your mobile number', controller: _phone),
        const SizedBox(height: Gap.md),
        CustomTextField(
          label: 'Invite code',
          controller: _code,
          hint: 'e.g. K7P2QM',
          textCapitalization: TextCapitalization.characters,
          validator: (v) => _required(v, 'the invite code'),
        ),
        const SizedBox(height: Gap.md),
        password,
        const SizedBox(height: Gap.md),
        confirm,
      ],
    };
  }
}
