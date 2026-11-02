import 'package:flutter/foundation.dart';

import 'models.dart';

/// In-memory store for the frontend. Replace method bodies with API calls
/// once the backend is ready; screens only talk to this class.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  /// Number of staff logins included in the current plan (admin not counted).
  static const int staffLoginLimit = 0;

  // ---- Session -----------------------------------------------------------
  String? userName;
  String? userEmail;
  int trialDaysRemaining = 14;

  bool get isLoggedIn => userEmail != null;

  void login({required String email, String? name}) {
    userEmail = email;
    userName = name ?? email.split('@').first;
    notifyListeners();
  }

  void logout() {
    userEmail = null;
    userName = null;
    notifyListeners();
  }

  // ---- Classes -----------------------------------------------------------
  final List<SchoolClass> classes = [];

  SchoolClass addClass(String name) {
    final c = SchoolClass(id: _id(), name: name);
    classes.add(c);
    notifyListeners();
    return c;
  }

  void renameClass(SchoolClass c, String name) {
    c.name = name;
    notifyListeners();
  }

  void sortClassesByName() {
    classes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    notifyListeners();
  }

  void deleteClass(SchoolClass c) {
    classes.remove(c);
    students.removeWhere((s) => s.classId == c.id);
    tests.removeWhere((t) => t.classId == c.id);
    _attendance.remove(c.id);
    notifyListeners();
  }

  SchoolClass? classById(String id) {
    for (final c in classes) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ---- Students ----------------------------------------------------------
  final List<Student> students = [];

  List<Student> studentsOf(String classId, {bool includeDisabled = true}) =>
      students
          .where(
            (s) => s.classId == classId && (includeDisabled || !s.disabled),
          )
          .toList();

  void addStudent(Student s) {
    students.add(s);
    notifyListeners();
  }

  void updateStudent() => notifyListeners();

  void toggleStudentDisabled(Student s) {
    s.disabled = !s.disabled;
    notifyListeners();
  }

  void deleteStudent(Student s) {
    students.remove(s);
    for (final t in tests) {
      t.marks.remove(s.id);
    }
    for (final byDate in _attendance.values) {
      for (final day in byDate.values) {
        day.remove(s.id);
      }
    }
    notifyListeners();
  }

  void collectFee(Student s, double amount) {
    s.feesPaid += amount;
    notifyListeners();
  }

  // ---- Fees summary ------------------------------------------------------
  double totalFeesOf(String? classId) =>
      _feeStudents(classId).fold(0, (sum, s) => sum + s.totalFees);

  double collectedFeesOf(String? classId) =>
      _feeStudents(classId).fold(0, (sum, s) => sum + s.feesPaid);

  double dueFeesOf(String? classId) =>
      _feeStudents(classId).fold(0, (sum, s) => sum + s.feesDue);

  Iterable<Student> _feeStudents(String? classId) =>
      classId == null ? students : students.where((s) => s.classId == classId);

  // ---- Attendance --------------------------------------------------------
  /// classId -> dateKey(yyyy-mm-dd) -> studentId -> status
  final Map<String, Map<String, Map<String, AttendanceStatus>>> _attendance =
      {};

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, AttendanceStatus>? attendanceFor(String classId, DateTime date) =>
      _attendance[classId]?[dateKey(date)];

  void saveAttendance(
    String classId,
    DateTime date,
    Map<String, AttendanceStatus> marks,
  ) {
    _attendance.putIfAbsent(classId, () => {})[dateKey(date)] = Map.of(marks);
    notifyListeners();
  }

  int get presentToday {
    final key = dateKey(DateTime.now());
    var count = 0;
    for (final byDate in _attendance.values) {
      count +=
          byDate[key]?.values
              .where((s) => s == AttendanceStatus.present)
              .length ??
          0;
    }
    return count;
  }

  /// Aggregated status counts across every saved day for a class.
  Map<AttendanceStatus, int> attendanceTotals(String classId) {
    final totals = {for (final s in AttendanceStatus.values) s: 0};
    for (final day
        in _attendance[classId]?.values ??
            const <Map<String, AttendanceStatus>>[]) {
      for (final status in day.values) {
        totals[status] = totals[status]! + 1;
      }
    }
    return totals;
  }

  List<MapEntry<DateTime, AttendanceStatus>> attendanceHistoryOf(Student s) {
    final out = <MapEntry<DateTime, AttendanceStatus>>[];
    _attendance[s.classId]?.forEach((key, day) {
      final status = day[s.id];
      if (status != null) out.add(MapEntry(DateTime.parse(key), status));
    });
    out.sort((a, b) => b.key.compareTo(a.key));
    return out;
  }

  // ---- Tests -------------------------------------------------------------
  final List<ClassTest> tests = [];

  List<ClassTest> testsOf(String classId) =>
      tests.where((t) => t.classId == classId).toList();

  ClassTest addTest(String classId, String subject, double maxMarks) {
    final t = ClassTest(
      id: _id(),
      classId: classId,
      subject: subject,
      maxMarks: maxMarks,
    );
    tests.add(t);
    notifyListeners();
    return t;
  }

  void updateTest() => notifyListeners();

  void deleteTest(ClassTest t) {
    tests.remove(t);
    notifyListeners();
  }

  // ---- Staff users -------------------------------------------------------
  final List<StaffUser> users = [];

  int get activeUserCount => users.where((u) => u.active).length;

  void addUser(StaffUser u) {
    users.add(u);
    notifyListeners();
  }

  void updateUser() => notifyListeners();

  /// Returns false when activating would exceed the plan's staff login limit.
  bool toggleUserActive(StaffUser u) {
    if (!u.active && activeUserCount >= staffLoginLimit) return false;
    u.active = !u.active;
    notifyListeners();
    return true;
  }

  void deleteUser(StaffUser u) {
    users.remove(u);
    notifyListeners();
  }

  // ------------------------------------------------------------------------
  int _seq = 0;
  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';
}

final appState = AppState.instance;
