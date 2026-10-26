import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';

/// Makes it explicit that nothing leaves the device in this phase.
class SmsDemoBanner extends StatelessWidget {
  const SmsDemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoNotice(
      icon: Icons.science_outlined,
      text:
          'Demo mode · Sending is simulated on this device. No SMS provider is connected and no real messages are sent.',
    );
  }
}

/// Phone-style message preview.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, this.footer});

  final String text;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: AppTextStyles.body.copyWith(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            footer ??
                '${text.length} characters · ${(text.length / 160).ceil()} SMS part${text.length > 160 ? 's' : ''}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

IconData categoryIcon(MessageCategory c) => switch (c) {
  MessageCategory.attendance => Icons.fact_check_outlined,
  MessageCategory.examResults => Icons.assignment_turned_in_outlined,
  MessageCategory.feeReminder => Icons.currency_rupee_rounded,
  MessageCategory.announcement => Icons.campaign_outlined,
};

Color categoryColor(MessageCategory c) => switch (c) {
  MessageCategory.attendance => AppColors.success,
  MessageCategory.examResults => AppColors.info,
  MessageCategory.feeReminder => AppColors.warning,
  MessageCategory.announcement => AppColors.accent,
};

/// Proportional bar of delivered / sent / failed / pending.
class BatchProgressBar extends StatelessWidget {
  const BatchProgressBar({super.key, required this.batch, this.height = 8});

  final MessageBatch batch;
  final double height;

  @override
  Widget build(BuildContext context) {
    final parts = [
      (batch.delivered, AppColors.success),
      (batch.sent - batch.delivered, AppColors.accent),
      (batch.failed, AppColors.error),
      (batch.pending, AppColors.surfaceHighlight),
    ].where((p) => p.$1 > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (parts.isEmpty)
              const Expanded(
                child: ColoredBox(color: AppColors.surfaceHighlight),
              ),
            for (final p in parts)
              Expanded(
                flex: p.$1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  color: p.$2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class BatchTile extends StatelessWidget {
  const BatchTile({super.key, required this.batch, required this.onTap});

  final MessageBatch batch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final classes = batch.classIds.length >= app.academic.runningClasses.length
        ? 'All classes'
        : batch.classIds
              .map((id) => app.academic.classById(id).name)
              .join(', ');
    final (label, color) = batch.pending > 0
        ? (
            batch.isProcessing ? 'Sending' : '${batch.pending} pending',
            AppColors.info,
          )
        : batch.failed > 0
        ? ('${batch.failed} failed', AppColors.error)
        : ('Completed', AppColors.success);
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                icon: categoryIcon(batch.category),
                color: categoryColor(batch.category),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.title,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$classes · ${Fmt.relative(batch.createdAt)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: label, color: color, dense: true),
            ],
          ),
          const SizedBox(height: 12),
          BatchProgressBar(batch: batch, height: 6),
          const SizedBox(height: 8),
          Text(
            '${batch.total} recipients · ${batch.sent} sent · ${batch.delivered} delivered · ${batch.failed} failed',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontFeatures: AppTextStyles.tabular,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Recipient row used in batch details.
class RecipientTile extends StatelessWidget {
  const RecipientTile({super.key, required this.recipient});

  final MessageRecipient recipient;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showAppSheet<void>(
        context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(recipient.studentName, style: AppTextStyles.title),
              Text(
                '${recipient.parentName} · ${Fmt.phone(recipient.phone)}',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: Gap.md),
              MessageBubble(text: recipient.body),
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  MessageStatusChip(status: recipient.status),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Attempts: ${recipient.attempts} · Updated ${Fmt.relative(recipient.updatedAt)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient.studentName,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${recipient.parentName} · ${Fmt.phoneSuffix(recipient.phone)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (recipient.failureReason != null)
                    Text(
                      recipient.failureReason!,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: MessageStatusChip(
                key: ValueKey(recipient.status),
                status: recipient.status,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
