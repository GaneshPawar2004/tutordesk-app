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
  });

  factory FeePayment.fromJson(Map<String, dynamic> j) => FeePayment(
    id: j['id'] as String,
    amount: _num(j['amount']),
    paidAt: parseDate(j['paidAt']) ?? DateTime.now(),
    note: j['note'] as String? ?? '',
    collectedBy: j['collectedBy'] as String? ?? '',
  );

  final String id;
  final double amount;
  final DateTime paidAt;
  final String note;
  final String collectedBy;
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
