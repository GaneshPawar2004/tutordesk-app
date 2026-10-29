import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../fees/fee_widgets.dart';
import '../students/student_profile_screen.dart';

/// Step-by-step promotion: years → classes → students → fee → review.
/// Creates new enrollments for existing students; never duplicates students.
class PromotionScreen extends StatefulWidget {
  const PromotionScreen({super.key});

  @override
  State<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends State<PromotionScreen> {
  static const _steps = ['Years', 'Classes', 'Students', 'Fee', 'Review'];
  var _step = 0;
  String? _fromYearId;
  String? _toYearId;
  String? _fromClassId;
  String? _toClassId;
  final _selected = <String>{};
  final _fee = TextEditingController();
  var _installments = 4;
  var _done = false;
  var _promotedCount = 0;
  String? _firstPromotedId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fromYearId != null) return;
    final app = context.appRead;
    _fromYearId = app.currentYear.id;
    _toYearId = app.academic.nextYearAfter(app.currentYear)?.id;
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  List<Student> _sourceStudents() {
    if (_fromYearId == null || _fromClassId == null) return const [];
    return context.appRead.students.studentsIn(_fromClassId!, _fromYearId!);
  }

  bool _alreadyEnrolled(String studentId) =>
      _toYearId != null &&
      context.appRead.students.enrollmentFor(studentId, _toYearId!) != null;

  String? _validateStep() {
    final app = context.appRead;
    switch (_step) {
      case 0:
        if (_fromYearId == null || _toYearId == null) {
          return 'Choose both academic years.';
        }
        final from = app.academic.yearById(_fromYearId!);
        final to = app.academic.yearById(_toYearId!);
        if (!to.startDate.isAfter(from.startDate)) {
          return 'The destination year must come after the current year.';
        }
      case 1:
        if (_fromClassId == null || _toClassId == null) {
          return 'Choose the source and destination classes.';
        }
      case 2:
        if (_selected.isEmpty) return 'Select at least one student to promote.';
    }
    return null;
  }

  void _next() {
    final error = _validateStep();
    if (error != null) {
      AppToast.show(context, error, type: ToastType.warning);
      return;
    }
    if (_step == 1) {
      // Pre-select everyone not already in the destination year.
      _selected
        ..clear()
        ..addAll(
          _sourceStudents()
              .where((s) => !_alreadyEnrolled(s.id))
              .map((s) => s.id),
        );
    }
    setState(() => _step++);
  }

