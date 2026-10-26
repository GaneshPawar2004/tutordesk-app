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
import '../exams/student_result_screen.dart';
import '../fees/fee_widgets.dart';
import '../fees/record_payment_screen.dart';
import '../fees/student_fee_detail_screen.dart';
import 'student_form_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key, required this.studentId});

  final String studentId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final student = app.students.tryById(studentId);
    if (student == null || !app.can(StaffPermission.viewStudents)) {
      return const AppScaffold(
        title: 'Student',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available',
          message: 'This profile is not available for your account.',
        ),
      );
    }
    final enrollment = app.enrollmentOf(student.id);
    if (app.isStaff &&
        (enrollment == null || !app.canAccessClass(enrollment.classId))) {
      return const AppScaffold(
        title: 'Student',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Outside your classes',
          message: 'Staff can only open students from their assigned classes.',
        ),
      );
    }

    final tabs = <(String, Widget)>[
      ('Overview', _OverviewTab(student: student)),
      ('Attendance', _AttendanceTab(student: student)),
      if (app.can(StaffPermission.viewExamResults))
        ('Exams & Marks', _ExamsTab(student: student)),
      ('Academic History', _HistoryTab(student: student)),
      if (app.canSeeFinance) ('Fees', _FeesTab(student: student)),
    ];
    final canEdit = app.isAdmin || app.can(StaffPermission.editStudents);

    return DefaultTabController(
      length: tabs.length,
      child: AppScaffold(
        title: student.fullName,
        subtitle: student.id,
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit student',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  pushPage(context, StudentFormScreen(student: student)),
            ),
        ],
        body: Column(
          children: [
            _ProfileHeader(student: student, enrollment: enrollment),
            const SizedBox(height: Gap.sm),
            SizedBox(
              height: 44,
              child: TabBar(
                isScrollable: true,
                padding: const EdgeInsets.symmetric(horizontal: Gap.page - 4),
                tabs: [for (final t in tabs) Tab(text: t.$1)],
              ),
            ),
            const SizedBox(height: Gap.sm),
            Expanded(child: TabBarView(children: [for (final t in tabs) t.$2])),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.student, required this.enrollment});

  final Student student;
  final Enrollment? enrollment;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final active =
        student.isActive && enrollment?.status != EnrollmentStatus.withdrawn;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
      child: Row(
        children: [
          AppAvatar(initials: student.initials, seed: student.id, size: 72),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: AppTextStyles.headline.copyWith(fontSize: 22),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${student.id} · ${app.classNameOf(student.id)} · ${app.selectedYear.label}',
                  style: AppTextStyles.caption.copyWith(
                    fontFeatures: AppTextStyles.tabular,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                ActiveStatusChip(active: active),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final e = app.enrollmentOf(student.id);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: [
        const SectionHeader(
          title: 'Parent & contact',
          padding: EdgeInsets.only(bottom: 4, top: Gap.sm),
        ),
        InfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Parent / guardian',
          value: student.parentName,
        ),
        InfoRow(
          icon: Icons.phone_outlined,
          label: 'Mobile',
          value: Fmt.phone(student.parentPhone),
        ),
        InfoRow(
          icon: Icons.phone_forwarded_outlined,
          label: 'Alternate',
          value: student.altPhone == null
              ? 'Not provided'
              : Fmt.phone(student.altPhone!),
        ),
        InfoRow(
          icon: Icons.home_outlined,
          label: 'Address',
          value: student.address ?? 'Not provided',
        ),
        const Divider(height: Gap.lg),
        const SectionHeader(
          title: 'Enrollment',
          padding: EdgeInsets.only(bottom: 4, top: Gap.sm),
        ),
        if (e == null)
          const InfoRow(label: 'Status', value: 'Not enrolled in this year')
        else ...[
          InfoRow(
            icon: Icons.calendar_month_outlined,
            label: 'Academic year',
            value: app.academic.yearById(e.academicYearId).label,
          ),
          InfoRow(
            icon: Icons.class_outlined,
            label: 'Class',
            value: app.academic.classById(e.classId).name,
          ),
          InfoRow(
            icon: Icons.event_outlined,
            label: 'Enrolled on',
            value: Fmt.date(e.enrolledOn),
          ),
          InfoRow(
            icon: Icons.flag_outlined,
            label: 'Enrollment status',
            value: e.status.label,
          ),
        ],
        InfoRow(
          icon: Icons.history_rounded,
          label: 'First admitted',
          value: Fmt.date(student.admittedOn),
        ),
        const Divider(height: Gap.lg),
        const SectionHeader(
          title: 'Personal',
          padding: EdgeInsets.only(bottom: 4, top: Gap.sm),
        ),
        InfoRow(
          icon: Icons.cake_outlined,
          label: 'Date of birth',
          value:
              '${Fmt.date(student.dateOfBirth)} · ${student.ageOn(app.today)} yrs',
        ),
        InfoRow(
          icon: Icons.wc_rounded,
          label: 'Gender',
          value: student.gender?.label ?? 'Not specified',
        ),
      ],
    );
  }
}

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab({required this.student});

  final Student student;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime? _month;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final yearId =
        app.enrollmentOf(widget.student.id)?.academicYearId ??
        app.currentYear.id;
    final summary = app.attendance.summaryFor(widget.student.id, yearId);
    final history = app.attendance.historyFor(widget.student.id, yearId);
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No attendance yet',
        message:
            'Attendance will appear here once a session for this student\'s class is marked.',
      );
    }
    final month =
        _month ?? DateTime(history.first.$1.year, history.first.$1.month);
    final byDay = {
      for (final (d, s) in history)
        if (d.year == month.year && d.month == month.month) d.day: s,
    };
    final months =
        history.map((h) => DateTime(h.$1.year, h.$1.month)).toSet().toList()
          ..sort();
    final idx = months.indexOf(month);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: [
        CreamCard(
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: summary.percent / 100,
                        strokeWidth: 8,
                        color: AppColors.accentPressed,
                        backgroundColor: AppColors.creamTrack,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      Fmt.percent(summary.percent),
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.textOnCream,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ATTENDANCE',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${summary.attended} of ${summary.total} sessions attended',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.textOnCream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.academic.yearById(yearId).label,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final (status, count) in [
              (AttendanceStatus.present, summary.present),
              (AttendanceStatus.absent, summary.absent),
              (AttendanceStatus.late, summary.late),
              (AttendanceStatus.leave, summary.leave),
            ]) ...[
              Expanded(
                child: SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 10,
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: AppTextStyles.metric.copyWith(
                          fontSize: 20,
                          color: attendanceColor(status),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        status.label,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (status != AttendanceStatus.leave) const SizedBox(width: 8),
            ],
          ],
        ),
        SectionHeader(
          title: Fmt.monthYear(month),
          padding: const EdgeInsets.only(top: Gap.lg, bottom: 8),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: idx > 0
                    ? () => setState(() => _month = months[idx - 1])
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: idx < months.length - 1
                    ? () => setState(() => _month = months[idx + 1])
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        MonthCalendar(month: month, statuses: byDay),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in AttendanceStatus.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: attendanceColor(s),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
        const SectionHeader(
          title: 'Recent sessions',
          padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
        ),
        for (final (date, status) in history.take(8))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Fmt.longDate(date),
                    style: AppTextStyles.body.copyWith(fontSize: 14),
                  ),
                ),
                AttendanceStatusChip(status: status),
              ],
            ),
          ),
      ],
    );
  }
}

