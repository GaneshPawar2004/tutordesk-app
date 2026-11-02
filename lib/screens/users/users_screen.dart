import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../students/students_view.dart' show StatusBadge;
import 'user_form_dialog.dart';

/// Staff logins (screens 16-19).
class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  Future<void> _toggle(BuildContext context, StaffUser u) async {
    if (u.active) {
      final ok = await confirmDialog(
        context,
        title: 'Block ${u.name}?',
        message: 'They will no longer be able to sign in.',
        confirmLabel: 'BLOCK',
      );
      if (!ok || !context.mounted) return;
    }
    final allowed = await runApiValue(
      context,
      () => appState.toggleUserActive(u),
    );
    if (allowed == null || !context.mounted) return;
    if (!allowed) {
      showNotice(
        context,
        'Your plan includes ${appState.staffLoginLimit} staff login(s). '
        'Add staff logins for ₹500/user per year from Subscriptions to '
        'activate ${u.name}.',
        title: 'Upgrade required',
      );
      return;
    }
    showSuccess(
      context,
      u.active ? '${u.name} activated' : '${u.name} blocked',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await showUserFormDialog(context);
          if (saved == true && context.mounted) {
            showSuccess(context, 'User added successfully!');
          }
        },
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final limit = appState.staffLoginLimit;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${appState.activeUserCount}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' of '),
                    TextSpan(
                      text: '$limit',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text:
                          ' staff logins active — the admin login is always included and not counted here. Only ',
                    ),
                    const TextSpan(
                      text: 'Active',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: ' staff can sign in. '),
                    if (limit == 0)
                      const TextSpan(
                        text:
                            'Your plan includes only the admin login — add staff logins for ₹500/user per year from Subscriptions.',
                        style: TextStyle(color: Color(0xFFD32F2F)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (appState.users.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 75),
                  child: EmptyState(
                    icon: Icons.person_off_outlined,
                    message: 'No users yet. Tap + to add.',
                  ),
                ),
              for (final u in appState.users) ...[
                _UserCard(
                  user: u,
                  onToggle: () => _toggle(context, u),
                  onEdit: () async {
                    final saved = await showUserFormDialog(context, user: u);
                    if (saved == true && context.mounted) {
                      showSuccess(context, 'User updated successfully!');
                    }
                  },
                  onDelete: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Delete ${u.name}?',
                      message: 'This staff login will be removed.',
                    );
                    if (ok && context.mounted) {
                      if (await runApi(context, () => appState.deleteUser(u)) &&
                          context.mounted) {
                        showSuccess(context, 'User deleted');
                      }
                    }
                  },
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffUser user;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 9, 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Text(
                      u.name.isEmpty ? '?' : u.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 23),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(u.name, style: const TextStyle(fontSize: 16)),
                      u.active
                          ? const StatusBadge(
                              label: 'Active',
                              color: AppColors.successDark,
                              background: Color(0xFFE8F5E9),
                            )
                          : const StatusBadge(
                              label: 'Blocked',
                              color: Color(0xFFB26A00),
                              background: Color(0xFFFFF0D9),
                            ),
                    ],
                  ),
                  Text(u.email, style: const TextStyle(fontSize: 14)),
                  if (u.subject.isNotEmpty)
                    Text(
                      u.subject,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: u.active ? 'Block' : 'Activate',
              icon: Icon(
                u.active ? Icons.block : Icons.check_circle_outline,
                color: u.active
                    ? const Color(0xFFB26A00)
                    : AppColors.successDark,
              ),
              onPressed: onToggle,
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, color: Color(0xFFD32F2F)),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
