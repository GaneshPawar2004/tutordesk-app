import 'package:flutter/material.dart';

import '../../core/navigation/app_shell.dart';
import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../attendance/class_attendance_screen.dart';
import '../exams/create_exam_screen.dart';
import '../exams/exam_detail_screen.dart';
import '../exams/exams_screen.dart';
import '../fees/fees_dashboard_screen.dart';
import '../fees/record_payment_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../students/student_form_screen.dart';
import 'academic_year_sheet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final classes = app.visibleClasses;
    final today = app.todayAttendance(classes: classes);
    final exams = app.visibleExams;
    final upcoming =
        exams
            .where((e) => e.statusOn(app.today) == ExamStatus.upcoming)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    final resultsPending = exams
        .where((e) => e.statusOn(app.today) == ExamStatus.completed)
        .length;

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        const _Header(),
        const _YearRow(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: _SummaryCard(today: today, classes: classes),
        ),
        const SectionHeader(title: 'Today'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: _MetricGrid(
            today: today,
            upcomingCount: upcoming.length,
            nextExam: upcoming.isEmpty ? null : upcoming.first,
            resultsPending: resultsPending,
          ),
        ),
        const SectionHeader(title: 'Quick actions'),
        const _QuickActions(),
        SectionHeader(
          title: 'Today\'s activity',
          actionLabel: 'Notifications',
          onAction: () => pushPage(context, const NotificationsScreen()),
        ),
        const _ActivityList(),
        SectionHeader(
          title: 'Upcoming',
          actionLabel: app.can(StaffPermission.viewExamResults)
              ? 'All exams'
              : null,
          onAction: () => pushPage(context, const ExamsScreen()),
        ),
        _Schedule(exams: upcoming),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final unread = app.notifications.unreadCount(isAdmin: app.isAdmin);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Open profile',
            child: GestureDetector(
              onTap: () => pushPage(context, const ProfileScreen()),
              child: AppAvatar(
                initials: initialsOf(app.userName),
                seed: app.userName,
                size: 48,
                accent: true,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.greeting()}, ${app.userFirstName}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  app.tuition.name,
                  style: AppTextStyles.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: unread > 0
                ? 'Notifications, $unread unread'
                : 'Notifications',
            badge: unread > 0,
            onPressed: () => pushPage(context, const NotificationsScreen()),
          ),
        ],
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.md),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterPill(
                label: 'Year',
                value: app.selectedYear.label,
                active: app.selectedYear.id != app.currentYear.id,
                onTap: () => showAcademicYearSheet(context),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (app.isStaff)
            const StatusChip(
              label: 'Staff view',
              color: AppColors.info,
              dense: true,
            )
          else
            Text(Fmt.weekdayDate(app.today), style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.today, required this.classes});

  final TodayAttendance today;
  final List<SchoolClass> classes;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final year = app.selectedYear;
    final students = classes.fold<int>(
      0,
      (sum, c) => sum + app.enrolledCount(c.id, year.id),
    );
    final remaining = classes
        .where((c) => app.todaySession(c.id) == null)
        .map((c) => c.name)
        .toList();
    final progress = today.classesTotal == 0
        ? 0.0
        : today.classesMarked / today.classesTotal;

    return CreamCard(
      onTap: () => AppShell.goTo(context, ShellTab.attendance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (app.isAdmin ? 'Active students' : 'Your students')
                          .toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$students',
                      style: AppTextStyles.display.copyWith(
                        color: AppColors.textOnCream,
                        fontSize: 48,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                    Text(
                      year.label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textOnCream,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    Text(
                      '${classes.length}',
                      style: AppTextStyles.metric.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    Text(
                      app.isAdmin ? 'classes\nrunning' : 'classes\nassigned',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.cream,
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          const Divider(color: AppColors.creamBorder),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Attendance marked today',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textOnCream,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${today.classesMarked} of ${today.classesTotal} classes',
                style: AppTextStyles.amount.copyWith(
                  color: AppColors.textOnCream,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(
            value: progress,
            color: AppColors.accentPressed,
            trackColor: AppColors.creamTrack,
            height: 8,
          ),
          const SizedBox(height: 10),
          Text(
            remaining.isEmpty
                ? 'All classes are done for today.'
                : 'Remaining: ${remaining.join(', ')}',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textOnCreamMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.today,
    required this.upcomingCount,
    required this.nextExam,
    required this.resultsPending,
  });

  final TodayAttendance today;
  final int upcomingCount;
  final Exam? nextExam;
  final int resultsPending;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    void toAttendance() => AppShell.goTo(context, ShellTab.attendance);
    final canExams = app.can(StaffPermission.viewExamResults);

    final cards = <Widget>[
      MetricCard(
        label: 'Present today',
        value: '${today.present}',
        icon: Icons.how_to_reg_outlined,
        color: AppColors.success,
        caption: 'incl. ${today.lateOrLeave} late/leave',
        onTap: toAttendance,
      ),
      MetricCard(
        label: 'Absent today',
        value: '${today.absent}',
        icon: Icons.person_off_outlined,
        color: AppColors.error,
        caption: '${today.notMarked} not marked yet',
        onTap: toAttendance,
      ),
      // Financial card exists only in the admin tree — never built for staff.
      if (app.canSeeFinance)
        Builder(
          builder: (context) {
            final fees = app.feeTotals(yearId: app.currentYear.id);
            return MetricCard(
              label: 'Pending fees',
              value: Fmt.compactCurrency(fees.outstanding),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.warning,
              caption: '${Fmt.compactCurrency(fees.overdue)} overdue',
              onTap: () => pushPage(context, const FeesDashboardScreen()),
            );
          },
        )
      else
        MetricCard(
          label: 'Results pending',
          value: '$resultsPending',
          icon: Icons.edit_note_rounded,
          color: AppColors.warning,
          caption: 'Exams awaiting marks',
          onTap: canExams ? () => pushPage(context, const ExamsScreen()) : null,
        ),
      MetricCard(
        label: 'Upcoming exams',
        value: '$upcomingCount',
        icon: Icons.event_note_outlined,
        color: AppColors.info,
        caption: nextExam == null
            ? 'Nothing scheduled'
            : 'Next: ${Fmt.shortDate(nextExam!.date)}',
        onTap: canExams ? () => pushPage(context, const ExamsScreen()) : null,
      ),
    ];

    Widget row(Widget a, Widget b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      ),
    );

    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: 12),
        row(cards[2], cards[3]),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  Future<void> _markAttendance(BuildContext context) async {
    final app = context.appRead;
    final classes = app.visibleClasses;
    if (classes.isEmpty) {
      AppToast.show(
        context,
        'No classes are assigned to you yet.',
        type: ToastType.info,
      );
      return;
    }
    final picked = await showSelectSheet<String>(
      context,
      title: 'Mark attendance',
      subtitle: Fmt.longDate(app.today),
      options: [
        for (final c in classes)
          SelectOption(
            c.id,
            c.name,
            subtitle: app.todaySession(c.id) == null
                ? 'Not marked · ${c.sessionLabel}'
                : 'Marked · ${c.sessionLabel}',
            icon: app.todaySession(c.id) == null
                ? Icons.radio_button_unchecked
                : Icons.lock_outline_rounded,
          ),
      ],
    );
    if (picked != null && context.mounted) {
      pushPage(context, ClassAttendanceScreen(classId: picked.value));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final actions = <Widget>[
      if (app.isAdmin)
        _QuickAction(
          icon: Icons.person_add_alt_outlined,
          label: 'Add\nStudent',
          onTap: () => pushPage(context, const StudentFormScreen()),
        ),
      if (app.can(StaffPermission.markAttendance))
        _QuickAction(
          icon: Icons.fact_check_outlined,
          label: 'Mark\nAttendance',
          onTap: () => _markAttendance(context),
        ),
      if (app.isAdmin || app.can(StaffPermission.enterMarks))
        _QuickAction(
          icon: Icons.post_add_rounded,
          label: 'Create\nExam',
          onTap: () => pushPage(context, const CreateExamScreen()),
        ),
      if (app.canSeeFinance)
        _QuickAction(
          icon: Icons.currency_rupee_rounded,
          label: 'Record\nPayment',
          onTap: () => pushPage(context, const RecordPaymentScreen()),
        ),
    ];
    if (actions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Gap.page),
        child: DemoNotice(
          text:
              'No quick actions are enabled for your account. Ask the admin for permissions.',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page - 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in actions) Expanded(child: a),
          for (var i = actions.length; i < 4; i++)
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(icon, color: AppColors.accent, size: 24),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData activityIcon(ActivityType t) => switch (t) {
  ActivityType.attendance => Icons.fact_check_outlined,
  ActivityType.payment => Icons.currency_rupee_rounded,
  ActivityType.exam => Icons.assignment_turned_in_outlined,
  ActivityType.staff => Icons.badge_outlined,
  ActivityType.student => Icons.person_add_alt_outlined,
  ActivityType.message => Icons.sms_outlined,
};

Color activityColor(ActivityType t) => switch (t) {
  ActivityType.attendance => AppColors.success,
  ActivityType.payment => AppColors.warning,
  ActivityType.exam => AppColors.info,
  ActivityType.staff => AppColors.accent,
  ActivityType.student => AppColors.accent,
  ActivityType.message => AppColors.info,
};

class _ActivityList extends StatelessWidget {
  const _ActivityList();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final cutoff = app.now.subtract(const Duration(hours: 24));
    final events = app.notifications
        .activity(isAdmin: app.isAdmin)
        .where((e) => e.at.isAfter(cutoff))
        .take(5)
        .toList();
    if (events.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.bolt_outlined,
        title: 'Quiet day so far',
        message:
            'Attendance, payments and results will appear here as they happen.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            _TimelineRow(event: events[i], isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final ActivityEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              IconWell(
                icon: activityIcon(event.type),
                color: activityColor(event.type),
                size: 38,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              Fmt.relative(event.at),
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({required this.exams});

  final List<Exam> exams;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final items = <(DateTime, Widget)>[
      for (final e in exams)
        (
          e.date,
          _ScheduleRow(
            date: e.date,
            title: e.name,
            subtitle:
                '${app.academic.classById(e.classId).name} · '
                '${e.subjects.map((s) => app.academic.subjectById(s.subjectId).name).join(', ')}',
            tag: 'Exam',
            tagColor: AppColors.info,
            onTap: app.can(StaffPermission.viewExamResults)
                ? () => pushPage(context, ExamDetailScreen(examId: e.id))
                : null,
          ),
        ),
      for (final ev in app.events.where((ev) => !ev.date.isBefore(app.today)))
        (
          ev.date,
          _ScheduleRow(
            date: ev.date,
            title: ev.title,
            subtitle: ev.endDate == null
                ? ev.subtitle
                : '${ev.subtitle} · until ${Fmt.shortDate(ev.endDate!)}',
            tag: 'Event',
            tagColor: AppColors.accent,
          ),
        ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    if (items.isEmpty) {
      return const EmptyState(
        compact: true,
        icon: Icons.event_outlined,
        title: 'Nothing scheduled',
        message: 'Upcoming exams and tuition events will show here.',
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < items.length && i < 5; i++) ...[
              if (i > 0) const Divider(indent: 76),
              items[i].$2,
            ],
          ],
        ),
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    this.onTap,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DateBadge(date: date),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(label: tag, color: tagColor, dense: true),
          ],
        ),
      ),
    );
  }
}

/// Cream date tile: big day number over short month.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, this.size = 48});

  final DateTime date;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.textOnCream,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Fmt.month(date.month).toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: AppColors.textOnCreamMuted,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}
