import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/api.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Number to contact parents on: parent's mobile first, else student contact.
String parentNumber(Student s) =>
    s.parentMobile.isNotEmpty ? s.parentMobile : s.contact;

/// Opens the phone's SMS app with [numbers] and [message] pre-filled. The SMS
/// is sent from the user's own SIM after they tap send in that app.
Future<void> openSms(
  BuildContext context,
  List<String> numbers,
  String message,
) async {
  final uri = Uri.parse(
    'sms:${numbers.join(',')}?body=${Uri.encodeComponent(message)}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showError(context, 'Could not open SMS app.');
}

/// Opens WhatsApp (or WhatsApp Business) on [number]'s chat with [message]
/// typed in; the teacher taps send there.
Future<void> openWhatsApp(
  BuildContext context,
  String number,
  String message,
) async {
  var digits = number.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) digits = '91$digits'; // Indian mobile
  final uri = Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showError(context, 'Could not open WhatsApp.');
}

Future<void> openDialer(BuildContext context, String number) async {
  final ok = await launchUrl(
    Uri(scheme: 'tel', path: number),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) showError(context, 'Could not open dialer.');
}

/// Sends SMS directly from this phone's SIM (Android only; see MainActivity.kt).
class SimSms {
  static const _channel = MethodChannel('kaksha/sms');
  static var _seq = 0;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Asks for the SEND_SMS permission if needed. False if refused.
  static Future<bool> ensurePermission() async {
    if (!supported) return false;
    final granted = await _channel.invokeMethod<bool>('hasPermission') ?? false;
    if (granted) return true;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  /// Sends one SMS. `sent` is also true when the phone handed it over but
  /// never confirmed it (reason then says so), so it is not sent twice.
  static Future<({bool sent, String? reason})> send(
    String number,
    String message,
  ) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('send', {
        'id': '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
        'phone': _dialable(number),
        'body': message,
      });
      return switch (res?['status']) {
        'sent' => (sent: true, reason: null),
        'unconfirmed' => (
          sent: true,
          reason: 'Sent, but the phone did not confirm it',
        ),
        _ => (
          sent: false,
          reason: res?['reason'] as String? ?? 'Could not send',
        ),
      };
    } on PlatformException catch (e) {
      return (sent: false, reason: e.message ?? 'Could not send');
    }
  }

  /// Indian 10-digit mobile numbers get +91 so the SIM routes them.
  static String _dialable(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits;
  }
}

/// SMS sent from this phone today, against the plan's daily limit (most
/// Indian plans allow 100/day; changeable in Pending SMS).
class SmsQuota {
  static const _dateKey = 'sms_quota_date';
  static const _usedKey = 'sms_quota_used';
  static const _limitKey = 'sms_quota_limit';

  static int used = 0;
  static int limit = 100;

  static String _today() => AppState.dateKey(DateTime.now());

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    limit = prefs.getInt(_limitKey) ?? 100;
    used = prefs.getString(_dateKey) == _today()
        ? prefs.getInt(_usedKey) ?? 0
        : 0;
  }

  static int get remaining => (limit - used).clamp(0, 100000);

  static Future<void> add(int n) async {
    await load();
    used += n;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, _today());
    await prefs.setInt(_usedKey, used);
  }

  static Future<void> setLimit(int value) async {
    limit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_limitKey, value);
  }
}

class SmsItem {
  const SmsItem({
    required this.name,
    required this.number,
    required this.message,
    this.studentId,
    this.messageId,
    this.status,
    this.sentBy,
  });

  final String name;
  final String number;
  final String message;
  final String? studentId;

  /// Set when the message is already saved on the server (Pending SMS).
  final String? messageId;

  /// Server status when known ('sent' rows are shown as already sent).
  final String? status;
  final String? sentBy;
}

