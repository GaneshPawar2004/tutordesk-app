import 'package:flutter/material.dart';

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
            validator: (v) =>
                (v ?? '').trim().length < 2 ? 'Enter at least 2 letters' : null,
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
