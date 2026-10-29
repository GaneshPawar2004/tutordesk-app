import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../fees/fee_widgets.dart';
import 'staff_form_screen.dart';

/// Staff profile with live permission toggles. Changes apply immediately to
/// that staff member's preview.
class StaffDetailScreen extends StatelessWidget {
  const StaffDetailScreen({super.key, required this.staffId});

  final String staffId;

  Future<void> _editClasses(BuildContext context, StaffMember member) async {
    final app = context.appRead;
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Assigned classes',
      options: [
        for (final c in app.academic.runningClasses)
          SelectOption(c.id, c.name, subtitle: c.sessionLabel),
      ],
      selected: member.assignedClassIds.toSet(),
    );
    if (picked == null || !context.mounted) return;
    await runAction(
      context,
      () => app.updateStaff(
        member,
        name: member.name,
        email: member.email,
        phone: member.phone,
        designation: member.designation,
        classIds: app.academic.classes
            .where((c) => picked.contains(c.id))
            .map((c) => c.id)
            .toList(),
        isActive: member.isActive,
      ),
      success: 'Assigned classes updated',
    );
  }

  Future<void> _preview(BuildContext context, StaffMember member) async {
    final app = context.appRead;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Preview as ${member.firstName}?',
      message:
          'Switches the demo to ${member.firstName}\'s staff view so you can check what they see. '
          'Use Profile → Switch preview to come back.',
      confirmLabel: 'Switch preview',
      icon: Icons.visibility_outlined,
    );
    if (!ok || !context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.signInAsStaff(member.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final member = app.staff.byId(staffId);
    final pending = member.accountStatus == AccountStatus.invitationPending;

    return AppScaffold(
      title: member.name,
      subtitle: member.designation,
      actions: [
        IconButton(
          tooltip: 'Edit staff details',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => pushPage(context, StaffFormScreen(member: member)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          Row(
            children: [
              AppAvatar(initials: member.initials, seed: member.id, size: 64),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: AppTextStyles.title),
                    Text(member.designation, style: AppTextStyles.caption),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActiveStatusChip(active: member.isActive),
                        if (pending)
                          const StatusChip(
                            label: 'Invitation pending',
                            color: AppColors.warning,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          InfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: Fmt.phone(member.phone),
          ),
          InfoRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: member.email,
          ),
          InfoRow(
            icon: Icons.event_outlined,
            label: 'Joined',
            value: Fmt.date(member.joinedOn),
          ),
          InfoRow(
            icon: Icons.verified_user_outlined,
            label: 'Account',
            value: member.accountStatus.label,
          ),
          if (pending && app.isRemote) ...[
            const SizedBox(height: 12),
            _InviteCodeCard(member: member),
          ] else if (pending) ...[
            const SizedBox(height: 8),
            DemoNotice(
              icon: Icons.mark_email_unread_outlined,
              color: AppColors.warning,
              text:
                  'Account setup is pending. ${member.firstName} sets their own password when accepting the '
                  'invitation — passwords are never shown or stored here.',
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Mark invitation accepted (demo)',
              icon: Icons.how_to_reg_outlined,
              onPressed: () => app.resetInvite(member),
            ),
          ] else if (app.isRemote) ...[
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Reset password (new invite code)',
              icon: Icons.key_rounded,
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: "Reset ${member.firstName}'s password?",
                  message:
                      'Their current password stops working. A new invite code is created so they can set a new password.',
                  confirmLabel: 'Reset',
                  destructive: true,
                  icon: Icons.key_rounded,
                );
                if (ok && context.mounted) {
                  await runAction(
                    context,
                    () => app.resetInvite(member),
                    success: 'New invite code created',
                  );
                }
              },
            ),
          ],
          SectionHeader(
            title: 'Assigned classes',
            padding: const EdgeInsets.only(top: Gap.lg, bottom: 8),
            actionLabel: 'Edit',
            onAction: () => _editClasses(context, member),
          ),
          if (member.assignedClassIds.isEmpty)
            Text('No classes assigned.', style: AppTextStyles.caption)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in member.assignedClassIds)
                  Chip(label: Text(app.academic.classById(id).name)),
              ],
            ),
          const SectionHeader(
            title: 'Permissions',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
          ),
          Text(
            app.isRemote
                ? 'Changes apply on their very next action.'
                : 'Changes apply immediately in the demo.',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final p in StaffPermission.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: member.permissions.contains(p),
              onChanged: (v) async {
                final ok = await runAction(
                  context,
                  () => app.setStaffPermission(member, p, v),
                );
                if (ok &&
                    context.mounted &&
                    p == StaffPermission.sendSms &&
                    !v) {
                  AppToast.show(
                    context,
                    '${member.firstName} will no longer see Send Messages actions',
                    type: ToastType.info,
                  );
                }
              },
              title: Text(
                p.label,
                style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
              ),
              subtitle: Text(
                p.description,
                style: AppTextStyles.caption.copyWith(fontSize: 12.5),
              ),
            ),
          const Divider(height: Gap.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const IconWell(
              icon: Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              size: 40,
            ),
            title: Text(
              'Fees & financial reports',
              style: AppTextStyles.titleSmall.copyWith(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
            subtitle: Text(
              'Admin only · cannot be granted to staff',
              style: AppTextStyles.caption.copyWith(fontSize: 12.5),
            ),
            trailing: const Switch(value: false, onChanged: null),
          ),
          const SizedBox(height: Gap.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: member.isActive,
            onChanged: (v) => runAction(
              context,
              () => app.updateStaff(
                member,
                name: member.name,
                email: member.email,
                phone: member.phone,
                designation: member.designation,
                classIds: member.assignedClassIds,
                isActive: v,
              ),
            ),
            title: Text('Account active', style: AppTextStyles.titleSmall),
            subtitle: Text(
              'Inactive staff lose access to every module.',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: Gap.md),
          if (member.isActive && !app.isRemote)
            PrimaryButton(
              label: 'Preview as ${member.firstName}',
              icon: Icons.visibility_outlined,
              onPressed: () => _preview(context, member),
            ),
        ],
      ),
    );
  }
}

/// Shows the invite code the admin shares with a new staff member.
class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.member});

  final StaffMember member;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final code = member.inviteCode ?? '-';
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INVITE CODE',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textOnCreamMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.textOnCream,
                    fontSize: 32,
                    letterSpacing: 4,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(
                  Icons.copy_rounded,
                  color: AppColors.textOnCream,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppToast.show(context, 'Invite code copied');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this code with ${member.firstName}. On their phone: open TutorDesk, choose '
            '"I have an invite code", then enter ${Fmt.phone(member.phone)}, this code and a new password.',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnCreamMuted,
            ),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Create a new code',
            icon: Icons.refresh_rounded,
            onPressed: () => runAction(
              context,
              () => app.resetInvite(member),
              success: 'New invite code created',
            ),
          ),
        ],
      ),
    );
  }
}
