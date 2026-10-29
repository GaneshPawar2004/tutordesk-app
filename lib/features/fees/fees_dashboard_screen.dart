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
import '../messaging/batch_detail_screen.dart';
import 'fee_widgets.dart';
import 'record_payment_screen.dart';
import 'student_fee_detail_screen.dart';
import 'student_fees_screen.dart';

class FeesDashboardScreen extends StatefulWidget {
  const FeesDashboardScreen({super.key});

  @override
  State<FeesDashboardScreen> createState() => _FeesDashboardScreenState();
}

class _FeesDashboardScreenState extends State<FeesDashboardScreen> {
  String? _yearId;
  String? _classId;

  Future<void> _sendReminders() async {
    final app = context.appRead;
    final existing = app.messaging.bySource(app.feeReminderKey);
    if (existing != null) {
      pushPage(context, BatchDetailScreen(batchId: existing.id));
      return;
    }
    final rows = app.overdueRows;
    if (rows.isEmpty) {
      AppToast.show(
        context,
        'No overdue balances right now.',
        type: ToastType.info,
      );
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Send fee reminders?',
      message:
          'A reminder with each student\'s overdue amount will be queued for '
          '${Fmt.plural(rows.length, 'parent')}. ${context.appRead.smsDeliveryNote}',
      confirmLabel: 'Queue ${rows.length} messages',
      icon: Icons.sms_outlined,
    );
    if (!ok || !mounted) return;
    final BatchResult result;
    try {
      result = await app.sendFeeReminders();
    } on ApiException catch (e) {
      if (mounted) AppToast.show(context, e.message, type: ToastType.error);
      return;
    }
    if (!mounted) return;
    pushPage(context, BatchDetailScreen(batchId: result.batch.id));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();

    final yearId = _yearId ?? app.selectedYear.id;
    final year = app.academic.yearById(yearId);
    final rows = app
        .feeDirectory(yearId: yearId)
        .where((r) => _classId == null || r.enrollment.classId == _classId)
        .toList();
    final totals = rows.fold(FeeSummary.empty, (sum, r) => sum + r.summary);
    final counts = {
      for (final s in PaymentStatus.values)
        s: rows.where((r) => r.plan != null && r.summary.status == s).length,
    };
    final noPlan = rows.where((r) => r.plan == null).length;
    final enrollmentIds = rows.map((r) => r.enrollment.id).toSet();
    final monthStart = DateTime(app.today.year, app.today.month);
    final thisMonth = app.fees
        .paymentsBetween(monthStart, app.today, enrollmentIds)
        .fold<int>(0, (sum, p) => sum + p.amount);
    final recent = app.fees.recent(limit: 8, enrollmentIds: enrollmentIds);
    final reminderSent = app.messaging.bySource(app.feeReminderKey) != null;

    return AppScaffold(
      title: 'Fees & payments',
      subtitle: '${year.label} · Admin only',
      actions: [
        IconButton(
          tooltip: 'Record payment',
          icon: const Icon(Icons.add_card_rounded),
          onPressed: () => pushPage(context, const RecordPaymentScreen()),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          const SizedBox(height: Gap.sm),
          FilterChips(
            children: [
              FilterPill(
                label: 'Year',
                value: year.label,
                active: yearId != app.currentYear.id,
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    context,
                    title: 'Academic year',
                    options: [
                      for (final y in app.academic.years)
                        SelectOption(y.id, y.label, subtitle: y.status.label),
                    ],
                    selected: yearId,
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
                      for (final c in app.academic.classes)
                        SelectOption(c.id, c.name),
                    ],
                    selected: _classId ?? '',
                  );
                  if (picked != null) {
                    setState(
                      () =>
                          _classId = picked.value.isEmpty ? null : picked.value,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: _TotalsCard(
              totals: totals,
              label: _classId == null
                  ? 'All classes'
                  : app.academic.classById(_classId!).name,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Collected in ${Fmt.month(app.today.month)}',
                      value: Fmt.compactCurrency(thisMonth),
                      icon: Icons.trending_up_rounded,
                      color: AppColors.success,
                      caption: 'All payment methods',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Overdue',
                      value: Fmt.compactCurrency(totals.overdue),
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.error,
                      caption:
                          '${rows.where((r) => r.summary.overdue > 0).length} students',
                      onTap: () => pushPage(
                        context,
                        StudentFeesScreen(
                          initialYearId: yearId,
                          onlyOverdue: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.page),
            child: Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Student fees',
                    icon: Icons.list_alt_rounded,
                    onPressed: () =>
                        pushPage(context, const StudentFeesScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(
                    label: reminderSent ? 'Reminders sent' : 'Send reminders',
                    icon: reminderSent
                        ? Icons.done_all_rounded
                        : Icons.sms_outlined,
                    onPressed: yearId == app.currentYear.id
                        ? _sendReminders
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Payment status'),
          for (final s in PaymentStatus.values)
            NavRow(
              icon: switch (s) {
                PaymentStatus.paid => Icons.task_alt_rounded,
                PaymentStatus.partial => Icons.timelapse_rounded,
                PaymentStatus.unpaid => Icons.hourglass_empty_rounded,
              },
              color: paymentColor(s),
              title: s.label,
              subtitle: Fmt.plural(counts[s]!, 'student'),
              onTap: () => pushPage(
                context,
                StudentFeesScreen(initialStatus: s, initialYearId: yearId),
              ),
            ),
          if (noPlan > 0)
            NavRow(
              icon: Icons.request_quote_outlined,
              color: AppColors.textSecondary,
              title: 'Fee not set',
              subtitle:
                  '${Fmt.plural(noPlan, 'enrollment')} without a fee agreement',
              onTap: () => pushPage(
                context,
                StudentFeesScreen(initialYearId: yearId, onlyWithoutPlan: true),
              ),
            ),
          const SectionHeader(title: 'Recent transactions'),
          if (recent.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No payment history',
              message: 'Recorded payments will appear here.',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.page),
              child: Column(
                children: [
                  for (final p in recent)
                    Builder(
                      builder: (context) {
                        final e = app.students.enrollmentById(p.enrollmentId)!;
                        final s = app.students.byId(e.studentId);
                        return PaymentRow(
                          payment: p,
                          title: s.fullName,
                          onTap: () => pushPage(
                            context,
                            StudentFeeDetailScreen(enrollmentId: e.id),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals, required this.label});

  final FeeSummary totals;
  final String label;

  @override
  Widget build(BuildContext context) {
    return CreamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TOTAL FEES AGREED · ${label.toUpperCase()}',
            style: AppTextStyles.label.copyWith(
              color: AppColors.textOnCreamMuted,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.currency(totals.agreed),
              style: AppTextStyles.display.copyWith(
                color: AppColors.textOnCream,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
          ProgressBar(
            value: totals.progress,
            color: AppColors.accentPressed,
            trackColor: AppColors.creamTrack,
            height: 8,
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Collected',
                  value: Fmt.currency(totals.paid),
                  onCream: true,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Outstanding',
                  value: Fmt.currency(totals.outstanding),
                  onCream: true,
                  alignEnd: true,
                  valueColor: const Color(0xFFB4541F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
