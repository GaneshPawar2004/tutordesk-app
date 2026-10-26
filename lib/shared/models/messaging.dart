enum MessageCategory {
  attendance('Attendance alerts'),
  examResults('Exam results'),
  feeReminder('Fee reminders'),
  announcement('Announcements');

  const MessageCategory(this.label);
  final String label;
}

enum DeliveryStatus {
  queued('Queued'),
  sending('Sending'),
  sent('Sent'),
  delivered('Delivered'),
  failed('Failed');

  const DeliveryStatus(this.label);
  final String label;

  bool get isPending => this == queued || this == sending;
  bool get isSuccessful => this == sent || this == delivered;
}

class MessageRecipient {
  MessageRecipient({
    required this.id,
    required this.studentName,
    required this.parentName,
    required this.phone,
    required this.body,
    this.studentId,
    this.status = DeliveryStatus.queued,
    this.attempts = 0,
    this.failureReason,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String? studentId;
  final String studentName;
  final String parentName;
  final String phone;
  final String body;
  DeliveryStatus status;
  int attempts;
  String? failureReason;
  DateTime updatedAt;
}

/// A batch is created once per source (attendance session, published exam,
/// announcement). [sourceKey] is what prevents duplicate batches.
class MessageBatch {
  MessageBatch({
    required this.id,
    required this.sourceKey,
    required this.title,
    required this.category,
    required this.classIds,
    required this.createdBy,
    required this.createdAt,
    required this.previewBody,
    required this.recipients,
  });

  final String id;
  final String sourceKey;
  final String title;
  final MessageCategory category;
  final List<String> classIds;
  final String createdBy;
  final DateTime createdAt;
  final String previewBody;
  final List<MessageRecipient> recipients;

  int count(bool Function(DeliveryStatus s) test) =>
      recipients.where((r) => test(r.status)).length;

  int get delivered => count((s) => s == DeliveryStatus.delivered);
  int get sent => count((s) => s.isSuccessful);
  int get failed => count((s) => s == DeliveryStatus.failed);
  int get pending => count((s) => s.isPending);
  int get total => recipients.length;
  bool get isProcessing =>
      recipients.any((r) => r.status == DeliveryStatus.sending);
}

enum SendingMode {
  androidDevice('Phone SIM via Android device'),
  gateway('SMS gateway'),
  notConfigured('Not configured');

  const SendingMode(this.label);
  final String label;
}

/// Provider-neutral settings. All numbers here are demo values; no real
/// provider is connected and SIM balances cannot be read automatically.
class SmsSettings {
  SmsSettings({
    required this.mode,
    required this.deviceName,
    required this.lastSync,
    required this.monthlyAllowance,
    required this.usedThisMonth,
    required this.senderSignature,
    this.autoSuggestAttendance = true,
    this.includeTuitionName = true,
  });

  SendingMode mode;
  String deviceName;
  DateTime lastSync;
  int monthlyAllowance;
  int usedThisMonth;
  String senderSignature;
  bool autoSuggestAttendance;
  bool includeTuitionName;
}