/// Bottom sheet listing one SMS per student.
///
/// The list is saved on the server first (an SMS batch), so messages this
/// phone cannot send — e.g. its daily SMS limit is used up — stay in Pending
/// SMS for the admin or other staff to send from their phones. On Android,
/// SEND TO ALL sends straight from this phone's SIM, one after another.
/// Without SMS permission (or on iPhone) each SEND opens the SMS app instead.
/// [kind]: fees | marks | birthday | receipt | other (absence SMS come from
/// the attendance screen with [batchId]).
/// [batchId]: continue an existing list (items then carry messageId).
/// [dedupeKey]: same key → same list on the server; students already in it
/// are shown as sent instead of being messaged again (e.g. once per day).
Future<void> showSmsSheet(
  BuildContext context, {
  required String title,
  required List<SmsItem> items,
  String kind = 'other',
  String? listTitle,
  String? classId,
  String? batchId,
  String? dedupeKey,
}) async {
  if (items.isEmpty) {
    showInfo(context, 'No students to message.');
    return;
  }
  await SmsQuota.load();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SmsSheet(
      title: title,
      listTitle: listTitle ?? title,
      items: items,
      kind: kind,
      classId: classId,
      batchId: batchId,
      dedupeKey: dedupeKey,
    ),
  );
  appState.refreshSmsBatches().ignore();
}

String _alreadySent(String? by) =>
    'Already sent${by == null || by.isEmpty ? '' : ' by $by'}';

enum _SmsState { idle, sending, sent, failed, opened, elsewhere }

class _SmsSheet extends StatefulWidget {
  const _SmsSheet({
    required this.title,
    required this.listTitle,
    required this.items,
    required this.kind,
    this.classId,
    this.batchId,
    this.dedupeKey,
  });

  final String title;
  final String listTitle;
  final List<SmsItem> items;
  final String kind;
  final String? classId;
  final String? batchId;
  final String? dedupeKey;

  @override
  State<_SmsSheet> createState() => _SmsSheetState();
}

class _SmsSheetState extends State<_SmsSheet> {
  // Gap between messages so the operator does not flag the SIM for spam.
  static const _gap = Duration(milliseconds: 1500);
  static const _whatsAppGreen = Color(0xFF25D366);

  late final _state = [
    for (final it in widget.items)
      it.status == 'sent' ? _SmsState.sent : _SmsState.idle,
  ];
  late final _reason = [
    for (final it in widget.items)
      it.status == 'sent' ? _alreadySent(it.sentBy) : null,
  ];
  late final _ids = [for (final it in widget.items) it.messageId];
  late String? _batchId = widget.batchId;
  bool _sendingAll = false;
  bool _closed = false;

  bool _hasNumber(int i) => widget.items[i].number.isNotEmpty;

  bool _sendable(int i) =>
      _hasNumber(i) &&
      const [_SmsState.idle, _SmsState.failed].contains(_state[i]);

  int get _remaining =>
      List.generate(widget.items.length, _sendable).where((b) => b).length;

  @override
  void dispose() {
    _closed = true; // stops SEND TO ALL after the current message
    super.dispose();
  }

  void _set(int i, _SmsState s, [String? reason]) {
    if (_closed) return;
    setState(() {
      _state[i] = s;
      _reason[i] = reason;
    });
  }

  /// Saves the list on the server once, so unsent messages are visible to all.
  Future<bool> _ensureBatch() async {
    if (_batchId != null) return true;
    final idx = [
      for (var i = 0; i < widget.items.length; i++)
        if (_hasNumber(i)) i,
    ];
    try {
      final (batch, saved) = await appState.createSmsBatch(
        kind: widget.kind,
        title: widget.listTitle,
        classId: widget.classId,
        key: widget.dedupeKey,
        messages: [
          for (final i in idx)
            {
              'student': ?widget.items[i].studentId,
              'name': widget.items[i].name,
              'phone': widget.items[i].number,
              'body': widget.items[i].message,
            },
        ],
      );
      _batchId = batch;
      // The server returns the whole list (with a dedupe key it may already
      // hold messages sent earlier): match rows by student, else by order.
      final byStudent = {
        for (final m in saved)
          if (m.studentId != null) m.studentId!: m,
      };
      final others = saved.where((m) => m.studentId == null).toList();
      for (final i in idx) {
        final sid = widget.items[i].studentId;
        final m = sid != null
            ? byStudent[sid]
            : (others.isEmpty ? null : others.removeAt(0));
        if (m == null) continue;
        _ids[i] = m.id;
        if (m.status == 'sent') _set(i, _SmsState.sent, _alreadySent(m.sentBy));
      }
      return true;
    } catch (e) {
      if (mounted) showError(context, 'Could not save the SMS list: $e');
      return false;
    }
  }

