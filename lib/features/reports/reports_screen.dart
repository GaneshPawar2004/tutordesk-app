import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

enum _Range {
  week('Last 7 days', 7),
  month('Last 30 days', 30),
  year('Whole year', 0),
  custom('Custom', -1);

  const _Range(this.label, this.days);
  final String label;
  final int days;
}

/// Role-aware reports. Financial sections are only built for the admin.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  var _range = _Range.month;
  DateTimeRange? _custom;
  String? _yearId;
  String? _classId;

  DateTimeRange _window(AppState app, AcademicYear year) {
    final today = app.today;
    return switch (_range) {
      _Range.custom when _custom != null => _custom!,
      _Range.year ||
      _Range.custom => DateTimeRange(start: year.startDate, end: year.endDate),
      _ => DateTimeRange(
        start: today.subtract(Duration(days: _range.days - 1)),
        end: today,
      ),
    };
  }

  Future<void> _pickRange() async {
    final picked = await showSelectSheet<_Range>(
      context,
      title: 'Date range',
      options: [for (final r in _Range.values) SelectOption(r, r.label)],
      selected: _range,
    );
    if (picked == null || !mounted) return;
    if (picked.value == _Range.custom) {
      final now = DateTime.now();
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 3),
        lastDate: now,
        initialDateRange:
            _custom ??
            DateTimeRange(
              start: now.subtract(const Duration(days: 14)),
              end: now,
            ),
      );
      if (r == null) return;
      setState(() {
        _range = _Range.custom;
        _custom = r;
      });
    } else {
      setState(() => _range = picked.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final year = app.academic.yearById(_yearId ?? app.selectedYear.id);
    final window = _window(app, year);
    final classes = app.visibleClasses
        .where((c) => _classId == null || c.id == _classId)
        .toList();
    final canResults = app.can(StaffPermission.viewExamResults);

    return AppScaffold(
      title: 'Reports',
      subtitle: app.isAdmin ? 'All classes' : 'Your classes',
      body: SimulatedLoad(
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          children: [
            const SizedBox(height: Gap.sm),
            FilterChips(
              children: [
                FilterPill(
                  label: 'Range',
                  value: _range == _Range.custom && _custom != null
                      ? '${Fmt.shortDate(_custom!.start)} – ${Fmt.shortDate(_custom!.end)}'
                      : _range.label,
                  active: _range != _Range.month,
                  onTap: _pickRange,
                ),
                FilterPill(
                  label: 'Year',
                  value: year.label,
                  active: year.id != app.currentYear.id,
                  onTap: () async {
                    final picked = await showSelectSheet<String>(
                      context,
                      title: 'Academic year',
                      options: [
                        for (final y in app.academic.years)
                          SelectOption(y.id, y.label),
                      ],
                      selected: year.id,
                    );
                    if (picked != null) setState(() => _yearId = picked.value);
                  },
                ),
                FilterPill(
                  label: 'Class',
                  value: _classId == null
                      ? 'All'
                      : app.academic.classById(_classId!).name,
                  active: _classId != null,
                  onTap: () async {
                    final picked = await showSelectSheet<String>(
                      context,
                      title: 'Class',
                      options: [
                        const SelectOption('', 'All classes'),
                        for (final c in app.visibleClasses)
                          SelectOption(c.id, c.name),
                      ],
                      selected: _classId ?? '',
                    );
                    if (picked != null) {
                      setState(
                        () => _classId = picked.value.isEmpty
                            ? null
                            : picked.value,
                      );
                    }
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 12, Gap.page, 0),
              child: Text(
                '${Fmt.date(window.start)} – ${Fmt.date(window.end)}',
                style: AppTextStyles.caption,
              ),
            ),
            if (app.isAdmin)
              _EnrollmentReport(year: year, classes: classes, window: window),
            _AttendanceReport(year: year, classes: classes, window: window),
            if (app.canSeeFinance) ...[
              _FeeCollectionReport(
                year: year,
                classes: classes,
                window: window,
              ),
              _DuesReport(year: year, classes: classes),
            ],
            if (canResults)
              _ExamReport(year: year, classes: classes, window: window),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
              child: Text(
                'Export to PDF/Excel is not part of this demo. Figures are computed from sample data.',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Report section: header, headline stats, then optional bar rows.
class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.stats,
    this.children = const [],
  });

  final String title;
  final IconData icon;
  final List<(String, String)> stats;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 0),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconWell(icon: icon, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTextStyles.titleSmall)),
              ],
            ),
            const SizedBox(height: Gap.md),
            Row(
              children: [
                for (var i = 0; i < stats.length; i++)
                  Expanded(
                    child: StatBlock(
                      label: stats[i].$1,
                      value: stats[i].$2,
                      alignEnd: i == stats.length - 1 && i > 0,
                    ),
                  ),
              ],
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              const Divider(),
              const SizedBox(height: 8),
              ...children,
            ],
          ],
        ),
      ),
    );
  }
}

