import 'package:flutter/material.dart';

import '../../core/navigation/app_shell.dart';
import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../exams/exams_screen.dart';
import '../fees/fees_dashboard_screen.dart';
import '../messaging/messages_screen.dart';
import '../staff/staff_screen.dart';
import '../students/student_directory_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static (IconData, Color) _style(NotificationType t) => switch (t) {
    NotificationType.attendance => (
      Icons.fact_check_outlined,
      AppColors.success,
    ),
    NotificationType.exam => (
      Icons.assignment_turned_in_outlined,
      AppColors.info,
    ),
    NotificationType.student => (
      Icons.person_add_alt_outlined,
      AppColors.accent,
    ),
    NotificationType.messageFailed => (
      Icons.sms_failed_outlined,
      AppColors.error,
    ),
    NotificationType.payment => (
      Icons.currency_rupee_rounded,
      AppColors.warning,
    ),
    NotificationType.staff => (Icons.badge_outlined, AppColors.accent),
  };

  void _open(BuildContext context, AppNotification n) {
    final app = context.appRead;
    app.markNotificationRead(n).catchError((_) {});
    switch (n.type) {
      case NotificationType.attendance:
        Navigator.of(context).popUntil((r) => r.isFirst);
        AppShell.goTo(context, ShellTab.attendance);
      case NotificationType.exam:
        if (app.can(StaffPermission.viewExamResults)) {
          pushPage(context, const ExamsScreen());
        }
      case NotificationType.student:
        if (app.can(StaffPermission.viewStudents)) {
          pushPage(context, const StudentDirectoryScreen(standalone: true));
        }
      case NotificationType.messageFailed:
        if (app.canOpenMessages) pushPage(context, const MessagesScreen());
      case NotificationType.payment:
        if (app.isAdmin) pushPage(context, const FeesDashboardScreen());
      case NotificationType.staff:
        if (app.isAdmin) pushPage(context, const StaffScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final items = app.notifications.visible(isAdmin: app.isAdmin);
    final unread = items.where((n) => !n.isRead).length;
    final today = items
        .where((n) => Fmt.isSameDay(n.createdAt, app.now))
        .toList();
    final earlier = items
        .where((n) => !Fmt.isSameDay(n.createdAt, app.now))
        .toList();

    return AppScaffold(
      title: 'Notifications',
      subtitle: unread == 0 ? 'All caught up' : '$unread unread',
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: () => runAction(context, app.markAllNotificationsRead),
            child: const Text('Mark all read'),
          ),
      ],
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              message:
                  'Attendance, results, admissions and message alerts will appear here.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Gap.xl),
              children: [
                for (final (title, list) in [
                  ('Today', today),
                  ('Earlier', earlier),
                ])
                  if (list.isNotEmpty) ...[
                    SectionHeader(
                      title: title,
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.md,
                        Gap.page,
                        4,
                      ),
                    ),
                    for (final n in list)
                      _Tile(
                        notification: n,
                        style: _style(n.type),
                        onTap: () => _open(context, n),
                      ),
                  ],
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.notification,
    required this.style,
    required this.onTap,
  });

  final AppNotification notification;
  final (IconData, Color) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Semantics(
      label: '${unread ? 'Unread' : 'Read'}: ${notification.title}',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: unread ? AppColors.accent.withValues(alpha: 0.04) : null,
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.page,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(icon: style.$1, color: style.$2, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTextStyles.titleSmall.copyWith(
                        fontSize: 15,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: unread
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(notification.body, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.relative(notification.createdAt),
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6, left: 8),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
