import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../academic_years/academic_years_screen.dart';
import '../classes/classes_screen.dart';
import '../messaging/sms_settings_screen.dart';
import '../staff/staff_screen.dart';
import 'settings_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Log out?',
      message:
          'You will return to the preview selection. Demo changes made in this session are kept until the app restarts.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
    );
    if (!ok || !context.mounted) return;
    final app = context.appRead;
    Navigator.of(context).popUntil((r) => r.isFirst);
    app.signOut();
  }

  void _showClasses(BuildContext context) {
    final app = context.appRead;
    showAppSheet<void>(
      context,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Assigned classes',
              subtitle: 'Managed by the admin',
            ),
            if (app.visibleClasses.isEmpty)
              const EmptyState(
                compact: true,
                icon: Icons.class_outlined,
                title: 'No classes',
                message: 'You are not assigned to any class yet.',
              )
            else
              for (final c in app.visibleClasses)
                ListTile(
                  leading: const Icon(Icons.class_outlined),
                  title: Text(c.name, style: AppTextStyles.titleSmall),
                  subtitle: Text(
                    '${c.sessionLabel} · ${Fmt.plural(app.rosterFor(c.id).length, 'student')}',
                    style: AppTextStyles.caption,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final isAdmin = app.isAdmin;

    final settings = isAdmin
        ? [
            NavRow(
              icon: Icons.storefront_outlined,
              title: 'Tuition information',
              subtitle: app.tuition.name,
              onTap: () => pushPage(context, const TuitionInfoScreen()),
            ),
            NavRow(
              icon: Icons.calendar_month_outlined,
              title: 'Academic year',
              subtitle: app.currentYear.label,
              onTap: () => pushPage(context, const AcademicYearsScreen()),
            ),
            NavRow(
              icon: Icons.class_outlined,
              title: 'Class configuration',
              subtitle: '${app.academic.runningClasses.length} running',
              onTap: () => pushPage(context, const ClassesScreen()),
            ),
            NavRow(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Staff permissions',
              subtitle: '${app.staff.all.length} staff',
              onTap: () => pushPage(context, const StaffScreen()),
            ),
            NavRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notification preferences',
              onTap: () =>
                  pushPage(context, const NotificationPreferencesScreen()),
            ),
            NavRow(
              icon: Icons.sms_outlined,
              title: 'Messaging settings',
              subtitle: app.messaging.sms.mode.label,
              onTap: () => pushPage(context, const SmsSettingsScreen()),
            ),
            NavRow(
              icon: Icons.person_outline_rounded,
              title: 'Edit profile',
              onTap: () => pushPage(context, const EditProfileScreen()),
            ),
          ]
        : [
            NavRow(
              icon: Icons.person_outline_rounded,
              title: 'Personal profile',
              subtitle: 'Name, email and phone',
              onTap: () => pushPage(context, const EditProfileScreen()),
            ),
            NavRow(
              icon: Icons.class_outlined,
              title: 'Assigned classes',
              subtitle: Fmt.plural(
                app.visibleClasses.length,
                'class',
                'classes',
              ),
              onTap: () => _showClasses(context),
            ),
            NavRow(
              icon: Icons.notifications_none_rounded,
              title: 'Notification preferences',
              onTap: () =>
                  pushPage(context, const NotificationPreferencesScreen()),
            ),
            NavRow(
              icon: Icons.tune_rounded,
              title: 'App preferences',
              onTap: () => pushPage(context, const AppPreferencesScreen()),
            ),
          ];

    return AppScaffold(
      title: 'Profile',
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: CreamCard(
              child: Row(
                children: [
                  AppAvatar(
                    initials: initialsOf(app.userName),
                    seed: app.userName,
                    size: 64,
                    accent: true,
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          app.userName,
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.textOnCream,
                          ),
                        ),
                        Text(
                          app.userRoleLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textOnCreamMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusChip(
                          label: isAdmin ? 'Admin preview' : 'Staff preview',
                          color: isAdmin
                              ? AppColors.accentPressed
                              : AppColors.info,
                          dense: true,
                          onCream: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.page,
              vertical: Gap.sm,
            ),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: app.userEmail,
                ),
                InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: Fmt.phone(app.userPhone),
                ),
                InfoRow(
                  icon: Icons.storefront_outlined,
                  label: 'Tuition',
                  value: app.tuition.name,
                ),
              ],
            ),
          ),
          SectionHeader(
            title: isAdmin ? 'Admin settings' : 'Settings',
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 4),
          ),
          for (var i = 0; i < settings.length; i++) ...[
            if (i > 0) const InsetDivider(indent: 76),
            settings[i],
          ],
          const SectionHeader(
            title: 'Demo',
            padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 4),
          ),
          NavRow(
            icon: Icons.switch_account_outlined,
            title: 'Switch preview role',
            subtitle: 'Return to the admin / staff selector',
            color: AppColors.info,
            onTap: () {
              final a = context.appRead;
              Navigator.of(context).popUntil((r) => r.isFirst);
              a.signOut();
            },
          ),
          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: SecondaryButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              color: AppColors.error,
              onPressed: () => _logout(context),
            ),
          ),
          const SizedBox(height: Gap.md),
          Center(
            child: Text(
              'Role previews are for the demo only and are not security.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