/// Compact month grid with a coloured dot per marked day.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key, required this.month, required this.statuses});

  final DateTime month;
  final Map<int, AttendanceStatus> statuses;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final cells = offset + days;
    final rows = (cells / 7).ceil();
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Center(
                    child: Text(
                      Fmt.weekdayLetter(d),
                      style: AppTextStyles.label.copyWith(fontSize: 10.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = r * 7 + c - offset + 1;
                        if (day < 1 || day > days) {
                          return const SizedBox(height: 38);
                        }
                        final status = statuses[day];
                        return Semantics(
                          label:
                              '${Fmt.month(month.month)} $day: ${status?.label ?? 'no session'}',
                          child: Container(
                            height: 34,
                            margin: const EdgeInsets.all(2),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: status == null
                                  ? Colors.transparent
                                  : AppColors.tint(
                                      attendanceColor(status),
                                      0.18,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$day',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12.5,
                                fontWeight: status == null
                                    ? FontWeight.w400
                                    : FontWeight.w700,
                                color: status == null
                                    ? AppColors.textTertiary
                                    : attendanceColor(status),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ExamsTab extends StatelessWidget {
  const _ExamsTab({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final enrollments = app.historyOf(student.id);
    final exams = app.exams.all.where((e) {
      final matches = enrollments.any(
        (en) =>
            en.academicYearId == e.academicYearId && en.classId == e.classId,
      );
      if (!matches) return false;
      // Unpublished marks are visible to the admin only, clearly labelled.
      return e.resultsPublished || (app.isAdmin && e.marks.isNotEmpty);
    }).toList();
    if (exams.isEmpty) {
      return const EmptyState(
        icon: Icons.assignment_outlined,
        title: 'No marks yet',
        message:
            'Results appear here after marks are entered and published for this student\'s class.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      itemCount: exams.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final exam = exams[i];
        final result = app.resultFor(exam, student.id);
        return SurfaceCard(
          onTap: () => pushPage(
            context,
            StudentResultScreen(examId: exam.id, studentId: student.id),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.name,
                          style: AppTextStyles.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(Fmt.date(exam.date), style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!exam.resultsPublished)
                    const StatusChip(
                      label: 'Draft',
                      color: AppColors.textSecondary,
                      dense: true,
                    )
                  else
                    StatusChip(
                      label: 'Grade ${result.grade.label}',
                      color: result.grade.color,
                      dense: true,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              for (final s in result.subjects)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 104,
                        child: Text(
                          s.subject.name,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ProgressBar(
                          value: s.ratio,
                          color: s.isAbsent
                              ? AppColors.textTertiary
                              : AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 58,
                        child: Text(
                          s.isAbsent
                              ? 'Absent'
                              : s.isMissing
                              ? '—/${Fmt.marks(s.maxMarks)}'
                              : '${Fmt.marks(s.obtained)}/${Fmt.marks(s.maxMarks)}',
                          textAlign: TextAlign.right,
                          style: AppTextStyles.amount.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    'Total ${Fmt.marks(result.obtained)}/${Fmt.marks(result.maxTotal)}',
                    style: AppTextStyles.amount,
                  ),
                  const Spacer(),
                  Text(
                    Fmt.percent(result.percent, decimals: 1),
                    style: AppTextStyles.amount.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final history = app.historyOf(student.id).reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: [
        const DemoNotice(
          icon: Icons.fingerprint_rounded,
          color: AppColors.accent,
          text:
              'One permanent student record. Each academic year adds a separate enrollment — '
              'the student is never duplicated when promoted.',
        ),
        const SizedBox(height: Gap.md),
        for (var i = 0; i < history.length; i++)
          _HistoryRow(
            enrollment: history[i],
            isFirst: i == 0,
            isLast: i == history.length - 1,
          ),
        if (app.isAdmin) ...[
          const SizedBox(height: Gap.md),
          SecondaryButton(
            label: 'Manage years & promotion',
            icon: Icons.swap_vert_rounded,
            onPressed: () => pushPage(context, const AcademicYearsScreen()),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.enrollment,
    required this.isFirst,
    required this.isLast,
  });

  final Enrollment enrollment;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final year = app.academic.yearById(enrollment.academicYearId);
    final cls = app.academic.classById(enrollment.classId);
    final color = switch (enrollment.status) {
      EnrollmentStatus.active => AppColors.accent,
      EnrollmentStatus.promoted => AppColors.success,
      EnrollmentStatus.completed => AppColors.info,
      EnrollmentStatus.withdrawn => AppColors.textSecondary,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    color: isFirst ? AppColors.accent : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(year.label, style: AppTextStyles.label),
                          const SizedBox(height: 4),
                          Text(
                            cls.name,
                            style: AppTextStyles.title.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Enrolled ${Fmt.date(enrollment.enrolledOn)}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: enrollment.status.label,
                      color: color,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Admin-only. Never constructed for staff (see tab list above).
class _FeesTab extends StatefulWidget {
  const _FeesTab({required this.student});

  final Student student;

  @override
  State<_FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<_FeesTab> {
  String? _enrollmentId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final history = app.historyOf(widget.student.id).reversed.toList();
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No enrollments',
        message: 'No fee records yet.',
      );
    }
    final enrollment = history.firstWhere(
      (e) => e.id == _enrollmentId,
      orElse: () => app.enrollmentOf(widget.student.id) ?? history.first,
    );
    final plan = app.fees.planFor(enrollment.id);
    final summary = app.feeSummaryFor(enrollment.id);
    final payments = app.fees.paymentsFor(enrollment.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
      children: [
        SegmentedChoice<String>(
          options: [
            for (final e in history)
              SelectOption(e.id, app.academic.yearById(e.academicYearId).label),
          ],
          value: enrollment.id,
          onChanged: (id) => setState(() => _enrollmentId = id),
        ),
        const SizedBox(height: Gap.md),
        if (plan == null)
          EmptyState(
            compact: true,
            icon: Icons.request_quote_outlined,
            title: 'No fee agreement',
            message:
                'No fee has been agreed for ${app.academic.yearById(enrollment.academicYearId).label} yet.',
            actionLabel: 'Set up fee',
            onAction: () => pushPage(
              context,
              StudentFeeDetailScreen(enrollmentId: enrollment.id),
            ),
          )
        else ...[
          FeeSummaryCard(
            summary: summary,
            title:
                '${app.academic.classById(enrollment.classId).name} · ${app.academic.yearById(enrollment.academicYearId).label}',
          ),
          const SectionHeader(
            title: 'Instalments',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
          ),
          InstallmentList(
            progress: app.fees.progressFor(enrollment.id, app.today),
          ),
          SectionHeader(
            title: 'Payments',
            padding: const EdgeInsets.only(top: Gap.lg, bottom: 4),
            actionLabel: 'Full details',
            onAction: () => pushPage(
              context,
              StudentFeeDetailScreen(enrollmentId: enrollment.id),
            ),
          ),
          if (payments.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No payment history',
              message:
                  'Payments recorded for this enrollment will be listed here.',
            )
          else
            for (final p in payments.take(4)) PaymentRow(payment: p),
          const SizedBox(height: Gap.md),
          if (summary.outstanding > 0)
            PrimaryButton(
              label: 'Record payment',
              icon: Icons.add_rounded,
              onPressed: () => pushPage(
                context,
                RecordPaymentScreen(enrollmentId: enrollment.id),
              ),
            ),
        ],
      ],
    );
  }
}
