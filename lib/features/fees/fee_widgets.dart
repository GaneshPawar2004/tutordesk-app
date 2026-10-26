import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

/// Cream summary of one enrollment's (or a group's) fee position.
class FeeSummaryCard extends StatelessWidget {
  const FeeSummaryCard({
    super.key,
    required this.summary,
    required this.title,
    this.onTap,
  });

  final FeeSummary summary;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CreamCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textOnCreamMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PaymentStatusChip(status: summary.status, onCream: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Agreed',
                  value: Fmt.currency(summary.agreed),
                  onCream: true,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Received',
                  value: Fmt.currency(summary.paid),
                  onCream: true,
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Balance',
                  value: Fmt.currency(summary.outstanding),
                  onCream: true,
                  alignEnd: true,
                  valueColor: summary.outstanding > 0
                      ? const Color(0xFFB4541F)
                      : const Color(0xFF138A5E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProgressBar(
            value: summary.progress,
            color: AppColors.accentPressed,
            trackColor: AppColors.creamTrack,
            height: 8,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${(summary.progress * 100).round()}% collected',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textOnCreamMuted,
                ),
              ),
              const Spacer(),
              if (summary.overdue > 0)
                Text(
                  '${Fmt.currency(summary.overdue)} overdue',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFFB4541F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class InstallmentList extends StatelessWidget {
  const InstallmentList({super.key, required this.progress});

  final List<InstallmentProgress> progress;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < progress.length; i++) ...[
            if (i > 0) const Divider(),
            _InstallmentRow(item: progress[i]),
          ],
        ],
      ),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({required this.item});

  final InstallmentProgress item;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (item.state) {
      InstallmentState.paid => ('Paid', AppColors.success),
      InstallmentState.partial => (
        '${Fmt.currency(item.remaining)} left',
        AppColors.warning,
      ),
      InstallmentState.due => ('Upcoming', AppColors.textSecondary),
      InstallmentState.overdue => ('Overdue', AppColors.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${item.installment.number}',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Fmt.currency(item.installment.amount),
                  style: AppTextStyles.amount,
                ),
                Text(
                  'Due ${Fmt.date(item.installment.dueDate)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          StatusChip(label: label, color: color, dense: true),
        ],
      ),
    );
  }
}

IconData paymentIcon(PaymentMethod m) => switch (m) {
  PaymentMethod.cash => Icons.payments_outlined,
  PaymentMethod.upi => Icons.qr_code_2_rounded,
  PaymentMethod.bankTransfer => Icons.account_balance_outlined,
  PaymentMethod.cheque => Icons.receipt_outlined,
  PaymentMethod.card => Icons.credit_card_rounded,
};

class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.payment, this.title, this.onTap});

  final Payment payment;

  /// Defaults to the method label; dashboards pass the student name.
  final String? title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      Fmt.date(payment.date),
      if (title != null) payment.method.label,
      ?payment.reference,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconWell(
              icon: paymentIcon(payment.method),
              color: AppColors.success,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? payment.method.label,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    details,
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (payment.note != null)
                    Text(
                      payment.note!,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '+${Fmt.currency(payment.amount)}',
              style: AppTextStyles.amount.copyWith(color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of any financial screen if a non-admin somehow navigates
/// there. Defence in depth for the UI; real enforcement belongs to the API.
class AdminOnlyNotice extends StatelessWidget {
  const AdminOnlyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Restricted',
      body: EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Admin only',
        message:
            'Fees, payments and financial reports are available to the tuition admin only.',
      ),
    );
  }
}
