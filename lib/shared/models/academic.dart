enum YearStatus {
  active('Current'),
  upcoming('Upcoming'),
  closed('Closed');

  const YearStatus(this.label);
  final String label;
}

class AcademicYear {
  AcademicYear({
    required this.id,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;

  /// e.g. "2026–27"
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  YearStatus status;
}

/// A class (grade batch) offered by the tuition. Classes persist across
/// academic years; who sits in them for a given year comes from [Enrollment].
class SchoolClass {
  SchoolClass({
    required this.id,
    required this.name,
    required this.grade,
    required this.sessionLabel,
    required this.subjectIds,
    this.room = '',
    this.isActive = true,
  });

  final String id;
  String name;
  int grade;

  /// Daily batch timing shown on attendance cards, e.g. "4:00 – 5:00 PM".
  String sessionLabel;
  String room;
  List<String> subjectIds;
  bool isActive;
}

enum EnrollmentStatus {
  active('Active'),
  promoted('Promoted'),
  completed('Completed'),
  withdrawn('Withdrawn');

  const EnrollmentStatus(this.label);
  final String label;
}

/// One student's seat in one class for one academic year.
///
/// Promotion creates a *new* enrollment for the same permanent student; the
/// previous enrollment (and its fee plan and payments) is left untouched.
class Enrollment {
  Enrollment({
    required this.id,
    required this.studentId,
    required this.academicYearId,
    required this.classId,
    required this.enrolledOn,
    required this.status,
    this.promotedFromId,
  });

  final String id;
  final String studentId;
  final String academicYearId;
  final String classId;
  final DateTime enrolledOn;
  EnrollmentStatus status;
  final String? promotedFromId;
}

/// A non-exam item on the tuition calendar (holiday, meeting, …).
class TuitionEvent {
  const TuitionEvent({
    required this.title,
    required this.date,
    required this.subtitle,
    this.endDate,
  });

  final String title;
  final DateTime date;
  final DateTime? endDate;
  final String subtitle;
}
