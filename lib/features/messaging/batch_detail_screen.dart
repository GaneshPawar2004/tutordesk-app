import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'message_widgets.dart';

/// Live status of one message batch with safe retry of failures only.
class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({super.key, required this.batchId});

  final String batchId;

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  DeliveryStatus? _filter;

  Future<void> _retry(MessageBatch batch) async {
    final app = context.appRead;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Retry ${Fmt.plural(batch.failed, 'failed message')}?',
      message:
          'Only failed recipients are retried. Parents who already received this message are not messaged again.',
      confirmLabel: 'Retry failed',
      icon: Icons.refresh_rounded,
    );
    if (!ok || !mounted) return;
    final count = app.messaging.retryFailed(batch);
    AppToast.show(
      context,
      'Retrying ${Fmt.plural(count, 'message')}',
      type: ToastType.info,
    );
  }

  void _processPending(MessageBatch batch) {
    final count = context.appRead.messaging.processPending(batch);
    AppToast.show(
      context,
      'Sending ${Fmt.plural(count, 'pending message')}',
      type: ToastType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final batch = app.messaging.byId(widget.batchId);
    if (batch == null ||
        (batch.category == MessageCategory.feeReminder && !app.isAdmin)) {
      return const AppScaffold(
        title: 'Message batch',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available',
          message: 'This batch is not available for your account.',
        ),
      );
    }
    final recipients = _filter == null
        ? batch.recipients
        : batch.recipients
              .where(
                (r) =>
                    r.status == _filter ||
                    (_filter == DeliveryStatus.queued && r.status.isPending),
              )
              .toList();
    final classes = batch.classIds.length >= app.academic.runningClasses.length
        ? 'All classes'
        : batch.classIds
              .map((id) => app.academic.classById(id).name)
              .join(', ');
    final stuck = app.messaging.hasStuckPending(batch);
    final canSend = app.canSendMessages;

    return AppScaffold(
      title: batch.title,
      subtitle: batch.category.label,
      bottomBar: canSend && (batch.failed > 0 || stuck)
          ? Row(
              children: [
                if (stuck)
                  Expanded(
                    child: SecondaryButton(
                      label: 'Send pending',
                      icon: Icons.schedule_send_outlined,
                      onPressed: () => _processPending(batch),
                    ),
                  ),
                if (stuck && batch.failed > 0) const SizedBox(width: 12),
                if (batch.failed > 0)
                  Expanded(
                    child: PrimaryButton(
                      label: 'Retry ${batch.failed} failed',
                      icon: Icons.refresh_rounded,
                      onPressed: batch.isProcessing
                          ? null
                          : () => _retry(batch),
                    ),
                  ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SmsDemoBanner(),
                const SizedBox(height: Gap.md),
                CreamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatBlock(
                              label: 'Recipients',
                              value: '${batch.total}',
                              onCream: true,
                            ),
                          ),
                          Expanded(
                            child: StatBlock(
                              label: 'Sent',
                              value: '${batch.sent}',
                              onCream: true,
                            ),
                          ),
                          Expanded(
                            child: StatBlock(
                              label: 'Failed',
                              value: '${batch.failed}',
                              onCream: true,
                              valueColor: batch.failed > 0
                                  ? const Color(0xFFC03A3B)
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: StatBlock(
                              label: 'Pending',
                              value: '${batch.pending}',
                              onCream: true,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.md),
                      BatchProgressBar(batch: batch),
                      const SizedBox(height: 10),
                      Text(
                        '${batch.delivered} delivered (confirmed by device) · ${batch.sent - batch.delivered} sent without a delivery report',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textOnCreamMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(
                  title: 'Batch details',
                  padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
                ),
                InfoRow(label: 'Class', value: classes),
                InfoRow(label: 'Created by', value: batch.createdBy),
                InfoRow(
                  label: 'Date & time',
                  value:
                      '${Fmt.date(batch.createdAt)}, ${Fmt.time(batch.createdAt)}',
                ),
                InfoRow(label: 'Category', value: batch.category.label),
                const SectionHeader(
                  title: 'Message preview',
                  padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
                ),
                MessageBubble(text: batch.previewBody),
              ],
            ),
          ),
          const SectionHeader(title: 'Recipients'),
          FilterChips(
            children: [
              ChoiceChip(
                label: Text('All ${batch.total}'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final (status, count) in [
                (DeliveryStatus.delivered, batch.delivered),
                (DeliveryStatus.sent, batch.sent - batch.delivered),
                (DeliveryStatus.failed, batch.failed),
                (DeliveryStatus.queued, batch.pending),
              ])
                ChoiceChip(
                  label: Text(
                    '${status == DeliveryStatus.queued ? 'Pending' : status.label} $count',
                  ),
                  selected: _filter == status,
                  onSelected: (_) => setState(
                    () => _filter = _filter == status ? null : status,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (recipients.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.inbox_outlined,
              title: 'No messages',
              message: 'No recipients have this status.',
            )
          else
            for (var i = 0; i < recipients.length; i++) ...[
              if (i > 0) const InsetDivider(),
              RecipientTile(recipient: recipients[i]),
            ],
          if (!canSend && batch.failed > 0)
            Padding(
              padding: const EdgeInsets.all(Gap.page),
              child: Text(
                'Retrying is not enabled for your account.',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
