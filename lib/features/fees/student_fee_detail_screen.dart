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
import 'fee_widgets.dart';
import 'record_payment_screen.dart';

/// Fee agreement, schedule and payment history for one enrollment.
class StudentFeeDetailScreen extends StatelessWidget {
  const StudentFeeDetailScreen({super.key, required this.enrollmentId});

  final String enrollmentId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final enrollment = app.students.enrollmentById(enrollmentId)!;
    final student = app.students.byId(enrollment.studentId);
    final cls = app.academic.classById(enrollment.classId);
    final year = app.academic.yearById(enrollment.academicYearId);
    final plan = app.fees.planFor(enrollment.id);
    final summary = app.feeSummaryFor(enrollment.id);
    final payments = app.fees.paymentsFor(enrollment.id);
    final otherYears = app
        .historyOf(student.id)
        .where((e) => e.id != enrollment.id)
        .toList();

    return AppScaffold(
      title: student.fullName,
      subtitle: '${cls.name} · ${year.label} · ${student.id}',
      bottomBar: plan != null && summary.outstanding > 0
          ? PrimaryButton(
              label: 'Record payment',
              icon: Icons.add_rounded,
              onPressed: () => pushPage(
                context,
                RecordPaymentScreen(enrollmentId: enrollment.id),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          if (plan == null)
            _FeeSetupForm(enrollment: enrollment)
          else ...[
            FeeSummaryCard(
              summary: summary,
              title: 'Annual fee · ${year.label}',
            ),
            const SectionHeader(
              title: 'Agreement',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
            ),
            InfoRow(label: 'Annual fee', value: Fmt.currency(plan.annualFee)),
            InfoRow(
              label: 'Instalments',
              value: '${plan.installmentCount} · ${plan.frequency.label}',
            ),
            InfoRow(
              label: 'First due date',
              value: Fmt.date(plan.firstDueDate),
            ),
            if (plan.note != null) InfoRow(label: 'Note', value: plan.note!),
            const SectionHeader(
              title: 'Instalment schedule',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
            ),
            InstallmentList(
              progress: app.fees.progressFor(enrollment.id, app.today),
            ),
            const SectionHeader(
              title: 'Payment history',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
            ),
            if (payments.isEmpty)
              const EmptyState(
                compact: true,
                icon: Icons.receipt_long_outlined,
                title: 'No payment history',
                message:
                    'No payments recorded for this enrollment yet. Use Record payment below.',
              )
            else ...[
              for (final p in payments) PaymentRow(payment: p),
              const SizedBox(height: 8),
              Text(
                'Payments are never edited or deleted. A correction is recorded as a new entry.',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ],
          if (otherYears.isNotEmpty) ...[
            const SectionHeader(
              title: 'Other academic years',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
            ),
            for (final e in otherYears)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Builder(
                  builder: (context) {
                    final s = app.feeSummaryFor(e.id);
                    final hasPlan = app.fees.planFor(e.id) != null;
                    return SurfaceCard(
                      onTap: () => replacePage(
                        context,
                        StudentFeeDetailScreen(enrollmentId: e.id),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.academic.yearById(e.academicYearId).label,
                                  style: AppTextStyles.titleSmall,
                                ),
                                Text(
                                  app.academic.classById(e.classId).name,
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          if (!hasPlan)
                            const StatusChip(
                              label: 'Fee not set',
                              color: AppColors.textSecondary,
                              dense: true,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  s.outstanding > 0
                                      ? '${Fmt.currency(s.outstanding)} due'
                                      : 'Settled',
                                  style: AppTextStyles.amount.copyWith(
                                    color: s.outstanding > 0
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                ),
                                Text(
                                  'of ${Fmt.currency(s.agreed)}',
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Text(
              'Each year has its own fee agreement. Unpaid amounts stay with the year they belong to.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lets the admin agree a fee for an enrollment that has none yet, e.g. after
/// promotion into a new academic year.
class _FeeSetupForm extends StatefulWidget {
  const _FeeSetupForm({required this.enrollment});

  final Enrollment enrollment;

  @override
  State<_FeeSetupForm> createState() => _FeeSetupFormState();
}

class _FeeSetupFormState extends State<_FeeSetupForm> {
  final _formKey = GlobalKey<FormState>();
  final _fee = TextEditingController();
  var _installments = 4;
  var _frequency = FeeFrequency.quarterly;
  late DateTime _firstDue;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _firstDue = DateTime(now.year, now.month + 1, 10);
  }

  @override
  void dispose() {
    _fee.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final app = context.appRead;
    final result = app.setFeePlan(
      enrollment: widget.enrollment,
      annualFee: AmountField.parse(_fee.text),
      installments: _installments,
      frequency: _frequency,
      firstDueDate: _firstDue,
    );
    AppToast.show(
      context,
      result == FeeSetupResult.created
          ? 'Fee agreement saved'
          : 'A fee agreement already exists',
      type: result == FeeSetupResult.created
          ? ToastType.success
          : ToastType.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final year = app.academic.yearById(widget.enrollment.academicYearId);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DemoNotice(
            icon: Icons.request_quote_outlined,
            color: AppColors.warning,
            text:
                'No fee has been agreed for ${year.label}. Enter it separately — '
                'previous years\' fees are not copied or changed.',
          ),
          const SizedBox(height: Gap.md),
          AmountField(
            label: 'Agreed annual fee',
            controller: _fee,
            validator: (v) => AmountField.parse(v ?? '') <= 0
                ? 'Enter the agreed annual fee'
                : null,
          ),
          const SizedBox(height: Gap.md),
          const FieldLabel('Number of instalments'),
          Row(
            children: [
              CircleIconButton(
                icon: Icons.remove_rounded,
                tooltip: 'Fewer instalments',
                onPressed: () => setState(
                  () => _installments = (_installments - 1).clamp(1, 36),
                ),
              ),
              Expanded(
                child: Text(
                  Fmt.plural(_installments, 'instalment'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.amount.copyWith(fontSize: 17),
                ),
              ),
              CircleIconButton(
                icon: Icons.add_rounded,
                tooltip: 'More instalments',
                onPressed: () => setState(
                  () => _installments = (_installments + 1).clamp(1, 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          const FieldLabel('Payment frequency'),
          SegmentedChoice<FeeFrequency>(
            options: [
              for (final f in FeeFrequency.values) SelectOption(f, f.label),
            ],
            value: _frequency,
            onChanged: (f) => setState(() => _frequency = f),
          ),
          const SizedBox(height: Gap.md),
          DatePickerField(
            label: 'First instalment due',
            value: _firstDue,
            onChanged: (d) => setState(() => _firstDue = d),
          ),
          const SizedBox(height: Gap.lg),
          PrimaryButton(
            label: 'Save fee agreement',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
