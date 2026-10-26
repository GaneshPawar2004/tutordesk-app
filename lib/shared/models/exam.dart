import '../../core/utils/grading.dart';

class Subject {
  const Subject({required this.id, required this.name, required this.code});

  final String id;
  final String name;
  final String code;
}

class ExamSubject {
  const ExamSubject({required this.subjectId, required this.maxMarks});

  final String subjectId;
  final double maxMarks;
}

enum ExamStatus {
  draft('Draft'),
  upcoming('Upcoming'),
  completed('Results pending'),
  published('Published');

  const ExamStatus(this.label);
  final String label;
}

/// A single mark. Absent is its own state — never a fabricated zero.
class MarkEntry {
  const MarkEntry({this.marks, this.absent = false});

  static const absentEntry = MarkEntry(absent: true);

  final double? marks;
  final bool absent;

  bool get isEntered => absent || marks != null;
}

class Exam {
  Exam({
    required this.id,
    required this.name,
    required this.academicYearId,
    required this.classId,
    required this.date,
    required this.subjects,
    required this.createdBy,
    this.description = '',
    this.isDraft = false,
    this.resultsPublished = false,
    this.publishedAt,
    this.revision = 0,
    Map<String, Map<String, MarkEntry>>? marks,
    List<String>? correctionLog,
  }) : marks = marks ?? {},
       correctionLog = correctionLog ?? [];

  final String id;
  String name;
  String academicYearId;
  String classId;
  DateTime date;
  List<ExamSubject> subjects;
  String description;
  String createdBy;

  /// Exam set-up not yet announced.
  bool isDraft;
  bool resultsPublished;
  DateTime? publishedAt;

  /// Bumped when published results are corrected, so a corrected result can
  /// be sent once more while the original batch stays de-duplicated.
  int revision;

  /// subjectId -> studentId -> mark
  final Map<String, Map<String, MarkEntry>> marks;
  final List<String> correctionLog;

  double get totalMax => subjects.fold(0, (sum, s) => sum + s.maxMarks);

  ExamStatus statusOn(DateTime today) {
    if (isDraft) return ExamStatus.draft;
    if (resultsPublished) return ExamStatus.published;
    final examDay = DateTime(date.year, date.month, date.day);
    if (examDay.isAfter(today)) return ExamStatus.upcoming;
    return ExamStatus.completed;
  }

  MarkEntry? markFor(String subjectId, String studentId) =>
      marks[subjectId]?[studentId];
}

class SubjectResult {
  const SubjectResult({
    required this.subject,
    required this.maxMarks,
    required this.entry,
  });

  final Subject subject;
  final double maxMarks;
  final MarkEntry? entry;

  bool get isAbsent => entry?.absent ?? false;
  bool get isMissing => entry == null || !entry!.isEntered;
  double get obtained => entry?.marks ?? 0;
  double get ratio => maxMarks == 0 ? 0 : (obtained / maxMarks).clamp(0.0, 1.0);
}

/// Totals are always computed from the subject marks, never stored.
class StudentResult {
  const StudentResult({
    required this.studentId,
    required this.exam,
    required this.subjects,
  });

  final String studentId;
  final Exam exam;
  final List<SubjectResult> subjects;

  double get obtained => subjects.fold(0, (sum, s) => sum + s.obtained);
  double get maxTotal => subjects.fold(0, (sum, s) => sum + s.maxMarks);
  double get percent => maxTotal == 0 ? 0 : obtained * 100 / maxTotal;
  bool get isComplete => subjects.every((s) => !s.isMissing);
  bool get absentInAll =>
      subjects.isNotEmpty && subjects.every((s) => s.isAbsent);
  Grade get grade => gradeFor(percent);
}
