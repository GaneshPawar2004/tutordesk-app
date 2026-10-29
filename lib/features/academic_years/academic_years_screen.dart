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
import 'promotion_screen.dart';

class AcademicYearsScreen extends StatelessWidget {
  const AcademicYearsScreen({super.key});

  Future<void> _createYear(BuildContext context) async {
    final app = context.appRead;
    final latest = app.academic.years.first;
    final startYear = latest.startDate.year + 1;
    final created = await showAppSheet<bool>(
      context,
      builder: (_) => _NewYearSheet(
        suggestedLabel: '$startYear–${(startYear + 1) % 100}',
        start: DateTime(startYear, 6, 1),
        end: DateTime(startYear + 1, 4, 30),
      ),
    );
    if ((created ?? false) && context.mounted) {
      AppToast.show(context, 'Academic year created');
    }
  }

  Future<void> _makeCurrent(BuildContext context, AcademicYear year) async {
    final app = context.appRead;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Make ${year.label} the current year?',
      message:
          '${app.currentYear.label} will be closed. Attendance and new admissions will use ${year.label}. '
          'Past enrollments, fees and results are kept as they are.',
      confirmLabel: 'Make current',
      icon: Icons.event_available_rounded,
    );
    if (ok && context.mounted) {
      await runAction(
        context,
        () => app.setCurrentYear(year.id),
        success: '${year.label} is now the current year',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final current = app.currentYear;
    final others = app.academic.years.where((y) => y.id != current.id).toList();
    int enrolled(String yearId) => app.students.enrollmentsIn(yearId).length;

    return AppScaffold(
      title: 'Academic years',
      subtitle: 'Years, enrollments & promotion',
      actions: [
        IconButton(
          tooltip: 'Create academic year',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _createYear(context),
        ),
      ],
      bottomBar: PrimaryButton(
        label: 'Promote students',
        icon: Icons.trending_up_rounded,
        onPressed: () => pushPage(context, const PromotionScreen()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CURRENT YEAR',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                    const Spacer(),
                    const StatusChip(
                      label: 'Active',
                      color: AppColors.success,
                      dense: true,
                      onCream: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  current.label,
                  style: AppTextStyles.display.copyWith(
                    color: AppColors.textOnCream,
                  ),
                ),
                Text(
                  '${Fmt.date(current.startDate)} – ${Fmt.date(current.endDate)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnCreamMuted,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Expanded(
                      child: StatBlock(
                        label: 'Enrollments',
                        value: '${enrolled(current.id)}',
                        onCream: true,
                      ),
                    ),
                    Expanded(
                      child: StatBlock(
                        label: 'Classes running',
                        value: '${app.academic.runningClasses.length}',
                        onCream: true,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'All years',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
          ),
          for (final y in others)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SurfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            y.label,
                            style: AppTextStyles.title.copyWith(fontSize: 18),
                          ),
                          Text(
                            '${Fmt.date(y.startDate)} – ${Fmt.date(y.endDate)}',
                            style: AppTextStyles.caption,
                          ),
                          Text(
                            Fmt.plural(enrolled(y.id), 'enrollment'),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        StatusChip(
                          label: y.status.label,
                          color: y.status == YearStatus.upcoming
                              ? AppColors.info
                              : AppColors.textSecondary,
                          dense: true,
                        ),
                        if (y.status == YearStatus.upcoming)
                          TextButton(
                            onPressed: () => _makeCurrent(context, y),
                            child: const Text('Make current'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: Gap.sm),
          const DemoNotice(
            icon: Icons.fingerprint_rounded,
            color: AppColors.accent,
            text:
                'Promotion adds a new enrollment for the next year to each existing student. Student IDs, '
                'history, previous fees and unpaid dues stay attached to the right year — nobody is duplicated.',
          ),
        ],
      ),
    );
  }
}

class _NewYearSheet extends StatefulWidget {
  const _NewYearSheet({
    required this.suggestedLabel,
    required this.start,
    required this.end,
  });

  final String suggestedLabel;
  final DateTime start;
  final DateTime end;

  @override
  State<_NewYearSheet> createState() => _NewYearSheetState();
}

class _NewYearSheetState extends State<_NewYearSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.suggestedLabel);
  late DateTime _start = widget.start;
  late DateTime _end = widget.end;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New academic year', style: AppTextStyles.title),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Label',
              controller: _label,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Enter a label';
                if (app.academic.years.any((y) => y.label == t)) {
                  return 'This year already exists';
                }
                return null;
              },
            ),
            const SizedBox(height: Gap.md),
            DatePickerField(
              label: 'Start date',
              value: _start,
              onChanged: (d) => setState(() => _start = d),
            ),
            const SizedBox(height: Gap.md),
            DatePickerField(
              label: 'End date',
              value: _end,
              validator: (v) => v != null && !v.isAfter(_start)
                  ? 'End must be after start'
                  : null,
              onChanged: (d) => setState(() => _end = d),
            ),
            const SizedBox(height: Gap.lg),
            PrimaryButton(
              label: 'Create year',
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await runAction(
                  context,
                  () => app.addYear(
                    label: _label.text.trim(),
                    start: _start,
                    end: _end,
                  ),
                );
                if (ok && context.mounted) Navigator.of(context).pop(true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
