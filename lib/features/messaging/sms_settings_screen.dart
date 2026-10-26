import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'batch_detail_screen.dart';

/// Provider-neutral sending settings. Every value here is a labelled mock.
class SmsSettingsScreen extends StatelessWidget {
  const SmsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) {
      return const AppScaffold(
        title: 'SMS settings',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Admin only',
          message: 'Messaging settings are managed by the admin.',
        ),
      );
    }
    final sms = app.messaging.sms;
    final usage = sms.monthlyAllowance == 0
        ? 0.0
        : sms.usedThisMonth / sms.monthlyAllowance;
    final failedBatches = app.messaging.batches
        .where((b) => b.failed > 0)
        .toList();

    return AppScaffold(
      title: 'SMS settings',
      subtitle: 'Messaging · Admin',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          const DemoNotice(
            icon: Icons.info_outline_rounded,
            color: AppColors.warning,
            text:
                'No SMS provider or phone is connected. All values on this screen are mock values. '
                'An ordinary SIM recharge balance cannot be read by a server, and delivery can only be '
                'shown when the sending device or gateway reports it.',
          ),
          const SizedBox(height: Gap.lg),
          SelectField<SendingMode>(
            label: 'Sending mode',
            value: sms.mode,
            options: [
              const SelectOption(
                SendingMode.androidDevice,
                'Phone SIM via Android device',
                subtitle: 'A tuition phone sends messages using its SIM plan',
              ),
              const SelectOption(
                SendingMode.gateway,
                'SMS gateway',
                subtitle: 'A bulk SMS provider (future integration)',
              ),
              const SelectOption(
                SendingMode.notConfigured,
                'Not configured',
                subtitle: 'Messages stay in the outbox',
              ),
            ],
            onChanged: (m) => app.messaging.updateSettings((s) => s.mode = m),
          ),
          if (sms.mode == SendingMode.androidDevice) ...[
            const SectionHeader(
              title: 'Sending device',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
            ),
            SurfaceCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      const IconWell(icon: Icons.smartphone_rounded, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sms.deviceName,
                              style: AppTextStyles.titleSmall,
                            ),
                            Text(
                              'Last sync ${Fmt.relative(sms.lastSync)}',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      const StatusChip(
                        label: 'Mock',
                        color: AppColors.info,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  SecondaryButton(
                    label: 'Sync now (demo)',
                    icon: Icons.sync_rounded,
                    onPressed: () {
                      app.messaging.syncDevice();
                      AppToast.show(
                        context,
                        'Demo sync complete',
                        type: ToastType.info,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          if (sms.mode != SendingMode.notConfigured) ...[
            const SectionHeader(
              title: 'Message allowance',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
            ),
            CreamCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatBlock(
                          label: 'Used this month',
                          value: '${sms.usedThisMonth}',
                          onCream: true,
                        ),
                      ),
                      Expanded(
                        child: StatBlock(
                          label: 'Allowance',
                          value: '${sms.monthlyAllowance}',
                          onCream: true,
                          alignEnd: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.md),
                  ProgressBar(
                    value: usage,
                    color: AppColors.accentPressed,
                    trackColor: AppColors.creamTrack,
                    height: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mock value entered manually · not read from any SIM or provider',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textOnCreamMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader(
            title: 'Preferences',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sms.includeTuitionName,
            onChanged: (v) =>
                app.messaging.updateSettings((s) => s.includeTuitionName = v),
            title: Text(
              'Sign messages with tuition name',
              style: AppTextStyles.titleSmall,
            ),
            subtitle: Text(sms.senderSignature, style: AppTextStyles.caption),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sms.autoSuggestAttendance,
            onChanged: (v) => app.messaging.updateSettings(
              (s) => s.autoSuggestAttendance = v,
            ),
            title: Text(
              'Suggest notifying parents after attendance',
              style: AppTextStyles.titleSmall,
            ),
            subtitle: Text(
              'Teachers still confirm before anything is sent',
              style: AppTextStyles.caption,
            ),
          ),
          const SectionHeader(
            title: 'Failed messages',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
          ),
          if (failedBatches.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.task_alt_rounded,
              title: 'No failures',
              message: 'All batches were sent successfully.',
            )
          else
            for (final b in failedBatches)
              NavRow(
                icon: Icons.error_outline_rounded,
                color: AppColors.error,
                title: b.title,
                subtitle:
                    '${Fmt.plural(b.failed, 'failed message')} · tap to retry',
                onTap: () =>
                    pushPage(context, BatchDetailScreen(batchId: b.id)),
              ),
        ],
      ),
    );
  }
}
