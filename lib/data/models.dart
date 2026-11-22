/// Parses an ISO date/time from the API into a local date (or null).
DateTime? parseDate(Object? v) =>
    v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

double _num(Object? v) => v is num ? v.toDouble() : 0;

class SchoolClass {
  SchoolClass({required this.id, required this.name});

  factory SchoolClass.fromJson(Map<String, dynamic> j) =>
      SchoolClass(id: j['id'] as String, name: j['name'] as String);

  final String id;
  String name;
}

class Student {
  Student({
    required this.id,
    required this.classId,
    required this.name,
    this.fatherName = '',
    this.contact = '',
    this.parentMobile = '',
    this.rollNo = '',
    this.email = '',
    this.dateOfBirth,
    this.totalFees = 0,
    this.feesDueDate,
    this.feesPaid = 0,
    this.disabled = false,
    this.photoUpdatedAt,
    this.oneTimeFees = 0,
    this.monthlyFee = 0,
    this.feeStart,
    this.monthsBilled = 0,
  });

  /// Fee fields are missing for staff without fee access; they read as 0.
  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id'] as String,
    classId: j['class'] as String,
    name: j['name'] as String,
    fatherName: j['fatherName'] as String? ?? '',
    contact: j['contact'] as String? ?? '',
    parentMobile: j['parentMobile'] as String? ?? '',
    rollNo: j['rollNo'] as String? ?? '',
    email: j['email'] as String? ?? '',
    dateOfBirth: parseDate(j['dateOfBirth']),
    totalFees: _num(j['totalFees']),
    feesDueDate: parseDate(j['feesDueDate']),
    feesPaid: _num(j['feesPaid']),
    disabled: j['disabled'] as bool? ?? false,
    photoUpdatedAt: parseDate(j['photoUpdatedAt']),
    oneTimeFees: _num(j['oneTimeFees'] ?? j['totalFees']),
    monthlyFee: _num(j['monthlyFee']),
    feeStart: j['feeStart'] as String?,
    monthsBilled: (j['monthsBilled'] as num?)?.toInt() ?? 0,
  );

  final String id;
  final String classId;
  String name;
  String fatherName;
  String contact;
  String parentMobile;
  String rollNo;
  String email;
  DateTime? dateOfBirth;
  double totalFees;
  DateTime? feesDueDate;
  double feesPaid;
  bool disabled;

  /// Null when the student has no photo.
  DateTime? photoUpdatedAt;

  // Monthly fees system: [totalFees] = [oneTimeFees] + [monthlyFee] × [monthsBilled].
  double oneTimeFees;
  double monthlyFee;

  /// First billed month, "YYYY-MM" (null without a monthly fee).
  String? feeStart;
  int monthsBilled;

  bool get hasMonthlyFee => monthlyFee > 0 && feeStart != null;

  double get feesDue => (totalFees - feesPaid).clamp(0, double.infinity);

  int get rollNumber => int.tryParse(rollNo) ?? 1 << 30;
}

/// One fee payment collected from a student.
class FeePayment {
  FeePayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.note = '',
    this.collectedBy = '',
    this.receiptNo,
  });

  factory FeePayment.fromJson(Map<String, dynamic> j) => FeePayment(
    id: j['id'] as String,
    amount: _num(j['amount']),
    paidAt: parseDate(j['paidAt']) ?? DateTime.now(),
    note: j['note'] as String? ?? '',
    collectedBy: j['collectedBy'] as String? ?? '',
    receiptNo: (j['receiptNo'] as num?)?.toInt(),
  );

  final String id;
  final double amount;
  final DateTime paidAt;
  final String note;
  final String collectedBy;

  /// 1, 2, 3… per institute (null for payments saved before numbering).
  final int? receiptNo;
}