  /// Reports a result; retried once so the list stays right on a bad network.
  /// Returns true when the server says to stop sending this list (STOP was
  /// pressed in Pending SMS).
  Future<bool> _report(
    int i, {
    required bool sent,
    String? reason,
    String channel = 'sms',
  }) async {
    final id = _ids[i];
    if (id == null) return false;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await appState.reportSms(
          id,
          sent: sent,
          reason: reason,
          channel: channel,
        );
        return res.stop;
      } on ApiException catch (e) {
        if (e.status == 409 || e.status == 404) return false;
        await Future<void>.delayed(const Duration(seconds: 1));
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return false;
  }

  /// Reserves message [i] for this phone; false if another phone has it or
  /// it was already sent.
  Future<bool> _claimOne(int i) async {
    final id = _ids[i];
    if (id == null) return true;
    final claimed = await appState
        .claimSms(ids: [id], limit: 1)
        .catchError((_) => <SmsMessage>[]);
    if (claimed.isNotEmpty) return true;
    _set(i, _SmsState.elsewhere);
    if (mounted) {
      showInfo(context, 'Already sent or being sent from another phone.');
    }
    return false;
  }

  /// Sends message [i] from the SIM and records the result. Returns the
  /// failure reason (null when sent) and whether to stop the whole list.
  Future<({String? error, bool stop})> _sendOne(int i) async {
    final it = widget.items[i];
    _set(i, _SmsState.sending);
    final r = await SimSms.send(it.number, it.message);
    if (r.sent) {
      // "Unconfirmed": Android never answered; count it as sent so it is not
      // sent a second time.
      _set(i, _SmsState.sent, r.reason);
      await SmsQuota.add(1);
    } else {
      _set(i, _SmsState.failed, r.reason);
    }
    final stop = await _report(i, sent: r.sent, reason: r.reason);
    return (error: r.sent ? null : r.reason, stop: stop);
  }

  /// True when SMS can go straight from the SIM (asks for permission once).
  Future<bool> _simReady() async {
    if (!SimSms.supported) return false;
    final ok = await SimSms.ensurePermission();
    if (!ok && mounted) {
      showError(
        context,
        'SMS permission was not allowed, so your SMS app will open instead.',
      );
    }
    return ok;
  }

  Future<void> _sendAll() async {
    if (!await _simReady() || _closed) return;
    if (!await _ensureBatch() || !mounted) return;
    await SmsQuota.load();
    if (!mounted) return;
    if (SmsQuota.remaining == 0) {
      await showNotice(
        context,
        "This phone has used today's ${SmsQuota.limit} SMS. The messages are saved "
        'in Pending SMS, so the admin or another staff member can send them from their phone.',
        title: 'Daily SMS limit reached',
      );
      return;
    }
    setState(() => _sendingAll = true);

    List<SmsMessage> claimed;
    try {
      claimed = await appState.claimSms(
        batch: _batchId,
        limit: SmsQuota.remaining.clamp(1, _remaining.clamp(1, 1000)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sendingAll = false);
        showError(context, '$e');
      }
      return;
    }
    final indexOf = {for (var i = 0; i < _ids.length; i++) _ids[i]: i};
    final queue = [for (final m in claimed) ?indexOf[m.id]];
    // Unsent rows not given to this phone are being sent from another phone.
    for (var i = 0; i < widget.items.length; i++) {
      if (_sendable(i) && !queue.contains(i)) _set(i, _SmsState.elsewhere);
    }

    var sent = 0;
    var failedInRow = 0;
    String? stopReason;
    final done = <int>{};
    for (final i in queue) {
      if (_closed) break;
      if (done.isNotEmpty) await Future<void>.delayed(_gap);
      if (_closed) break;
      final r = await _sendOne(i);
      done.add(i);
      if (r.error == null) {
        sent++;
        failedInRow = 0;
      } else if (r.error!.contains('limit') || ++failedInRow >= 3) {
        stopReason =
            r.error; // operator limit / no balance: stop, leave the rest
        break;
      }
      if (r.stop) {
        stopReason = 'this list was stopped from Pending SMS';
        break;
      }
    }
    final leftover = [
      for (final i in queue)
        if (!done.contains(i)) _ids[i]!,
    ];
    await appState.releaseSms(leftover).catchError((_) {});
    if (_closed || !mounted) return;
    setState(() => _sendingAll = false);

    final notSent =
        _remaining + _state.where((s) => s == _SmsState.elsewhere).length;
    if (stopReason != null) {
      await showNotice(
        context,
        'Sending stopped: $stopReason.\n\n$sent sent from this phone. The rest are saved in '
        'Pending SMS for the admin or another staff member to send.',
        title: 'Some SMS not sent',
      );
    } else if (notSent == 0) {
      showSuccess(context, '$sent SMS sent from your SIM');
    } else {
      showInfo(
        context,
        '$sent sent from this phone. $notSent left in Pending SMS for others to send.',
      );
    }
  }

