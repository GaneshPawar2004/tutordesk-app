import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// Turns this phone into the tuition's SMS sender ("device" transport).
///
/// While enabled and the app is open, it asks the server for queued parent
/// messages, sends each from this phone's SIM (see MainActivity.kt) and reports
/// sent / failed / delivered back. Messages are spaced out so the operator does
/// not flag the SIM for spam.
class SmsSender {
  SmsSender(this._api, this._onChange) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'delivered') {
        _report((call.arguments as Map)['id'] as String, 'delivered');
      }
    });
  }

  static const _channel = MethodChannel('tutordesk/sms');
  static const _enabledKey = 'sms_sender_enabled';
  static const _nameKey = 'sms_sender_name';
  static const _pollEvery = Duration(seconds: 8);
  static const _gap = Duration(milliseconds: 1500);

  final ApiClient _api;
  final void Function() _onChange;

  bool enabled = false;
  String deviceName = 'Tuition phone';
  int sentThisSession = 0;
  int failedThisSession = 0;
  String? lastError;
  DateTime? lastCheck;
  bool get isRunning => _timer != null;

  Timer? _timer;
  var _busy = false;

  /// Reports that could not reach the server yet; retried on the next check.
  final _unreported = <({String id, String status, String? reason})>[];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_enabledKey) ?? false;
    deviceName = prefs.getString(_nameKey) ?? deviceName;
  }

  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  /// Asks Android for SEND_SMS. Returns false if the user refused.
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  Future<void> setEnabled(bool value, {String? name}) async {
    final prefs = await SharedPreferences.getInstance();
    enabled = value;
    if (name != null && name.trim().isNotEmpty) deviceName = name.trim();
    await prefs.setBool(_enabledKey, value);
    await prefs.setString(_nameKey, deviceName);
    value ? start() : stop();
    _onChange();
  }

  void start() {
    if (!enabled || _timer != null) return;
    _timer = Timer.periodic(_pollEvery, (_) => checkNow());
    checkNow();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One round: flush old reports, claim queued messages, send them one by one.
  Future<void> checkNow() async {
    if (_busy || !enabled || _api.token == null) return;
    _busy = true;
    try {
      await _flushReports();
      final res =
          await _api.post('/sms-device/claim', {
                'limit': 5,
                'deviceName': deviceName,
              })
              as Map<String, dynamic>;
      lastCheck = DateTime.now();
      lastError = null;
      final messages = (res['messages'] as List).cast<Map<String, dynamic>>();
      for (final (i, m) in messages.indexed) {
        if (i > 0) await Future<void>.delayed(_gap);
        final result = await _channel.invokeMapMethod<String, dynamic>('send', {
          'id': m['id'],
          'phone': _dialable(m['phone'] as String),
          'body': m['body'],
        });
        final status = result?['status'] as String? ?? 'failed';
        final reason = result?['reason'] as String?;
        status == 'sent' ? sentThisSession++ : failedThisSession++;
        if (status != 'sent') lastError = reason;
        await _report(m['id'] as String, status, reason);
        _onChange();
      }
    } on ApiException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'Could not reach the server';
    } finally {
      _busy = false;
      _onChange();
    }
  }

  /// Indian 10-digit mobile numbers are sent with +91 so the SIM routes them.
  static String _dialable(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return digits;
  }

  Future<void> _report(String id, String status, [String? reason]) async {
    try {
      await _api.post('/sms-device/report', {
        'id': id,
        'status': status,
        'reason': ?reason,
      });
    } catch (_) {
      _unreported.add((id: id, status: status, reason: reason));
    }
  }

  Future<void> _flushReports() async {
    final queue = [..._unreported];
    _unreported.clear();
    for (final r in queue) {
      await _report(r.id, r.status, r.reason);
    }
  }
}