class StaffUser {
  StaffUser({
    required this.id,
    required this.name,
    required this.email,
    this.subject = '',
    this.phone = '',
    this.salary,
    this.canAccessFees = false,
    this.active = false,
  });

  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(
    id: j['id'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    subject: j['subject'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    salary: (j['salary'] as num?)?.toDouble(),
    canAccessFees: j['canAccessFees'] as bool? ?? false,
    active: j['active'] as bool? ?? false,
  );

  final String id;
  String name;
  String subject;
  String phone;
  String email;
  double? salary;
  bool canAccessFees;
  bool active;
}

enum AttendanceStatus {
  present('Present'),
  absent('Absent'),
  leave('Leave'),
  others('Others');

  const AttendanceStatus(this.label);
  final String label;
}

class StudentMark {
  StudentMark({this.marks, this.remarks = '', this.skip = false});

  Map<String, dynamic> toJson(String studentId) => {
    'student': studentId,
    'marks': marks,
    'remarks': remarks,
    'skip': skip,
  };

  double? marks;
  String remarks;
  bool skip;
}

class ClassTest {
  ClassTest({
    required this.id,
    required this.classId,
    required this.subject,
    required this.maxMarks,
  });

  factory ClassTest.fromJson(Map<String, dynamic> j) {
    final t = ClassTest(
      id: j['id'] as String,
      classId: j['class'] as String,
      subject: j['subject'] as String,
      maxMarks: _num(j['maxMarks']),
    );
    for (final m in (j['marks'] as List? ?? const [])) {
      t.marks[m['student'] as String] = StudentMark(
        marks: (m['marks'] as num?)?.toDouble(),
        remarks: m['remarks'] as String? ?? '',
        skip: m['skip'] as bool? ?? false,
      );
    }
    return t;
  }

  final String id;
  final String classId;
  String subject;
  double maxMarks;

  /// studentId -> mark entry
  final Map<String, StudentMark> marks = {};

  int get gradedCount =>
      marks.values.where((m) => !m.skip && m.marks != null).length;
}

/// One "send to all" SMS list saved on the server (see Pending SMS screen).
class SmsBatch {
  SmsBatch({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    this.className = '',
    this.createdBy = '',
    this.total = 0,
    this.sent = 0,
    this.failed = 0,
    this.remaining = 0,
    this.expired = false,
    this.senders = const [],
  });

  factory SmsBatch.fromJson(Map<String, dynamic> j) => SmsBatch(
    id: j['id'] as String,
    title: j['title'] as String,
    kind: j['kind'] as String? ?? 'other',
    createdAt: parseDate(j['createdAt']) ?? DateTime.now(),
    className: j['className'] as String? ?? '',
    createdBy: j['createdBy'] as String? ?? '',
    total: (j['total'] as num?)?.toInt() ?? 0,
    sent: (j['sent'] as num?)?.toInt() ?? 0,
    failed: (j['failed'] as num?)?.toInt() ?? 0,
    remaining: (j['remaining'] as num?)?.toInt() ?? 0,
    expired: j['expired'] as bool? ?? false,
    senders: [
      for (final s in (j['senders'] as List? ?? const []))
        (name: s['name'] as String, count: (s['count'] as num).toInt()),
    ],
  );

  final String id;
  final String title;
  final String kind;
  final DateTime createdAt;
  final String className;
  final String createdBy;
  final int total;
  final int sent;
  final int failed;

  /// Unsent and still sendable (not older than 2 days, not dismissed).
  final int remaining;
  final bool expired;
  final List<({String name, int count})> senders;
}

/// One parent SMS of a batch.
class SmsMessage {
  SmsMessage({
    required this.id,
    required this.name,
    required this.phone,
    required this.body,
    required this.status,
    this.studentId,
    this.reason,
    this.channel,
    this.sentBy,
    this.sentAt,
  });

  factory SmsMessage.fromJson(Map<String, dynamic> j) => SmsMessage(
    id: j['id'] as String,
    name: j['name'] as String,
    phone: j['phone'] as String,
    body: j['body'] as String,
    status: j['status'] as String,
    studentId: j['student'] as String?,
    reason: j['reason'] as String?,
    channel: j['channel'] as String?,
    sentBy: j['sentBy'] as String?,
    sentAt: parseDate(j['sentAt']),
  );

  final String id;
  final String name;
  final String phone;
  final String body;

  /// pending | sent | failed | dismissed
  final String status;
  final String? studentId;
  final String? reason;
  final String? channel;
  final String? sentBy;
  final DateTime? sentAt;

  bool get unsent => status == 'pending' || status == 'failed';
}

/// One change to a saved attendance mark (who changed it, from → to, when).
class AttendanceChange {
  AttendanceChange({
    required this.studentName,
    required this.from,
    required this.to,
    required this.by,
    required this.at,
  });

  final String studentName;
  final AttendanceStatus from;
  final AttendanceStatus to;
  final String by;
  final DateTime at;
}

/// Attendance of a class on one date, as saved on the server.
class AttendanceDay {
  AttendanceDay({
    required this.saved,
    required this.version,
    required this.marks,
    required this.savedMarks,
    required this.sms,
    required this.changes,
    this.notes = const {},
    this.savedBy,
    this.savedAt,
  });

  final bool saved;

  /// Send back when saving; the server refuses a save based on an old version.
  final int? version;
  final String? savedBy;
  final DateTime? savedAt;

  /// studentId → status (unsaved students default to present).
  final Map<String, AttendanceStatus> marks;

  /// Students that have a saved mark for this date.
  final Set<String> savedMarks;

  /// studentId → absence SMS status for this date (sent / pending / failed / dismissed).
  final Map<String, String> sms;
  final List<AttendanceChange> changes;

  /// studentId → reason for "others" (e.g. Sick).
  final Map<String, String> notes;
}
