import 'package:flutter/material.dart';

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
    if (picked == null) return;
    app.staff.update(
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
          if (pending) ...[
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
              onPressed: () => app.staff.markInvitationAccepted(member),
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
            'Changes apply immediately in the demo.',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 4),
          for (final p in StaffPermission.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: member.permissions.contains(p),
              onChanged: (v) {
                app.setStaffPermission(member, p, v);
                if (p == StaffPermission.sendSms && !v) {
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
            onChanged: (v) => app.staff.update(
              member,
              name: member.name,
              email: member.email,
              phone: member.phone,
              designation: member.designation,
              classIds: member.assignedClassIds,
              isActive: v,
            ),
            title: Text('Account active', style: AppTextStyles.titleSmall),
            subtitle: Text(
              'Inactive staff lose access to every module.',
              style: AppTextStyles.caption,
            ),
          ),
          const SizedBox(height: Gap.md),
          if (member.isActive)
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