/// One horizontal bar: label, bar (single hue), value in text ink.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final String value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: AppTextStyles.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(child: ProgressBar(value: ratio, height: 8)),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: AppTextStyles.amount.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentReport extends StatelessWidget {
  const _EnrollmentReport({
    required this.year,
    required this.classes,
    required this.window,
  });

  final AcademicYear year;
  final List<SchoolClass> classes;
  final DateTimeRange window;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ids = classes.map((c) => c.id).toSet();
    final enrollments = app.students
        .enrollmentsIn(year.id, includeInactive: true)
        .where((e) => ids.contains(e.classId))
        .toList();
    final active = enrollments
        .where((e) => e.status != EnrollmentStatus.withdrawn)
        .length;
    final withdrawn = enrollments.length - active;
    final newAdmissions = enrollments
        .where(
          (e) =>
              e.promotedFromId == null &&
              !e.enrolledOn.isBefore(window.start) &&
              !e.enrolledOn.isAfter(window.end),
        )
        .length;
    final counts = {
      for (final c in classes) c: app.enrolledCount(c.id, year.id),
    };
    final maxCount = counts.values.fold(1, (a, b) => a > b ? a : b);
    return _ReportSection(
      title: 'Student enrollment',
      icon: Icons.groups_outlined,
      stats: [
        ('Active', '$active'),
        ('New in range', '$newAdmissions'),
        ('Withdrawn', '$withdrawn'),
      ],
      children: [
        for (final e in counts.entries)
          _BarRow(
            label: e.key.name,
            value: '${e.value}',
            ratio: e.value / maxCount,
          ),
      ],
    );
  }
}

class _AttendanceReport extends StatelessWidget {
  const _AttendanceReport({
    required this.year,
    required this.classes,
    required this.window,
  });

  final AcademicYear year;
  final List<SchoolClass> classes;
  final DateTimeRange window;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final sessions = app.attendance.between(
      window.start,
      window.end,
      yearId: year.id,
    );
    var attended = 0, total = 0;
    final perClass = <SchoolClass, double?>{};
    for (final c in classes) {
      var a = 0, t = 0;
      for (final s in sessions.where((s) => s.classId == c.id)) {
        a += s.presentCount + s.lateCount;
        t += s.total;
      }
      attended += a;
      total += t;
      perClass[c] = t == 0 ? null : a * 100 / t;
    }
    final count = sessions
        .where((s) => classes.any((c) => c.id == s.classId))
        .length;
    return _ReportSection(
      title: 'Attendance',
      icon: Icons.fact_check_outlined,
      stats: [
        (
          'Average',
          total == 0 ? '—' : Fmt.percent(attended * 100 / total, decimals: 1),
        ),
        ('Sessions', '$count'),
        ('Absences', '${total - attended}'),
      ],
      children: total == 0
          ? [
              Text(
                'No attendance recorded in this range.',
                style: AppTextStyles.caption,
              ),
            ]
          : [
              for (final e in perClass.entries)
                _BarRow(
                  label: e.key.name,
                  value: e.value == null
                      ? '—'
                      : Fmt.percent(e.value!, decimals: 1),
                  ratio: (e.value ?? 0) / 100,
                ),
            ],
    );
  }
}

class _FeeCollectionReport extends StatelessWidget {
  const _FeeCollectionReport({
    required this.year,
    required this.classes,
    required this.window,
  });