  Future<void> _confirm() async {
    final app = context.appRead;
    final to = app.academic.yearById(_toYearId!);
    final toClass = app.academic.classById(_toClassId!);
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Promote ${Fmt.plural(_selected.length, 'student')}?',
      message:
          'Each student gets a new ${toClass.name} enrollment for ${to.label}. '
          'Their permanent record, ID and previous year stay unchanged.',
      confirmLabel: 'Confirm promotion',
      icon: Icons.trending_up_rounded,
    );
    if (!ok || !mounted) return;
    final fee = AmountField.parse(_fee.text);
    final PromotionResult result;
    try {
      result = await app.promote(
        from: app.academic.yearById(_fromYearId!),
        to: to,
        toClass: toClass,
        studentIds: _selected.toList(),
        annualFee: fee > 0 ? fee : null,
        installments: _installments,
      );
    } on ApiException catch (e) {
      if (mounted) AppToast.show(context, e.message, type: ToastType.error);
      return;
    }
    if (!mounted) return;
    setState(() {
      _done = true;
      _promotedCount = result.promoted.length;
      _firstPromotedId = result.promoted.isEmpty
          ? null
          : result.promoted.first.studentId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    if (_done) return _success();

    return AppScaffold(
      title: 'Promote students',
      subtitle: 'Step ${_step + 1} of ${_steps.length} · ${_steps[_step]}',
      onBack: _step == 0 ? null : () => setState(() => _step--),
      bottomBar: Row(
        children: [
          if (_step > 0) ...[
            Expanded(
              child: SecondaryButton(
                label: 'Back',
                onPressed: () => setState(() => _step--),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: _step == _steps.length - 1
                ? PrimaryButton(
                    label: 'Confirm promotion',
                    icon: Icons.check_rounded,
                    onPressed: _confirm,
                  )
                : PrimaryButton(
                    label: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(steps: _steps, current: _step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _yearsStep(),
                  1 => _classesStep(),
                  2 => _studentsStep(),
                  3 => _feeStep(),
                  _ => _reviewStep(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _padded(List<Widget> children) => ListView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
    children: children,
  );

  Widget _yearsStep() {
    final years = context.appRead.academic.years;
    return _padded([
      Text(
        'Which year are students moving from and to?',
        style: AppTextStyles.title,
      ),
      const SizedBox(height: Gap.lg),
      SelectField<String>(
        label: 'Current academic year',
        value: _fromYearId,
        options: [
          for (final y in years)
            SelectOption(y.id, y.label, subtitle: y.status.label),
        ],
        onChanged: (v) => setState(() => _fromYearId = v),
      ),
      const SizedBox(height: Gap.md),
      SelectField<String>(
        label: 'Destination academic year',
        value: _toYearId,
        hint: 'Create the next year first if it is missing',
        options: [
          for (final y in years)
            SelectOption(y.id, y.label, subtitle: y.status.label),
        ],
        onChanged: (v) => setState(() => _toYearId = v),
      ),
    ]);
  }

  Widget _classesStep() {
    final app = context.appRead;
    return _padded([
      Text('Which class are they moving into?', style: AppTextStyles.title),
      const SizedBox(height: Gap.lg),
      SelectField<String>(
        label: 'Source class',
        value: _fromClassId,
        options: [
          for (final c in app.academic.classes)
            SelectOption(
              c.id,
              c.name,
              subtitle: Fmt.plural(
                app.students.studentsIn(c.id, _fromYearId!).length,
                'student',
              ),
            ),
        ],
        onChanged: (v) => setState(() {
          _fromClassId = v;
          _toClassId =
              app.academic.nextClassAfter(app.academic.classById(v))?.id ??
              _toClassId;
        }),
      ),
      const SizedBox(height: Gap.md),
      SelectField<String>(
        label: 'Destination class',
        value: _toClassId,
        options: [
          for (final c in app.academic.classes) SelectOption(c.id, c.name),
        ],
        onChanged: (v) => setState(() => _toClassId = v),
      ),
    ]);
  }

  Widget _studentsStep() {
    final app = context.appRead;
    final students = _sourceStudents();
    final eligible = students.where((s) => !_alreadyEnrolled(s.id)).toList();
    final toYear = app.academic.yearById(_toYearId!);
    if (students.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'No students',
        message:
            'There are no active students in this class for the selected year.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_selected.length} of ${eligible.length} selected',
                  style: AppTextStyles.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  if (_selected.length == eligible.length) {
                    _selected.clear();
                  } else {
                    _selected.addAll(eligible.map((s) => s.id));
                  }
                }),
                child: Text(
                  _selected.length == eligible.length ? 'Clear' : 'Select all',
                ),
              ),
            ],
          ),
        ),
        for (final s in students)
          CheckboxListTile(
            value: _selected.contains(s.id),
            onChanged: _alreadyEnrolled(s.id)
                ? null
                : (v) => setState(
                    () => (v ?? false)
                        ? _selected.add(s.id)
                        : _selected.remove(s.id),
                  ),
            contentPadding: const EdgeInsets.symmetric(horizontal: Gap.page),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              s.fullName,
              style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
            ),
            subtitle: Text(
              _alreadyEnrolled(s.id)
                  ? '${s.id} · already enrolled in ${toYear.label}'
                  : s.id,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: _alreadyEnrolled(s.id) ? AppColors.warning : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _feeStep() {
    final app = context.appRead;
    final toYear = app.academic.yearById(_toYearId!);
    return _padded([
      Text('Fee for ${toYear.label}', style: AppTextStyles.title),
      const SizedBox(height: 6),
      Text(
        'Optional. This is a new agreement for the new year. It does not change last year\'s fee, '
        'and any unpaid amount stays with last year\'s enrollment.',
        style: AppTextStyles.bodyMuted,
      ),
      const SizedBox(height: Gap.lg),
      AmountField(
        label: 'Annual fee for ${app.academic.classById(_toClassId!).name}',
        controller: _fee,
        optional: true,
        helper: 'Leave empty to set fees per student later.',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Gap.md),
      const FieldLabel('Instalments'),
      SegmentedChoice<int>(
        options: [
          for (final n in [1, 2, 4, 6, 10])
            SelectOption(n, n == 1 ? 'Single' : '$n'),
        ],
        value: _installments,
        onChanged: (n) => setState(() => _installments = n),
      ),
    ]);
  }

  Widget _reviewStep() {
    final app = context.appRead;
    final fromYear = app.academic.yearById(_fromYearId!);
    final toYear = app.academic.yearById(_toYearId!);
    final fromClass = app.academic.classById(_fromClassId!);
    final toClass = app.academic.classById(_toClassId!);
    final fee = AmountField.parse(_fee.text);
    final students = _sourceStudents()
        .where((s) => _selected.contains(s.id))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.xl),
      children: [
        CreamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REVIEW CHANGES',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textOnCreamMuted,
                ),
              ),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Expanded(
                    child: StatBlock(
                      label: fromYear.label,
                      value: fromClass.name,
                      onCream: true,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.textOnCream,
                  ),
                  Expanded(
                    child: StatBlock(
                      label: toYear.label,
                      value: toClass.name,
                      onCream: true,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.md),
              Text(
                '${Fmt.plural(students.length, 'student')} · '
                '${fee > 0 ? 'New fee ${Fmt.currency(fee)} in ${Fmt.plural(_installments, 'instalment')}' : 'Fee to be set later'}',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textOnCream,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const DemoNotice(
          icon: Icons.verified_outlined,
          color: AppColors.success,
          text:
              'Same student IDs · previous enrollment kept and marked Promoted · previous fees and dues untouched.',
        ),
        const SectionHeader(
          title: 'Students',
          padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
        ),
        for (final s in students)
          Builder(
            builder: (context) {
              final prev = app.students.enrollmentFor(s.id, fromYear.id);
              final due = prev == null
                  ? 0
                  : app.feeSummaryFor(prev.id).outstanding;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s.id} · ${s.fullName}',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 14.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${fromClass.name} (${fromYear.label}) → ${toClass.name} (${toYear.label})',
                            style: AppTextStyles.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (due > 0)
                      StatusChip(
                        label: '${Fmt.currency(due)} due stays',
                        color: AppColors.warning,
                        dense: true,
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _success() {
    final app = context.appRead;
    return AppScaffold(
      title: 'Promotion complete',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.xl),
          child: Column(
            children: [
              const IconWell(
                icon: Icons.check_rounded,
                color: AppColors.success,
                size: 72,
              ),
              const SizedBox(height: Gap.lg),
              Text(
                '${Fmt.plural(_promotedCount, 'student')} promoted',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'New enrollments were added to ${app.academic.classById(_toClassId!).name}, '
                '${app.academic.yearById(_toYearId!).label}. Student IDs and history are unchanged.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Gap.xl),
              if (_firstPromotedId != null)
                PrimaryButton(
                  label: 'View a promoted profile',
                  onPressed: () => replacePage(
                    context,
                    StudentProfileScreen(studentId: _firstPromotedId!),
                  ),
                ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.steps, required this.current});

  final List<String> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == steps.length - 1 ? 0 : 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? AppColors.accent
                            : AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      steps[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: i == current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: i <= current
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
