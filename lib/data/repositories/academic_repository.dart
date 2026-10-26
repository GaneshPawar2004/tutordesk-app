import '../../shared/models/models.dart';
import 'mock_repository.dart';

class AcademicRepository extends MockRepository {
  AcademicRepository(
    super.onChanged, {
    required this._years,
    required this._classes,
    required this._subjects,
  });

  final List<AcademicYear> _years;
  final List<SchoolClass> _classes;
  final List<Subject> _subjects;
  var _classCounter = 100;
  var _yearCounter = 100;

  // ------------------------------------------------------------------ years

  /// Newest first.
  List<AcademicYear> get years =>
      [..._years]..sort((a, b) => b.startDate.compareTo(a.startDate));

  AcademicYear get currentYear => _years.firstWhere(
    (y) => y.status == YearStatus.active,
    orElse: () => _years.last,
  );

  AcademicYear yearById(String id) => _years.firstWhere((y) => y.id == id);

  /// The year that follows [year], if one has been created.
  AcademicYear? nextYearAfter(AcademicYear year) {
    final later =
        _years.where((y) => y.startDate.isAfter(year.startDate)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
    return later.isEmpty ? null : later.first;
  }

  AcademicYear addYear({
    required String label,
    required DateTime start,
    required DateTime end,
  }) {
    final year = AcademicYear(
      id: 'ay-new-${++_yearCounter}',
      label: label,
      startDate: start,
      endDate: end,
      status: YearStatus.upcoming,
    );
    _years.add(year);
    changed();
    return year;
  }

  /// Makes [id] the current year. The previous current year is closed.
  void setCurrentYear(String id) {
    for (final y in _years) {
      if (y.id == id) {
        y.status = YearStatus.active;
      } else if (y.status == YearStatus.active) {
        y.status = YearStatus.closed;
      }
    }
    changed();
  }

  // ---------------------------------------------------------------- classes

  List<SchoolClass> get classes =>
      [..._classes]..sort((a, b) => a.grade.compareTo(b.grade));

  List<SchoolClass> get runningClasses =>
      classes.where((c) => c.isActive).toList();

  SchoolClass classById(String id) => _classes.firstWhere((c) => c.id == id);

  /// The class one grade above [cls], if the tuition offers it.
  SchoolClass? nextClassAfter(SchoolClass cls) {
    for (final c in classes) {
      if (c.grade == cls.grade + 1) return c;
    }
    return null;
  }

  SchoolClass addClass({
    required String name,
    required int grade,
    required String sessionLabel,
    required String room,
    required List<String> subjectIds,
  }) {
    final cls = SchoolClass(
      id: 'cls-new-${++_classCounter}',
      name: name,
      grade: grade,
      sessionLabel: sessionLabel,
      room: room,
      subjectIds: subjectIds,
    );
    _classes.add(cls);
    changed();
    return cls;
  }

  void updateClass(
    SchoolClass cls, {
    required String name,
    required int grade,
    required String sessionLabel,
    required String room,
    required List<String> subjectIds,
    required bool isActive,
  }) {
    cls
      ..name = name
      ..grade = grade
      ..sessionLabel = sessionLabel
      ..room = room
      ..subjectIds = subjectIds
      ..isActive = isActive;
    changed();
  }

  // --------------------------------------------------------------- subjects

  List<Subject> get subjects => List.unmodifiable(_subjects);

  Subject subjectById(String id) => _subjects.firstWhere((s) => s.id == id);
}
