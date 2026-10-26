import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'announcement_screen.dart';
import 'batch_detail_screen.dart';
import 'message_widgets.dart';
import 'sms_settings_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  MessageCategory? _category;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.canOpenMessages) {
      return const AppScaffold(
        title: 'Messages',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Messaging is disabled',
          message:
              'The admin has not enabled parent messaging for your account.',
        ),
      );
    }
    final stats = app.messageStats;
    final categories = MessageCategory.values
        .where((c) => app.isAdmin || c != MessageCategory.feeReminder)
        .toList();
    final batches = app.visibleBatches
        .where((b) => _category == null || b.category == _category)
        .toList();
    final sms = app.messaging.sms;

    return AppScaffold(
      title: 'Messages',
      subtitle: 'Parent messages & SMS centre',
      actions: [
        if (app.isAdmin)
          IconButton(
            tooltip: 'SMS settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => pushPage(context, const SmsSettingsScreen()),
          ),
      ],
      floatingActionButton: app.canSendMessages
          ? FloatingActionButton.extended(
              onPressed: () => pushPage(context, const AnnouncementScreen()),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Announcement', style: AppTextStyles.button),
            )
          : null,
      body: SimulatedLoad(
        rows: 4,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: MetricCard(
                            label: 'Sent today',
                            value: '${stats.sentToday}',
                            icon: Icons.send_outlined,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: 'Failed',
                            value: '${stats.failed}',
                            icon: Icons.error_outline_rounded,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetricCard(
                            label: 'Pending',
                            value: '${stats.pending}',
                            icon: Icons.schedule_rounded,
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SurfaceCard(
                    onTap: app.isAdmin
                        ? () => pushPage(context, const SmsSettingsScreen())
                        : null,
                    child: Row(
                      children: [
                        const IconWell(
                          icon: Icons.smartphone_rounded,
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sms.mode.label,
                                style: AppTextStyles.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                sms.mode == SendingMode.androidDevice
                                    ? '${sms.deviceName} · synced ${Fmt.relative(sms.lastSync)}'
                                    : 'Mock configuration',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const StatusChip(
                          label: 'Demo',
                          color: AppColors.info,
                          dense: true,
                        ),
                      ],
                    ),
                  ),
                  if (!app.canSendMessages) ...[
                    const SizedBox(height: 12),
                    const DemoNotice(
                      icon: Icons.lock_outline_rounded,
                      color: AppColors.warning,
                      text:
                          'SMS sending is disabled for your account. You can view batches but not send or retry.',
                    ),
                  ],
                ],
              ),
            ),
            const SectionHeader(title: 'Categories'),
            FilterChips(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in categories)
                  ChoiceChip(
                    avatar: Icon(
                      categoryIcon(c),
                      size: 16,
                      color: _category == c
                          ? AppColors.onAccent
                          : categoryColor(c),
                    ),
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected: (_) =>
                        setState(() => _category = _category == c ? null : c),
                  ),
              ],
            ),
            const SectionHeader(title: 'Recent batches'),
            if (batches.isEmpty)
              EmptyState(
                icon: Icons.forum_outlined,
                title: 'No messages',
                message: _category == null
                    ? 'Batches appear here when you notify parents about attendance, results or announcements.'
                    : 'No ${_category!.label.toLowerCase()} have been sent yet.',
                actionLabel: app.canSendMessages ? 'New announcement' : null,
                onAction: app.canSendMessages
                    ? () => pushPage(context, const AnnouncementScreen())
                    : null,
              )
            else
              for (final b in batches)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 12),
                  child: BatchTile(
                    batch: b,
                    onTap: () =>
                        pushPage(context, BatchDetailScreen(batchId: b.id)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
