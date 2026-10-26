enum AttendanceStatus {
  present('Present', 'P'),
  absent('Absent', 'A'),
  late('Late', 'L'),
  leave('Leave', 'LV');

  const AttendanceStatus(this.label, this.short);
  final String label;
  final String short;

  /// Late students attended; leave is an approved absence.
  bool get attended => this == present || this == late;
}

class AuditNote {
  const AuditNote({required this.at, required this.by, required this.note});

  final DateTime at;
  final String by;
  final String note;
}

/// One class session on one date. After saving, a session is locked in this
/// demo; corrections are appended to [audit]. The future backend must enforce
/// real locking and concurrency — this client-side lock is UI only.
class AttendanceSession {
  AttendanceSession({
    required this.id,
    required this.classId,
    required this.academicYearId,
    required this.date,
    required this.records,
    required this.markedBy,
    required this.markedAt,
    List<AuditNote>? audit,
  }) : audit = audit ?? [];

  final String id;
  final String classId;
  final String academicYearId;
  final DateTime date;
  Map<String, AttendanceStatus> records;
  final String markedBy;
  final DateTime markedAt;
  final List<AuditNote> audit;

  bool get isLocked => true;

  int count(AttendanceStatus status) =>
      records.values.where((s) => s == status).length;

  int get presentCount => count(AttendanceStatus.present);
  int get absentCount => count(AttendanceStatus.absent);
  int get lateCount => count(AttendanceStatus.late);
  int get leaveCount => count(AttendanceStatus.leave);
  int get total => records.length;
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
  });

  final int present;
  final int absent;
  final int late;
  final int leave;

  int get total => present + absent + late + leave;
  int get attended => present + late;
  double get percent => total == 0 ? 0 : attended * 100 / total;
}
