import '../../shared/models/models.dart';
import 'mock_repository.dart';

class ExamRepository extends MockRepository {
  ExamRepository(super.onChanged, {required this._exams});

  final List<Exam> _exams;
  var _counter = 1000;

  /// Newest exam date first.
  List<Exam> get all => [..._exams]..sort((a, b) => b.date.compareTo(a.date));

  Exam byId(String id) => _exams.firstWhere((e) => e.id == id);

  Exam create({
    required String name,
    required String academicYearId,
    required String classId,
    required DateTime date,
    required List<ExamSubject> subjects,
    required String description,
    required bool isDraft,
    required String createdBy,
  }) {
    final exam = Exam(
      id: 'exm-${++_counter}',
      name: name,
      academicYearId: academicYearId,
      classId: classId,
      date: date,
      subjects: subjects,
      description: description,
      isDraft: isDraft,
      createdBy: createdBy,
    );
    _exams.add(exam);
    changed();
    return exam;
  }

  void update(
    Exam exam, {
    required String name,
    required String classId,
    required DateTime date,
    required List<ExamSubject> subjects,
    required String description,
    required bool isDraft,
  }) {
    exam
      ..name = name
      ..classId = classId
      ..date = date
      ..subjects = subjects
      ..description = description
      ..isDraft = isDraft;
    // Drop marks for subjects that were removed.
    exam.marks.removeWhere((id, _) => !subjects.any((s) => s.subjectId == id));
    changed();
  }

  void saveMarks(Exam exam, String subjectId, Map<String, MarkEntry> entries) {
    exam.marks[subjectId] = Map.of(entries);
    changed();
  }

  void publish(Exam exam) {
    exam
      ..resultsPublished = true
      ..isDraft = false
      ..publishedAt = DateTime.now();
    changed();
  }

  /// Records a correction to already-published results.
  void logCorrection(Exam exam, String note) {
    exam
      ..revision += 1
      ..correctionLog.add(note);
    changed();
  }
}
