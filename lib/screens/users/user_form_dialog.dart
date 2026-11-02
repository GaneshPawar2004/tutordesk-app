import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Add / edit staff user dialog (screens 17 & 19). Returns true when saved.
Future<bool?> showUserFormDialog(BuildContext context, {StaffUser? user}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _UserFormDialog(user: user),
  );
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.user});
  final StaffUser? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _subject = TextEditingController(text: widget.user?.subject);
  late final _phone = TextEditingController(text: widget.user?.phone);
  late final _email = TextEditingController(text: widget.user?.email);
  final _password = TextEditingController();
  late final _salary = TextEditingController(
    text: widget.user?.salary == null
        ? ''
        : widget.user!.salary!.toStringAsFixed(0),
  );
  late bool _canAccessFees = widget.user?.canAccessFees ?? false;
  bool _obscure = true;

  bool get _isEdit => widget.user != null;

  @override
  void dispose() {
    for (final c in [_name, _subject, _phone, _email, _password, _salary]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final body = {
      'name': _name.text.trim(),
      'subject': _subject.text.trim(),
      'phone': _phone.text.trim(),
      'email': _email.text.trim().toLowerCase(),
      'salary': double.tryParse(_salary.text.trim()),
      'canAccessFees': _canAccessFees,
      if (_password.text.isNotEmpty) 'password': _password.text,
    };
    final ok = await runApi(
      context,
      () => _isEdit
          ? appState.updateUser(widget.user!, body)
          : appState.addUser(body),
    );
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(15, 15, 15, 9),
                  children: [
                    _field(
                      label: 'Full name',
                      required: true,
                      hint: "User's name",
                      icon: Icons.person_outline,
                      controller: _name,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    _field(
                      label: 'Subject',
                      hint: 'e.g. Mathematics',
                      icon: Icons.menu_book_outlined,
                      controller: _subject,
                    ),
                    _field(
                      label: 'Phone',
                      hint: 'Phone number',
                      icon: Icons.call_outlined,
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return null;
                        return isValidMobile(value)
                            ? null
                            : 'Enter a valid 10-digit number';
                      },
                    ),
                    const Divider(height: 15),
                    const Padding(
                      padding: EdgeInsets.only(top: 6, bottom: 8),
                      child: Text(
                        'LOGIN CREDENTIALS',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    _field(
                      label: 'Login email',
                      required: true,
                      hint: 'Email used to sign in',
                      icon: Icons.mail_outline,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (!isValidEmail(value)) return 'Enter a valid email';
                        final taken = appState.users.any(
                          (u) =>
                              u.email.toLowerCase() == value.toLowerCase() &&
                              u != widget.user,
                        );
                        return taken ? 'This email is already used' : null;
                      },
                    ),
                    _field(
                      label: _isEdit ? 'New password' : 'Password',
                      required: !_isEdit,
                      hint: _isEdit
                          ? 'Leave blank to keep current'
                          : 'Min 6 characters',
                      icon: Icons.lock_outline,
                      controller: _password,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.textMuted,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) {
                        final value = v ?? '';
                        if (_isEdit && value.isEmpty) return null;
                        return value.length < 6 ? 'Min 6 characters' : null;
                      },
                    ),
                    _field(
                      label: 'Salary (₹)',
                      hint: 'Monthly salary',
                      icon: Icons.payments_outlined,
                      controller: _salary,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return null;
                        return double.tryParse(value) == null
                            ? 'Enter a valid amount'
                            : null;
                      },
                    ),
                    _feesSwitch(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 9, 15, 15),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextButton(
                        onPressed: _save,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                        ),
                        child: Text(
                          _isEdit ? 'UPDATE USER' : 'SAVE USER',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 21, 9, 21),
      decoration: const BoxDecoration(gradient: AppColors.buttonGradient),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person_add_alt_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit User' : 'Add User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Create a staff member & login',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool required = false,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 6),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
                children: [
                  TextSpan(text: label.toUpperCase()),
                  if (required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xFFD32F2F)),
                    ),
                ],
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.hint),
              filled: true,
              fillColor: AppColors.fieldFill,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Icon(icon, color: AppColors.textMuted),
              ),
              suffixIcon: suffix,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              enabledBorder: border(AppColors.fieldBorder),
              focusedBorder: border(AppColors.primary),
              errorBorder: border(AppColors.danger),
              focusedErrorBorder: border(AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _feesSwitch() {
    return Container(
      margin: const EdgeInsets.only(top: 3, bottom: 6),
      padding: const EdgeInsets.fromLTRB(18, 9, 9, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE0F5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can access Fees',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  'View & collect student fees',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _canAccessFees,
            onChanged: (v) => setState(() => _canAccessFees = v),
          ),
        ],
      ),
    );
  }
}
