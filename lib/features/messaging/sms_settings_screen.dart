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

/// Sending settings. Connected mode: send from this phone's SIM or simulate.
/// Offline (test) mode keeps the original labelled mock screen.
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

    if (app.isRemote) return const _RemoteSmsSettings();

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

class _RemoteSmsSettings extends StatefulWidget {
  const _RemoteSmsSettings();

  @override
  State<_RemoteSmsSettings> createState() => _RemoteSmsSettingsState();
}

class _RemoteSmsSettingsState extends State<_RemoteSmsSettings> {
  final _name = TextEditingController();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _name.text = context.appRead.smsSender?.deviceName ?? 'Tuition phone';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _set(bool useThisPhone) async {
    if (useThisPhone && _name.text.trim().isEmpty) {
      AppToast.show(context, 'Give this phone a name', type: ToastType.error);
      return;
    }
    setState(() => _busy = true);
    await runAction(
      context,
      () => context.appRead.setSmsMode(
        useThisPhone: useThisPhone,
        deviceName: _name.text.trim(),
      ),
      success: useThisPhone
          ? 'This phone will now send parent SMS'
          : 'Switched to simulated sending',
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final sms = app.messaging.sms;
    final sender = app.smsSender;
    final deviceMode = sms.mode == SendingMode.androidDevice;
    final thisPhone = deviceMode && (sender?.enabled ?? false);
    final failedBatches = app.messaging.batches
        .where((b) => b.failed > 0)
        .toList();

    return AppScaffold(
      title: 'SMS settings',
      subtitle: 'Messaging · Admin',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          if (!deviceMode)
            const DemoNotice(
              icon: Icons.info_outline_rounded,
              color: AppColors.warning,
              text:
                  'Sending is simulated — parents do not receive real SMS. Turn on "Send from this '
                  'phone" below to send real SMS using this phone\'s SIM.',
            )
          else if (thisPhone)
            const DemoNotice(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              text:
                  'Real SMS are sent from this phone\'s SIM and charged to its plan. Keep TutorDesk '
                  'open on this phone with mobile network on — messages wait in the queue while it is closed.',
            )
          else
            DemoNotice(
              icon: Icons.smartphone_rounded,
              color: AppColors.info,
              text:
                  'Real SMS are sent by "${sms.deviceName}". Messages wait in the queue until TutorDesk '
                  'is open on that phone.',
            ),
          const SizedBox(height: Gap.lg),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconWell(icon: Icons.sim_card_outlined, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Send from this phone',
                            style: AppTextStyles.titleSmall,
                          ),
                          Text(
                            'Uses this phone\'s SIM plan',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Switch(value: thisPhone, onChanged: _busy ? null : _set),
                  ],
                ),
                if (!thisPhone) ...[
                  const SizedBox(height: Gap.md),
                  CustomTextField(
                    label: 'Name for this phone',
                    controller: _name,
                    hint: 'e.g. Office phone (Jio)',
                  ),
                ],
              ],
            ),
          ),
          if (thisPhone && sender != null) ...[
            const SectionHeader(
              title: 'Sender status',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
            ),
            InfoRow(label: 'Phone', value: sender.deviceName),
            InfoRow(
              label: 'Status',
              value: sender.isRunning ? 'Running' : 'Stopped',
            ),
            InfoRow(
              label: 'Last checked',
              value: sender.lastCheck == null
                  ? 'Not yet'
                  : Fmt.relative(sender.lastCheck!),
            ),
            InfoRow(
              label: 'Sent / failed (since app opened)',
              value: '${sender.sentThisSession} / ${sender.failedThisSession}',
            ),
            if (sender.lastError != null)
              InfoRow(label: 'Last problem', value: sender.lastError!),
            const SizedBox(height: Gap.sm),
            SecondaryButton(
              label: 'Check for messages now',
              icon: Icons.sync_rounded,
              onPressed: sender.checkNow,
            ),
          ] else if (deviceMode)
            InfoRow(
              label: 'Sender last online',
              value: sms.lastSync.year < 2001
                  ? 'Never'
                  : Fmt.relative(sms.lastSync),
            ),
          const SizedBox(height: Gap.md),
          InfoRow(
            label: deviceMode ? 'SMS sent this month' : 'Simulated this month',
            value: '${sms.usedThisMonth}',
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Indian operators usually allow about 100 SMS a day on prepaid plans. Messages are '
            'sent 1.5 seconds apart. If the phone takes a message but never confirms it, it is '
            'marked failed after 10 minutes and is never re-sent automatically — use Retry.',
            style: AppTextStyles.caption,
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