  Future<void> _tapSend(int i) async {
    final it = widget.items[i];
    if (await _simReady()) {
      if (!await _ensureBatch() || !await _claimOne(i)) return;
      await _sendOne(i);
    } else if (mounted) {
      if (!await _ensureBatch() || !await _claimOne(i) || !mounted) return;
      await openSms(context, [it.number], it.message);
      _set(i, _SmsState.opened);
      await _report(i, sent: true, channel: 'sms_app');
    }
  }

  Future<void> _tapWhatsApp(int i) async {
    final it = widget.items[i];
    // Reserve it first so another phone does not SMS the same parent.
    if (!await _ensureBatch() || !await _claimOne(i) || !mounted) return;
    await openWhatsApp(context, it.number, it.message);
    _set(i, _SmsState.opened);
    await _report(i, sent: true, channel: 'whatsapp');
  }

  Widget _trailing(int i) {
    final it = widget.items[i];
    final busy = _sendingAll || it.number.isEmpty;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_state[i] != _SmsState.sent && _state[i] != _SmsState.opened)
          IconButton(
            tooltip: 'WhatsApp',
            onPressed: busy ? null : () => _tapWhatsApp(i),
            icon: Icon(
              Icons.chat,
              color: it.number.isEmpty ? null : _whatsAppGreen,
            ),
          ),
        _smsTrailing(i, busy),
      ],
    );
  }

  Widget _smsTrailing(int i, bool busy) {
    switch (_state[i]) {
      case _SmsState.sending:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case _SmsState.sent:
        return const Icon(Icons.check_circle, color: AppColors.success);
      case _SmsState.opened:
        return const Icon(Icons.mark_chat_read, color: AppColors.success);
      case _SmsState.elsewhere:
        return const Tooltip(
          message: 'Being sent from another phone',
          child: Icon(Icons.phonelink_ring, color: AppColors.textMuted),
        );
      case _SmsState.failed:
      case _SmsState.idle:
        return TextButton(
          onPressed: busy ? null : () => _tapSend(i),
          child: Text(_state[i] == _SmsState.failed ? 'RETRY' : 'SEND'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
    final quota = SmsQuota.remaining;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text(
              SimSms.supported
                  ? 'SMS go from your own SIM · $quota of ${SmsQuota.limit} left today on this phone. '
                        'Anything not sent stays in Pending SMS for others. '
                        'Green chat icon = WhatsApp.'
                  : 'Tap SEND to open your SMS app, or the green chat icon for WhatsApp.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          if (SimSms.supported)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: FilledButton.icon(
                onPressed: _sendingAll || remaining == 0 ? null : _sendAll,
                icon: _sendingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _sendingAll
                      ? 'SENDING…'
                      : remaining == 0
                      ? 'NOTHING LEFT TO SEND'
                      : quota < remaining
                      ? 'SEND $quota NOW (${remaining - quota} LEFT FOR OTHERS)'
                      : 'SEND TO ALL ($remaining)',
                ),
              ),
            ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = widget.items[i];
                final failed = _state[i] == _SmsState.failed;
                final sentNote =
                    _state[i] == _SmsState.sent && _reason[i] != null;
                return ListTile(
                  title: Text(it.name),
                  subtitle: Text(
                    !_hasNumber(i)
                        ? 'No mobile number saved'
                        : failed
                        ? 'Failed: ${_reason[i]}'
                        : sentNote
                        ? _reason[i]!
                        : it.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: !_hasNumber(i) || failed
                          ? AppColors.danger
                          : sentNote
                          ? AppColors.success
                          : null,
                    ),
                  ),
                  trailing: _trailing(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
