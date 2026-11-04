import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final granted =
        await _channel.invokeMethod<bool>('hasPermission') ?? false;
    if (granted) return true;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  /// Sends one SMS; returns null when sent, else the reason it failed.
  static Future<String?> send(String number, String message) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('send', {
        'id': '${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
        'phone': _dialable(number),
        'body': message,
      });
      return res?['status'] == 'sent'
          ? null
          : (res?['reason'] as String? ?? 'Could not send');
    } on PlatformException catch (e) {
      return e.message ?? 'Could not send';
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

class SmsItem {
  const SmsItem({
    required this.name,
    required this.number,
    required this.message,
  });

  final String name;
  final String number;
  final String message;
}

/// Bottom sheet listing one SMS per student. On Android, SEND TO ALL sends every
/// message straight from the teacher's SIM, one after another; each row shows
/// its result. Without SMS permission (or on iPhone) each SEND opens the SMS app
/// instead. Students without a number are shown but skipped.
Future<void> showSmsSheet(
  BuildContext context, {
  required String title,
  required List<SmsItem> items,
}) {
  if (items.isEmpty) {
    showInfo(context, 'No students to message.');
    return Future.value();
  }
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SmsSheet(title: title, items: items),
  );
}

enum _SmsState { idle, sending, sent, failed, opened }

class _SmsSheet extends StatefulWidget {
  const _SmsSheet({required this.title, required this.items});

  final String title;
  final List<SmsItem> items;

  @override
  State<_SmsSheet> createState() => _SmsSheetState();
}

class _SmsSheetState extends State<_SmsSheet> {
  // Gap between messages so the operator does not flag the SIM for spam.
  static const _gap = Duration(milliseconds: 1500);

  late final _state = List.filled(widget.items.length, _SmsState.idle);
  late final _reason = List<String?>.filled(widget.items.length, null);
  bool _sendingAll = false;
  bool _closed = false;

  bool _sendable(int i) =>
      widget.items[i].number.isNotEmpty &&
      _state[i] != _SmsState.sent &&
      _state[i] != _SmsState.sending;

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

  Future<void> _sendOne(int i) async {
    final it = widget.items[i];
    _set(i, _SmsState.sending);
    final error = await SimSms.send(it.number, it.message);
    _set(i, error == null ? _SmsState.sent : _SmsState.failed, error);
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
    setState(() => _sendingAll = true);
    var first = true;
    for (var i = 0; i < widget.items.length; i++) {
      if (_closed) return;
      if (!_sendable(i)) continue;
      if (!first) await Future<void>.delayed(_gap);
      first = false;
      if (_closed) return;
      await _sendOne(i);
    }
    if (_closed || !mounted) return;
    setState(() => _sendingAll = false);
    final sent = _state.where((s) => s == _SmsState.sent).length;
    final failed = _state.where((s) => s == _SmsState.failed).length;
    if (failed == 0) {
      showSuccess(context, '$sent SMS sent from your SIM');
    } else {
      showError(
        context,
        '$sent sent, $failed failed. Tap RETRY on failed ones.',
      );
    }
  }

  Future<void> _tapSend(int i) async {
    if (await _simReady()) {
      await _sendOne(i);
    } else if (mounted) {
      final it = widget.items[i];
      await openSms(context, [it.number], it.message);
      _set(i, _SmsState.opened);
    }
  }

  Widget _trailing(int i) {
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
        return const Icon(Icons.open_in_new, color: AppColors.success);
      case _SmsState.failed:
      case _SmsState.idle:
        return TextButton(
          onPressed: widget.items[i].number.isEmpty || _sendingAll
              ? null
              : () => _tapSend(i),
          child: Text(_state[i] == _SmsState.failed ? 'RETRY' : 'SEND'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining;
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
                  ? 'Messages go from your own SIM (normal SMS charges of your plan).'
                  : 'Tap SEND to open your SMS app. Messages go from your own SIM.',
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
                      ? 'ALL SENT'
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
                final hasNumber = it.number.isNotEmpty;
                final failed = _state[i] == _SmsState.failed;
                return ListTile(
                  title: Text(it.name),
                  subtitle: Text(
                    !hasNumber
                        ? 'No mobile number saved'
                        : failed
                        ? 'Failed: ${_reason[i]}'
                        : it.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasNumber && !failed ? null : AppColors.danger,
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
