import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import 'plan_screens.dart';

/// My Profile: name, institute name (owner), password, delete account, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editText(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) save,
    bool optional = false,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            maxLines: maxLines,
            validator: (v) => !optional && (v ?? '').trim().length < 2
                ? 'Enter at least 2 letters'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (value == null || value == initial || !context.mounted) return;
    if (await runApi(context, () => save(value)) && context.mounted) {
      showSuccess(context, 'Saved');
    }
  }

  Future<void> _changeLogo(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose logo from gallery'),
              onTap: () => Navigator.pop(ctx, 'pick'),
            ),
            if (appState.logoUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text('Remove logo'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'remove') {
      await runApi(context, appState.removeLogo);
      return;
    }
    final file = await ImagePicker()
        .pickImage(
          source: ImageSource.gallery,
          maxWidth: 400,
          maxHeight: 400,
          imageQuality: 85,
        )
        .catchError((_) => null);
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    if (await runApi(context, () => appState.uploadLogo(bytes)) &&
        context.mounted) {
      showSuccess(context, 'Logo saved — it will appear on receipts.');
    }
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) =>
                    (v ?? '').length < 6 ? 'At least 6 characters' : null,
              ),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (v) =>
                    v != next.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('CHANGE'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (await runApi(
          context,
          () => appState.changePassword(current.text, next.text),
        ) &&
        context.mounted) {
      showSuccess(context, 'Password changed. Other devices were signed out.');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your institute with all classes, '
              'students, attendance, marks, fees and staff logins. '
              'It cannot be undone.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Enter your password to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true || password.text.isEmpty || !context.mounted) return;
    if (await runApi(context, () => appState.deleteAccount(password.text)) &&
        context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      showSuccess(context, 'Your account was deleted.');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'LOGOUT',
    );
    if (!ok || !context.mounted) return;
    await appState.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const SizedBox(height: 6),
            const Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 40),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                appState.userName ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Center(
              child: Text(
                '${appState.isOwner ? 'Admin' : 'Staff'} · ${appState.userEmail ?? ''}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 15),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Your name'),
                    subtitle: Text(appState.userName ?? ''),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _editText(
                      context,
                      title: 'Your name',
                      initial: appState.userName ?? '',
                      save: (v) => appState.updateProfile(name: v),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: const Text('Institute name'),
                    subtitle: Text(appState.instituteName),
                    trailing: appState.isOwner
                        ? const Icon(Icons.edit_outlined, size: 20)
                        : null,
                    onTap: appState.isOwner
                        ? () => _editText(
                            context,
                            title: 'Institute name',
                            initial: appState.instituteName,
                            save: (v) =>
                                appState.updateProfile(instituteName: v),
                          )
                        : null,
                  ),
                  if (appState.isOwner) ...[
                    ListTile(
                      leading: const Icon(Icons.call_outlined),
                      title: const Text('Institute phone'),
                      subtitle: Text(
                        appState.institutePhone.isEmpty
                            ? 'Shown on receipts'
                            : appState.institutePhone,
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editText(
                        context,
                        title: 'Institute phone',
                        initial: appState.institutePhone,
                        optional: true,
                        save: (v) => appState.updateProfile(institutePhone: v),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: const Text('Institute address'),
                      subtitle: Text(
                        appState.instituteAddress.isEmpty
                            ? 'Shown on receipts'
                            : appState.instituteAddress,
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () => _editText(
                        context,
                        title: 'Institute address',
                        initial: appState.instituteAddress,
                        optional: true,
                        maxLines: 3,
                        save: (v) =>
                            appState.updateProfile(instituteAddress: v),
                      ),
                    ),
                    ListTile(
                      leading: const _LogoThumb(),
                      title: const Text('Institute logo'),
                      subtitle: Text(
                        appState.logoUrl == null
                            ? 'Add a logo for receipts'
                            : 'Shown on PDF receipts · tap to change',
                      ),
                      onTap: () => _changeLogo(context),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.calendar_month_outlined),
                      title: const Text('Monthly fees system'),
                      subtitle: const Text(
                        'Students can have a monthly fee that is added every month.',
                      ),
                      value: appState.monthlyFees,
                      onChanged: (v) => runApi(
                        context,
                        () => appState.updateProfile(monthlyFees: v),
                      ),
                    ),
                  ],
                  ListTile(
                    leading: const Icon(Icons.workspace_premium_outlined),
                    title: const Text('Subscription'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _changePassword(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: () => _logout(context),
                  ),
                  if (appState.isOwner)
                    ListTile(
                      leading: const Icon(
                        Icons.delete_forever_outlined,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Delete account',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () => _deleteAccount(context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small preview of the institute logo (or a placeholder icon).
class _LogoThumb extends StatelessWidget {
  const _LogoThumb();

  @override
  Widget build(BuildContext context) {
    final url = appState.logoUrl;
    if (url == null) return const Icon(Icons.image_outlined);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        url,
        headers: appState.authHeaders,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(Icons.image_outlined),
      ),
    );
  }
}
