class SchoolClass {
  SchoolClass({required this.id, required this.name});

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
  });

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

  double get feesDue => (totalFees - feesPaid).clamp(0, double.infinity);

  int get rollNumber => int.tryParse(rollNo) ?? 1 << 30;
}

class StaffUser {
  StaffUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    this.subject = '',
    this.phone = '',
    this.salary,
    this.canAccessFees = false,
    this.active = false,
  });

  final String id;
  String name;
  String subject;
  String phone;
  String email;
  String password;
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

  final String id;
  final String classId;
  String subject;
  double maxMarks;

  /// studentId -> mark entry
  final Map<String, StudentMark> marks = {};

  int get gradedCount =>
      marks.values.where((m) => !m.skip && m.marks != null).length;
}
