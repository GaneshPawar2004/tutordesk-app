import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

String _when(DateTime d) {
  final t = TimeOfDay.fromDateTime(d);
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '${formatDate(d)} $h:${t.minute.toString().padLeft(2, '0')} '
      '${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// Parent SMS lists of the last 7 days: what is still unsent (any phone can
/// send it) and who sent the rest. Open to the admin and all staff.
class PendingSmsScreen extends StatefulWidget {
  const PendingSmsScreen({super.key});

  @override
  State<PendingSmsScreen> createState() => _PendingSmsScreenState();
}

class _PendingSmsScreenState extends State<PendingSmsScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
    SmsQuota.load().then((_) => mounted ? setState(() {}) : null);
  }

  Future<void> _refresh() async {
    try {
      await appState.refreshSmsBatches();
    } catch (e) {
      if (mounted) showError(context, '$e');
    }
  }

  /// Opens the SMS sheet with the unsent messages of [b].
  Future<void> _send(SmsBatch b) async {
    final messages = await runApiValue(
      context,
      () => appState.loadSmsBatch(b.id),
    );
    if (messages == null || !mounted) return;
    final unsent = messages.where((m) => m.unsent).toList();
    if (unsent.isEmpty) {
      showInfo(context, 'Everything in this list has been sent.');
      await _refresh();
      return;
    }
    await showSmsSheet(
      context,
      title: '${b.title} (${unsent.length} left)',
      batchId: b.id,
      kind: b.kind,
      items: [
        for (final m in unsent)
          SmsItem(
            name: m.name,
            number: m.phone,
            message: m.body,
            studentId: m.studentId,
            messageId: m.id,
          ),
      ],
    );
    await SmsQuota.load();
    if (mounted) setState(() {});
  }

  Future<void> _dismiss(SmsBatch b) async {
    final ok = await confirmDialog(
      context,
      title: 'Stop sending?',
      message:
          'The ${b.remaining} unsent SMS of "${b.title}" will not be sent by anyone.',
      confirmLabel: 'STOP',
    );
    if (ok && mounted) {
      await runApi(context, () => appState.dismissSmsBatch(b.id));
    }
  }

  Future<void> _editLimit() async {
    final ctrl = TextEditingController(text: '${SmsQuota.limit}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily SMS limit of this phone'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How many SMS your mobile plan allows per day (usually 100). '
              'The app stops at this number and leaves the rest for others.',
              style: TextStyle(fontSize: 13),
            ),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              final n = int.tryParse(ctrl.text);
              if (n != null && n > 0 && n <= 10000) Navigator.pop(ctx, n);
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await SmsQuota.setLimit(value);
    await SmsQuota.load();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending SMS')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final pending = appState.smsBatches
              .where((b) => b.remaining > 0)
              .toList();
          final done = appState.smsBatches
              .where((b) => b.remaining == 0)
              .toList();
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.sim_card_outlined,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'This phone: ${SmsQuota.used} of ${SmsQuota.limit} SMS used today',
                    ),
                    subtitle: Text(
                      '${SmsQuota.remaining} left · tap to change the limit',
                    ),
                    onTap: _editLimit,
                  ),
                ),
                const SizedBox(height: 8),
                _Heading('Not sent yet (${appState.pendingSms})'),
                if (pending.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'All parent SMS have been sent. 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final b in pending)
                  _BatchCard(
                    batch: b,
                    onOpen: () => _openDetail(b),
                    actions: [
                      TextButton(
                        onPressed: () => _dismiss(b),
                        child: const Text(
                          'STOP',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _send(b),
                        icon: const Icon(Icons.send, size: 18),
                        label: Text('SEND ${b.remaining} FROM MY PHONE'),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                const _Heading('Sent in the last 7 days'),
                if (done.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'Nothing yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                for (final b in done)
                  _BatchCard(batch: b, onOpen: () => _openDetail(b)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail(SmsBatch b) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SmsBatchScreen(batch: b)));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.onOpen,
    this.actions = const [],
  });

  final SmsBatch batch;
  final VoidCallback onOpen;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    final senders = b.senders.map((s) => '${s.name} ${s.count}').join(', ');
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${b.sent} of ${b.total} sent'
                '${b.remaining > 0 ? ' · ${b.remaining} left' : ''}'
                '${b.failed > 0 ? ' · ${b.failed} failed' : ''}'
                '${b.expired ? ' · rest expired' : ''}',
                style: TextStyle(
                  color: b.remaining > 0 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Started by ${b.createdBy.isEmpty ? '—' : b.createdBy} · ${_when(b.createdAt)}'
                '${senders.isEmpty ? '' : '\nSent by $senders'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              // Wraps onto a second line on narrow phones.
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    TextButton(onPressed: onOpen, child: const Text('VIEW')),
                    ...actions,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every student of one SMS list with its status: sent (by whom, when),
/// not sent yet, failed (reason) or stopped.
class SmsBatchScreen extends StatelessWidget {
  const SmsBatchScreen({super.key, required this.batch});
  final SmsBatch batch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(batch.title)),
      body: FutureBuilder<List<SmsMessage>>(
        future: appState.loadSmsBatch(batch.id),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              message: '${snap.error}',
            );
          }
          final list = snap.data!;
          final unsent = list.where((m) => m.unsent).toList();
          final rest = list.where((m) => !m.unsent).toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (unsent.isNotEmpty) ...[
                Text(
                  'Not sent yet (${unsent.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                for (final m in unsent) _MessageTile(m),
                const SizedBox(height: 12),
              ],
              Text(
                'Sent / stopped (${rest.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final m in rest) _MessageTile(m),
            ],
          );
        },
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile(this.m);
  final SmsMessage m;

  @override
  Widget build(BuildContext context) {
    final (icon, color, detail) = switch (m.status) {
      'sent' => (
        Icons.check_circle,
        AppColors.success,
        'Sent${m.channel == 'whatsapp' ? ' on WhatsApp' : ''}'
            '${m.sentBy == null ? '' : ' by ${m.sentBy}'}'
            '${m.sentAt == null ? '' : ' · ${_when(m.sentAt!)}'}',
      ),
      'failed' => (
        Icons.error_outline,
        AppColors.danger,
        'Failed: ${m.reason ?? ''}',
      ),
      'dismissed' => (Icons.block, AppColors.textMuted, 'Stopped'),
      _ => (Icons.schedule, AppColors.warning, 'Not sent yet'),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(m.name),
      subtitle: Text(
        '${m.phone} · $detail',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
