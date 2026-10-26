import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../fees/fee_widgets.dart';
import 'staff_detail_screen.dart';
import 'staff_form_screen.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final staff = app.staff.all;
    final active = staff.where((s) => s.isActive).length;
    final pending = staff
        .where((s) => s.accountStatus == AccountStatus.invitationPending)
        .length;

    return AppScaffold(
      title: 'Staff',
      subtitle: app.tuition.name,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushPage(context, const StaffFormScreen()),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('Add staff', style: AppTextStyles.button),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 96),
        children: [
          CreamCard(
            child: Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: 'Team',
                    value: '${staff.length}',
                    onCream: true,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Active',
                    value: '$active',
                    onCream: true,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Invites pending',
                    value: '$pending',
                    onCream: true,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const DemoNotice(
            icon: Icons.lock_outline_rounded,
            color: AppColors.warning,
            text:
                'Fees, payments and financial reports are admin-only and cannot be granted to staff.',
          ),
          const SizedBox(height: Gap.md),
          if (staff.isEmpty)
            EmptyState(
              icon: Icons.badge_outlined,
              title: 'No staff yet',
              message:
                  'Add teachers and front-desk staff, then choose what each person can access.',
              actionLabel: 'Add staff',
              onAction: () => pushPage(context, const StaffFormScreen()),
            )
          else
            for (final s in staff)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: StaffListTile(
                  member: s,
                  classNames: s.assignedClassIds
                      .map((id) => app.academic.classById(id).name)
                      .toList(),
                  onTap: () =>
                      pushPage(context, StaffDetailScreen(staffId: s.id)),
                ),
              ),
        ],
      ),
    );
  }
}
