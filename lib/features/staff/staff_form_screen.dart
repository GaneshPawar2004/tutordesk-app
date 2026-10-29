import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../fees/fee_widgets.dart';
import 'staff_detail_screen.dart';

class StaffFormScreen extends StatefulWidget {
  const StaffFormScreen({super.key, this.member});

  final StaffMember? member;

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _designation = TextEditingController();
  var _classIds = <String>{};
  var _active = true;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    if (m != null) {
      _name.text = m.name;
      _email.text = m.email;
      _phone.text = m.phone;
      _designation.text = m.designation;
      _classIds = m.assignedClassIds.toSet();
      _active = m.isActive;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _pickClasses() async {
    final app = context.appRead;
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Assigned classes',
      options: [
        for (final c in app.academic.runningClasses)
          SelectOption(c.id, c.name, subtitle: c.sessionLabel),
      ],
      selected: _classIds,
    );
    if (picked != null) setState(() => _classIds = picked);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final app = context.appRead;
    final classIds = app.academic.classes
        .where((c) => _classIds.contains(c.id))
        .map((c) => c.id)
        .toList();
    final m = widget.member;
    setState(() => _saving = true);
    if (m != null) {
      final ok = await runAction(
        context,
        () => app.updateStaff(
          m,
          name: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          designation: _designation.text.trim(),
          classIds: classIds,
          isActive: _active,
        ),
      );
      if (!mounted) return;
      if (!ok) return setState(() => _saving = false);
      Navigator.of(context).pop();
      AppToast.show(context, 'Staff details updated');
      return;
    }
    StaffMember? member;
    final ok = await runAction(context, () async {
      member = await app.addStaff(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        designation: _designation.text.trim(),
        classIds: classIds,
        isActive: _active,
      );
    });
    if (!mounted) return;
    if (!ok || member == null) return setState(() => _saving = false);
    replacePage(context, StaffDetailScreen(staffId: member!.id));
    AppToast.show(
      context,
      app.isRemote
          ? 'Staff added · share the invite code shown on their page'
          : 'Staff added · invitation pending (demo — no email sent)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final isEdit = widget.member != null;

    return AppScaffold(
      title: isEdit ? 'Edit staff' : 'Add staff',
      bottomBar: PrimaryButton(
        label: isEdit ? 'Save changes' : 'Add & send invite',
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          children: [
            CustomTextField(
              label: 'Full name',
              controller: _name,
              hint: 'e.g. Sneha Kulkarni',
              textCapitalization: TextCapitalization.words,
              validator: (v) => (v ?? '').trim().split(' ').length < 2
                  ? 'Enter first and last name'
                  : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Role / designation',
              controller: _designation,
              hint: 'e.g. Mathematics teacher',
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a role' : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Email',
              controller: _email,
              hint: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch((v ?? '').trim())
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: Gap.md),
            PhoneField(label: 'Phone number', controller: _phone),
            const SizedBox(height: Gap.md),
            const FieldLabel('Assigned classes'),
            SecondaryButton(
              label: _classIds.isEmpty
                  ? 'Choose classes'
                  : app.academic.classes
                        .where((c) => _classIds.contains(c.id))
                        .map((c) => c.name)
                        .join(', '),
              icon: Icons.class_outlined,
              onPressed: _pickClasses,
            ),
            const SizedBox(height: Gap.md),
            const FieldLabel('Status'),
            SegmentedChoice<bool>(
              options: const [
                SelectOption(true, 'Active'),
                SelectOption(false, 'Inactive'),
              ],
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: Gap.lg),
            DemoNotice(
              icon: Icons.mark_email_unread_outlined,
              color: AppColors.info,
              text: isEdit
                  ? 'Passwords are managed by each staff member and are never visible here.'
                  : 'The staff member will appear as "Invitation pending" and set their own password when they accept. '
                        'No email or password is created in this demo. Permissions can be adjusted after saving.',
            ),
          ],
        ),
      ),
    );
  }
}
