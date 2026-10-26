import '../../shared/models/models.dart';
import 'mock_repository.dart';

class PromotionResult {
  const PromotionResult({required this.promoted, required this.skipped});

  /// Newly created enrollments in the destination year.
  final List<Enrollment> promoted;

  /// Students who already had an enrollment in the destination year.
  final List<String> skipped;
}

/// Students (permanent identity) and their per-year enrollments.
class StudentRepository extends MockRepository {
  StudentRepository(
    super.onChanged, {
    required this._students,
    required this._enrollments,
  });

  final List<Student> _students;
  final List<Enrollment> _enrollments;
  var _enrollmentCounter = 10000;

  List<Student> get all => List.unmodifiable(_students);

  Student byId(String id) => _students.firstWhere((s) => s.id == id);

  Student? tryById(String id) {
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Next permanent ID in the STU-0000 sequence.
  String nextStudentId() {
    var highest = 0;
    for (final s in _students) {
      final n = int.tryParse(s.id.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (n > highest) highest = n;
    }
    return 'STU-${(highest + 1).toString().padLeft(4, '0')}';
  }

  String newEnrollmentId() => 'enr-${++_enrollmentCounter}';

  Enrollment? enrollmentById(String id) {
    for (final e in _enrollments) {
      if (e.id == id) return e;
    }
    return null;
  }

  Enrollment? enrollmentFor(String studentId, String yearId) {
    for (final e in _enrollments) {
      if (e.studentId == studentId && e.academicYearId == yearId) return e;
    }
    return null;
  }

  /// Oldest year first.
  List<Enrollment> enrollmentsOf(String studentId, List<AcademicYear> years) {
    final order = {for (final y in years) y.id: y.startDate};
    return _enrollments.where((e) => e.studentId == studentId).toList()..sort(
      (a, b) => (order[a.academicYearId] ?? DateTime(0)).compareTo(
        order[b.academicYearId] ?? DateTime(0),
      ),
    );
  }

  List<Enrollment> enrollmentsIn(
    String yearId, {
    String? classId,
    bool includeInactive = false,
  }) {
    return _enrollments
        .where(
          (e) =>
              e.academicYearId == yearId &&
              (classId == null || e.classId == classId) &&
              (includeInactive || e.status != EnrollmentStatus.withdrawn),
        )
        .toList();
  }

  /// Active students sitting in [classId] during [yearId], sorted by name.
  List<Student> studentsIn(String classId, String yearId) {
    final ids = enrollmentsIn(
      yearId,
      classId: classId,
    ).map((e) => e.studentId).toSet();
    return _students.where((s) => s.isActive && ids.contains(s.id)).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  void add(Student student, Enrollment enrollment) {
    _students.add(student);
    _enrollments.add(enrollment);
    changed();
  }

  void update(Student student) {
    // Student objects are mutated by the edit form; this just broadcasts.
    assert(_students.contains(student));
    changed();
  }

  void setActive(Student student, bool active) {
    student.isActive = active;
    changed();
  }

  /// Creates a new enrollment in [toYearId] for each student. The student's
  /// permanent record is reused — never copied — and the source enrollment
  /// (with its fee plan and payments) remains as it was, marked promoted.
  PromotionResult promote({
    required String fromYearId,
    required String toYearId,
    required String toClassId,
    required List<String> studentIds,
    required DateTime enrolledOn,
  }) {
    final promoted = <Enrollment>[];
    final skipped = <String>[];
    for (final id in studentIds) {
      if (enrollmentFor(id, toYearId) != null) {
        skipped.add(id);
        continue;
      }
      final source = enrollmentFor(id, fromYearId);
      source?.status = EnrollmentStatus.promoted;
      final next = Enrollment(
        id: newEnrollmentId(),
        studentId: id,
        academicYearId: toYearId,
        classId: toClassId,
        enrolledOn: enrolledOn,
        status: EnrollmentStatus.active,
        promotedFromId: source?.id,
      );
      _enrollments.add(next);
      promoted.add(next);
    }
    changed();
    return PromotionResult(promoted: promoted, skipped: skipped);
  }
}