  final AcademicYear year;
  final List<SchoolClass> classes;
  final DateTimeRange window;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ids = classes.map((c) => c.id).toSet();
    final enrollmentIds = app.students
        .enrollmentsIn(year.id, includeInactive: true)
        .where((e) => ids.contains(e.classId))
        .map((e) => e.id)
        .toSet();
    final payments = app.fees.paymentsBetween(
      window.start,
      window.end,
      enrollmentIds,
    );
    final total = payments.fold<int>(0, (s, p) => s + p.amount);
    final byMethod = {
      for (final m in PaymentMethod.values)
        m: payments
            .where((p) => p.method == m)
            .fold<int>(0, (s, p) => s + p.amount),
    }..removeWhere((_, v) => v == 0);
    final maxValue = byMethod.values.fold(1, (a, b) => a > b ? a : b);
    return _ReportSection(
      title: 'Fee collection · admin',
      icon: Icons.account_balance_wallet_outlined,
      stats: [
        ('Collected', Fmt.compactCurrency(total)),
        ('Payments', '${payments.length}'),
      ],
      children: byMethod.isEmpty
          ? [Text('No payments in this range.', style: AppTextStyles.caption)]
          : [
              for (final e in byMethod.entries)
                _BarRow(
                  label: e.key.label,
                  value: Fmt.compactCurrency(e.value),
                  ratio: e.value / maxValue,
                ),
            ],
    );
  }
}

class _DuesReport extends StatelessWidget {
  const _DuesReport({required this.year, required this.classes});

  final AcademicYear year;
  final List<SchoolClass> classes;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ids = classes.map((c) => c.id).toSet();
    final rows = app
        .feeDirectory(yearId: year.id)
        .where((r) => ids.contains(r.enrollment.classId))
        .toList();
    final outstanding = rows.fold<int>(0, (s, r) => s + r.summary.outstanding);
    final overdue = rows.fold<int>(0, (s, r) => s + r.summary.overdue);
    final top = rows.where((r) => r.summary.overdue > 0).toList()
      ..sort((a, b) => b.summary.overdue.compareTo(a.summary.overdue));
    return _ReportSection(
      title: 'Outstanding dues · admin',
      icon: Icons.warning_amber_rounded,
      stats: [
        ('Outstanding', Fmt.compactCurrency(outstanding)),
        ('Overdue', Fmt.compactCurrency(overdue)),
      ],
      children: [
        Text(
          'HIGHEST OVERDUE',
          style: AppTextStyles.label.copyWith(fontSize: 10.5),
        ),
        const SizedBox(height: 6),
        if (top.isEmpty)
          Text('Nothing overdue.', style: AppTextStyles.caption)
        else
          for (final r in top.take(5))
            InfoRow(
              label:
                  '${r.student.fullName} · ${app.academic.classById(r.enrollment.classId).name}',
              value: Fmt.currency(r.summary.overdue),
            ),
      ],
    );
  }
}

class _ExamReport extends StatelessWidget {
  const _ExamReport({
    required this.year,
    required this.classes,
    required this.window,
  });

  final AcademicYear year;
  final List<SchoolClass> classes;
  final DateTimeRange window;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final ids = classes.map((c) => c.id).toSet();
    final exams = app.exams.all
        .where(
          (e) =>
              e.academicYearId == year.id &&
              ids.contains(e.classId) &&
              e.resultsPublished &&
              !e.date.isBefore(window.start) &&
              !e.date.isAfter(window.end),
        )
        .toList();
    final averages = {for (final e in exams) e: app.classAverage(e)};
    final valid = averages.values.whereType<double>().toList();
    final overall = valid.isEmpty
        ? null
        : valid.reduce((a, b) => a + b) / valid.length;
    return _ReportSection(
      title: 'Exam performance',
      icon: Icons.insights_rounded,
      stats: [
        ('Published', '${exams.length}'),
        (
          'Avg score',
          overall == null ? '—' : Fmt.percent(overall, decimals: 1),
        ),
      ],
      children: exams.isEmpty
          ? [
              Text(
                'No published results in this range.',
                style: AppTextStyles.caption,
              ),
            ]
          : [
              for (final e in averages.entries)
                _BarRow(
                  label:
                      '${app.academic.classById(e.key.classId).name} · ${e.key.name}',
                  value: e.value == null
                      ? '—'
                      : Fmt.percent(e.value!, decimals: 1),
                  ratio: (e.value ?? 0) / 100,
                ),
            ],
    );
  }
}
