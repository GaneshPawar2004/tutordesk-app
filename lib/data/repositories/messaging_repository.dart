import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../shared/models/models.dart';
import 'mock_repository.dart';

/// Abstraction over how messages actually leave the system (phone SIM,
/// gateway, …). The UI and batch logic never depend on a concrete transport.
abstract class MessageTransport {
  /// Begin sending [recipients]. Implementations update each recipient's
  /// status, call [onUpdate] whenever something changes, and call [onSettled]
  /// once a recipient reaches a final state for this attempt.
  void dispatch(
    List<MessageRecipient> recipients, {
    required VoidCallback onUpdate,
    required void Function(MessageRecipient r) onSettled,
  });

  void dispose();
}

/// Local simulation used in the static phase. No real SMS is ever sent.
///
/// Roughly one in six numbers fails on its first attempt so retry flows can be
/// demonstrated; retries always succeed. Even-ending numbers get a delivery
/// report, odd-ending ones stay at "sent" (as many SIM setups cannot confirm
/// delivery).
class SimulatedMessageTransport implements MessageTransport {
  SimulatedMessageTransport({this.speed = 1.0});

  final double speed;
  final _timers = <Timer>[];

  Duration _ms(int value) => Duration(milliseconds: (value / speed).round());

  void _after(Duration d, VoidCallback fn) => _timers.add(Timer(d, fn));

  static bool _failsFirstAttempt(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final tail = int.tryParse(digits.substring(digits.length - 2)) ?? 0;
    return tail % 6 == 0;
  }

  @override
  void dispatch(
    List<MessageRecipient> recipients, {
    required VoidCallback onUpdate,
    required void Function(MessageRecipient r) onSettled,
  }) {
    final stagger = recipients.length > 40 ? 70 : 220;
    for (var i = 0; i < recipients.length; i++) {
      final r = recipients[i];
      r
        ..status = DeliveryStatus.queued
        ..failureReason = null
        ..updatedAt = DateTime.now();
      _after(_ms(300 + i * stagger), () {
        r
          ..status = DeliveryStatus.sending
          ..updatedAt = DateTime.now();
        onUpdate();
        _after(_ms(650), () {
          r.attempts += 1;
          final fail = r.attempts == 1 && _failsFirstAttempt(r.phone);
          r
            ..status = fail ? DeliveryStatus.failed : DeliveryStatus.sent
            ..failureReason = fail ? 'Device reported send failure' : null
            ..updatedAt = DateTime.now();
          if (fail || r.phone.codeUnitAt(r.phone.length - 1).isOdd) {
            onSettled(r);
            onUpdate();
            return;
          }
          onUpdate();
          _after(_ms(1400), () {
            r
              ..status = DeliveryStatus.delivered
              ..updatedAt = DateTime.now();
            onSettled(r);
            onUpdate();
          });
        });
      });
    }
    onUpdate();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }
}

class RecipientDraft {
  const RecipientDraft({
    required this.studentName,
    required this.parentName,
    required this.phone,
    required this.body,
    this.studentId,
  });

  final String? studentId;
  final String studentName;
  final String parentName;
  final String phone;
  final String body;
}

class BatchResult {
  const BatchResult(this.batch, {required this.created});

  final MessageBatch batch;

  /// False when a batch already existed for this source; nothing new was sent.
  final bool created;
}

class MessagingRepository extends MockRepository {
  MessagingRepository(
    super.onChanged, {
    required this._batches,
    required this.sms,
    required this._transport,
    this.onBatchSettled,
  });

  final List<MessageBatch> _batches;
  final SmsSettings sms;
  final MessageTransport _transport;
  final void Function(MessageBatch batch)? onBatchSettled;
  final _inFlight = <String>{};
  var _counter = 1000;

  /// Newest first.
  List<MessageBatch> get batches =>
      [..._batches]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  MessageBatch? byId(String id) {
    for (final b in _batches) {
      if (b.id == id) return b;
    }
    return null;
  }

  MessageBatch? bySource(String sourceKey) {
    for (final b in _batches) {
      if (b.sourceKey == sourceKey) return b;
    }
    return null;
  }

  /// Creates and dispatches a batch — unless one already exists for
  /// [sourceKey], in which case the existing batch is returned untouched.
  /// This is what makes repeated taps and re-opened screens safe.
  BatchResult createBatch({
    required String sourceKey,
    required String title,
    required MessageCategory category,
    required List<String> classIds,
    required String createdBy,
    required String previewBody,
    required List<RecipientDraft> recipients,
  }) {
    final existing = bySource(sourceKey);
    if (existing != null) return BatchResult(existing, created: false);
    final id = 'bat-${++_counter}';
    final batch = MessageBatch(
      id: id,
      sourceKey: sourceKey,
      title: title,
      category: category,
      classIds: classIds,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      previewBody: previewBody,
      recipients: [
        for (var i = 0; i < recipients.length; i++)
          MessageRecipient(
            id: '$id-r$i',
            studentId: recipients[i].studentId,
            studentName: recipients[i].studentName,
            parentName: recipients[i].parentName,
            phone: recipients[i].phone,
            body: recipients[i].body,
          ),
      ],
    );
    _batches.add(batch);
    _send(batch, batch.recipients);
    return BatchResult(batch, created: true);
  }

  /// Re-queues failed recipients only. Recipients that were sent or
  /// delivered are never resent.
  int retryFailed(MessageBatch batch) {
    final failed = batch.recipients
        .where(
          (r) => r.status == DeliveryStatus.failed && !_inFlight.contains(r.id),
        )
        .toList();
    if (failed.isNotEmpty) _send(batch, failed);
    return failed.length;
  }

  /// Dispatches recipients stuck in "queued" (e.g. the device was offline).
  int processPending(MessageBatch batch) {
    final queued = batch.recipients
        .where(
          (r) => r.status == DeliveryStatus.queued && !_inFlight.contains(r.id),
        )
        .toList();
    if (queued.isNotEmpty) _send(batch, queued);
    return queued.length;
  }

  bool hasStuckPending(MessageBatch batch) => batch.recipients.any(
    (r) => r.status == DeliveryStatus.queued && !_inFlight.contains(r.id),
  );

  void _send(MessageBatch batch, List<MessageRecipient> recipients) {
    _inFlight.addAll(recipients.map((r) => r.id));
    _transport.dispatch(
      recipients,
      onSettled: (r) {
        _inFlight.remove(r.id);
        if (r.status.isSuccessful) {
          sms.usedThisMonth += 1;
        }
        if (!batch.recipients.any((x) => _inFlight.contains(x.id))) {
          onBatchSettled?.call(batch);
        }
      },
      onUpdate: changed,
    );
  }

  void updateSettings(void Function(SmsSettings s) edit) {
    edit(sms);
    changed();
  }

  void syncDevice() {
    sms.lastSync = DateTime.now();
    changed();
  }
}
