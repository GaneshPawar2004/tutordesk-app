import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'fee_widgets.dart';

/// Records a (partial or full) payment against one enrollment. Each save adds
/// a new payment — existing payments are never altered.
class RecordPaymentScreen extends StatefulWidget {
  const RecordPaymentScreen({super.key, this.enrollmentId});

  final String? enrollmentId;

  @override
  State<RecordPaymentScreen> createState() => _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends State<RecordPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String? _studentId;
  String? _enrollmentId;
  DateTime _date = DateTime.now();
  var _method = PaymentMethod.upi;
  var _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.enrollmentId != null && _enrollmentId == null) {
      final e = context.appRead.students.enrollmentById(widget.enrollmentId!);
      _enrollmentId = e?.id;
      _studentId = e?.studentId;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickStudent() async {
    final app = context.appRead;
    final id = await showAppSheet<String>(
      context,
      builder: (_) => const _StudentPickerSheet(),
    );
    if (id == null) return;
    final enrollments = app
        .historyOf(id)
        .where((e) => app.fees.planFor(e.id) != null)
        .toList();
    final current = app.students.enrollmentFor(id, app.currentYear.id);
    setState(() {
      _studentId = id;
      _enrollmentId =
          (enrollments.contains(current) ? current : enrollments.lastOrNull)
              ?.id;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_studentId == null || _enrollmentId == null) {
      AppToast.show(
        context,
        'Select a student with a fee agreement.',
        type: ToastType.error,
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final app = context.appRead;
    final enrollment = app.students.enrollmentById(_enrollmentId!)!;
    final amount = AmountField.parse(_amount.text);
    final student = app.students.byId(enrollment.studentId);
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Record ${Fmt.currency(amount)}?',
      message:
          '${student.fullName} · ${app.academic.yearById(enrollment.academicYearId).label} · ${_method.label}',
      confirmLabel: 'Record payment',
      icon: Icons.currency_rupee_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await app.recordPayment(
        enrollment: enrollment,
        amount: amount,
        date: _date,
        method: _method,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, e.message, type: ToastType.error);
      }
      return;
    }
    if (!mounted) return;
    final balance = app.feeSummaryFor(enrollment.id).outstanding;
    Navigator.of(context).pop();
    AppToast.show(
      context,
      balance == 0
          ? 'Payment recorded · fee fully paid'
          : 'Payment recorded · ${Fmt.currency(balance)} remaining',
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final student = _studentId == null ? null : app.students.byId(_studentId!);
    final enrollments = student == null
        ? <Enrollment>[]
        : app
              .historyOf(student.id)
              .where((e) => app.fees.planFor(e.id) != null)
              .toList()
              .reversed
              .toList();
    final summary = _enrollmentId == null
        ? null
        : app.feeSummaryFor(_enrollmentId!);
    final next = _enrollmentId == null
        ? null
        : app.fees
              .progressFor(_enrollmentId!, app.today)
              .where((p) => p.state != InstallmentState.paid)
              .firstOrNull;

    return AppScaffold(
      title: 'Record payment',
      subtitle: 'Admin only',
      bottomBar: PrimaryButton(
        label: 'Save payment',
        icon: Icons.check_rounded,
        loading: _saving,
        onPressed: summary == null || summary.outstanding == 0 ? null : _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          children: [
            const FieldLabel('Student'),
            SurfaceCard(
              onTap: widget.enrollmentId == null ? _pickStudent : null,
              child: Row(
                children: [
                  if (student == null)
                    const IconWell(icon: Icons.person_search_outlined, size: 44)
                  else
                    AppAvatar(initials: student.initials, seed: student.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student?.fullName ?? 'Select student',
                          style: AppTextStyles.titleSmall,
                        ),
                        Text(
                          student == null
                              ? 'Search by name or student ID'
                              : '${student.id} · ${app.classNameOf(student.id)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (widget.enrollmentId == null)
                    const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
            if (student != null) ...[
              const SizedBox(height: Gap.md),
              if (enrollments.isEmpty)
                const DemoNotice(
                  icon: Icons.request_quote_outlined,
                  color: AppColors.warning,
                  text:
                      'This student has no fee agreement yet. Set one up from their fee details first.',
                )
              else
                SelectField<String>(
                  label: 'Enrollment / academic year',
                  value: _enrollmentId,
                  options: [
                    for (final e in enrollments)
                      SelectOption(
                        e.id,
                        '${app.academic.yearById(e.academicYearId).label} · ${app.academic.classById(e.classId).name}',
                        subtitle:
                            '${Fmt.currency(app.feeSummaryFor(e.id).outstanding)} outstanding',
                      ),
                  ],
                  onChanged: (v) => setState(() => _enrollmentId = v),
                ),
            ],
            if (summary != null) ...[
              const SizedBox(height: Gap.md),
              FeeSummaryCard(summary: summary, title: 'Current position'),
              if (summary.outstanding == 0) ...[
                const SizedBox(height: Gap.md),
                const DemoNotice(
                  icon: Icons.task_alt_rounded,
                  color: AppColors.success,
                  text:
                      'This enrollment is fully paid. No further payment is needed.',
                ),
              ] else ...[
                const SizedBox(height: Gap.lg),
                AmountField(
                  label: 'Amount received',
                  controller: _amount,
                  helper: 'Partial payments are fine.',
                  validator: (v) {
                    final value = AmountField.parse(v ?? '');
                    if (value <= 0) return 'Enter the amount received';
                    if (value > summary.outstanding) {
                      return 'Exceeds the outstanding balance of ${Fmt.currency(summary.outstanding)}';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (next != null && next.remaining < summary.outstanding)
                      ActionChip(
                        label: Text(
                          'Next instalment ${Fmt.currency(next.remaining)}',
                        ),
                        onPressed: () =>
                            setState(() => _amount.text = '${next.remaining}'),
                      ),
                    ActionChip(
                      label: Text(
                        'Full balance ${Fmt.currency(summary.outstanding)}',
                      ),
                      onPressed: () => setState(
                        () => _amount.text = '${summary.outstanding}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                DatePickerField(
                  label: 'Payment date',
                  value: _date,
                  lastDate: DateTime.now(),
                  onChanged: (d) => setState(() => _date = d),
                ),
                const SizedBox(height: Gap.md),
                const FieldLabel('Payment method'),
                SegmentedChoice<PaymentMethod>(
                  options: [
                    for (final m in PaymentMethod.values)
                      SelectOption(m, m.label),
                  ],
                  value: _method,
                  onChanged: (m) => setState(() => _method = m),
                ),
                const SizedBox(height: Gap.md),
                CustomTextField(
                  label: 'Transaction / reference number',
                  controller: _reference,
                  optional: true,
                  hint: _method == PaymentMethod.cash
                      ? 'Receipt book number'
                      : 'e.g. UPI ref 6182…',
                ),
                const SizedBox(height: Gap.md),
                CustomTextField(
                  label: 'Notes',
                  controller: _note,
                  optional: true,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StudentPickerSheet extends StatefulWidget {
  const _StudentPickerSheet();

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final rows = app.feeDirectory(yearId: app.currentYear.id).where((r) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return r.student.fullName.toLowerCase().contains(q) ||
          r.student.id.toLowerCase().contains(q);
    }).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHeader(title: 'Select student'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 8),
          child: AppSearchBar(
            controller: _search,
            hint: 'Name or student ID',
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        Flexible(
          child: rows.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message: 'Try another name or ID.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return StudentListTile(
                      student: r.student,
                      className: app.academic
                          .classById(r.enrollment.classId)
                          .name,
                      showParent: false,
                      trailing: Text(
                        r.plan == null
                            ? 'No fee'
                            : Fmt.currency(r.summary.outstanding),
                        style: AppTextStyles.amount.copyWith(fontSize: 13),
                      ),
                      onTap: () => Navigator.of(context).pop(r.student.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
