import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/app_scope.dart';
import '../../shared/widgets/widgets.dart';
import '../fees/fee_widgets.dart';

class TuitionInfoScreen extends StatefulWidget {
  const TuitionInfoScreen({super.key});

  @override
  State<TuitionInfoScreen> createState() => _TuitionInfoScreenState();
}

class _TuitionInfoScreenState extends State<TuitionInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _city, _address, _phone, _email;

  @override
  void initState() {
    super.initState();
    final t = context.appRead.tuition;
    _name = TextEditingController(text: t.name);
    _city = TextEditingController(text: t.city);
    _address = TextEditingController(text: t.address);
    _phone = TextEditingController(text: t.phone);
    _email = TextEditingController(text: t.email);
  }

  @override
  void dispose() {
    for (final c in [_name, _city, _address, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final app = context.appRead;
    app.tuition
      ..name = _name.text.trim()
      ..city = _city.text.trim()
      ..address = _address.text.trim()
      ..phone = _phone.text.trim()
      ..email = _email.text.trim();
    app.touch();
    Navigator.of(context).pop();
    AppToast.show(context, 'Tuition information saved');
  }

  @override
  Widget build(BuildContext context) {
    if (!context.app.isAdmin) return const AdminOnlyNotice();
    return AppScaffold(
      title: 'Tuition information',
      bottomBar: PrimaryButton(
        label: 'Save',
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          children: [
            CustomTextField(
              label: 'Tuition name',
              controller: _name,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(label: 'City', controller: _city),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Address',
              controller: _address,
              maxLines: 3,
            ),
            const SizedBox(height: Gap.md),
            PhoneField(label: 'Contact number', controller: _phone),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: Gap.lg),
            const DemoNotice(
              text:
                  'The tuition name is used in parent messages. Changes last until the app restarts.',
            ),
          ],
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _email, _phone;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    _name = TextEditingController(text: app.userName);
    _email = TextEditingController(text: app.userEmail);
    _phone = TextEditingController(text: app.userPhone);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final app = context.appRead;
    if (app.isAdmin) {
      app.admin
        ..name = _name.text.trim()
        ..email = _email.text.trim()
        ..phone = _phone.text.trim();
      app.touch();
    } else {
      final m = app.currentStaff!;
      app.staff.update(
        m,
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        designation: m.designation,
        classIds: m.assignedClassIds,
        isActive: m.isActive,
      );
    }
    Navigator.of(context).pop();
    AppToast.show(context, 'Profile updated');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Edit profile',
      bottomBar: PrimaryButton(
        label: 'Save',
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Email',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: Gap.md),
            PhoneField(label: 'Phone', controller: _phone),
            const SizedBox(height: Gap.lg),
            const DemoNotice(
              text:
                  'Password and sign-in settings will be available once real accounts are connected.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic toggle list backed by an in-memory preference map.
class _PrefsScreen extends StatelessWidget {
  const _PrefsScreen({
    required this.title,
    required this.prefs,
    required this.note,
  });

  final String title;
  final Map<String, bool> prefs;
  final String note;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return AppScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          for (final key in prefs.keys)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: prefs[key]!,
              onChanged: (v) {
                prefs[key] = v;
                app.touch();
              },
              title: Text(
                key,
                style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
              ),
            ),
          const SizedBox(height: Gap.md),
          DemoNotice(text: note),
        ],
      ),
    );
  }
}

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final prefs = app.notificationPrefs;
    if (!app.isAdmin) {
      // Staff never receive payment notifications.
      return _PrefsScreen(
        title: 'Notification preferences',
        prefs: Map.fromEntries(
          prefs.entries.where((e) => e.key != 'Payments recorded'),
        ),
        note:
            'In-app only in this demo. Push notifications arrive with the real backend.',
      );
    }
    return _PrefsScreen(
      title: 'Notification preferences',
      prefs: prefs,
      note:
          'In-app only in this demo. Push notifications arrive with the real backend.',
    );
  }
}

class AppPreferencesScreen extends StatelessWidget {
  const AppPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) => _PrefsScreen(
    title: 'App preferences',
    prefs: context.app.appPrefs,
    note: 'Preferences are kept for this session only.',
  );
}
