import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../academic_years/academic_years_screen.dart';
import '../classes/classes_screen.dart';
import '../exams/exams_screen.dart';
import '../fees/fees_dashboard_screen.dart';
import '../messaging/messages_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart';
import '../staff/staff_screen.dart';

/// Additional features, filtered by role and permissions.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final isAdmin = app.isAdmin;
    final unread = app.notifications.unreadCount(isAdmin: isAdmin);

    final manage = <Widget>[
      if (isAdmin)
        NavRow(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Fees & payments',
          subtitle: 'Collections, dues and payment records',
          color: AppColors.warning,
          onTap: () => pushPage(context, const FeesDashboardScreen()),
        ),
      if (isAdmin)
        NavRow(
          icon: Icons.badge_outlined,
          title: 'Staff',
          subtitle: 'Team, assigned classes and permissions',
          onTap: () => pushPage(context, const StaffScreen()),
        ),
      if (app.can(StaffPermission.viewExamResults) ||
          app.can(StaffPermission.enterMarks))
        NavRow(
          icon: Icons.assignment_outlined,
          title: 'Exams & marks',
          subtitle: isAdmin
              ? 'Create exams, enter marks, publish results'
              : 'Exams for your classes',
          color: AppColors.info,
          onTap: () => pushPage(context, const ExamsScreen()),
        ),
      if (app.canOpenMessages)
        NavRow(
          icon: Icons.forum_outlined,
          title: 'Messages',
          subtitle: app.canSendMessages
              ? 'Parent messages and SMS batches'
              : 'View batches · sending disabled',
          color: AppColors.info,
          onTap: () => pushPage(context, const MessagesScreen()),
        ),
      NavRow(
        icon: Icons.insert_chart_outlined_rounded,
        title: 'Reports',
        subtitle: isAdmin
            ? 'Enrollment, attendance, fees and results'
            : 'Attendance and results for your classes',
        color: AppColors.success,
        onTap: () => pushPage(context, const ReportsScreen()),
      ),
    ];

    final setup = <Widget>[
      if (isAdmin)
        NavRow(
          icon: Icons.class_outlined,
          title: 'Classes',
          subtitle: 'Batches, timings and assigned staff',
          onTap: () => pushPage(context, const ClassesScreen()),
        ),
      if (isAdmin)
        NavRow(
          icon: Icons.calendar_month_outlined,
          title: 'Academic years & promotion',
          subtitle: 'Years, enrollments and promoting students',
          onTap: () => pushPage(context, const AcademicYearsScreen()),
        ),
      NavRow(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: unread == 0 ? 'All caught up' : '$unread unread',
        color: AppColors.accent,
        onTap: () => pushPage(context, const NotificationsScreen()),
      ),
      NavRow(
        icon: Icons.settings_outlined,
        title: isAdmin ? 'Profile & settings' : 'Profile & preferences',
        subtitle: app.userName,
        color: AppColors.textSecondary,
        onTap: () => pushPage(context, const ProfileScreen()),
      ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        AppHeader(
          eyebrow: app.tuition.name,
          title: 'More',
          subtitle: isAdmin
              ? 'Everything else for running your tuition'
              : 'Tools available to you',
        ),
        const SectionHeader(
          title: 'Manage',
          padding: EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 4),
        ),
        ..._divided(manage),
        const SectionHeader(
          title: 'Setup & account',
          padding: EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 4),
        ),
        ..._divided(setup),
        if (!isAdmin) ...[
          const SizedBox(height: Gap.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: DemoNotice(
              icon: Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              text:
                  'Fees, staff and settings are managed by the tuition admin. '
                  'Ask ${app.admin.firstName} if you need access to more tools.',
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Center(
          child: Text(
            'TutorDesk · Static UI preview',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _divided(List<Widget> rows) => [
    for (var i = 0; i < rows.length; i++) ...[
      if (i > 0) const InsetDivider(indent: 76),
      rows[i],
    ],
  ];
}
