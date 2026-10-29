import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/utils/formatters.dart';
import '../shared/models/models.dart';
import 'message_templates.dart';
import 'mock_data.dart';
import 'remote/api_client.dart';
import 'remote/session_store.dart';
import 'remote/sms_sender.dart';
import 'remote/snapshot.dart';
import 'repositories/academic_repository.dart';
import 'repositories/attendance_repository.dart';
import 'repositories/exam_repository.dart';
import 'repositories/fee_repository.dart';
import 'repositories/messaging_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/staff_repository.dart';
import 'repositories/student_repository.dart';

export 'repositories/attendance_repository.dart' show AttendanceSaveResult;
export 'repositories/messaging_repository.dart'
    show BatchResult, RecipientDraft;
export 'remote/api_client.dart' show ApiException;
export 'repositories/student_repository.dart' show PromotionResult;

class StudentEnrollment {
  const StudentEnrollment(this.student, this.enrollment);

  final Student student;
  final Enrollment enrollment;
}

class FeeRow {
  const FeeRow({
    required this.student,
    required this.enrollment,
    required this.plan,
    required this.summary,
  });

  final Student student;
  final Enrollment enrollment;
  final FeePlan? plan;
  final FeeSummary summary;
}

class TodayAttendance {
  const TodayAttendance({
    required this.classesMarked,
    required this.classesTotal,
    required this.present,
    required this.absent,
    required this.lateOrLeave,
    required this.notMarked,
  });

  final int classesMarked;
  final int classesTotal;

  /// Present + late.
  final int present;
  final int absent;
  final int lateOrLeave;

  /// Students in classes whose attendance has not been taken yet.
  final int notMarked;
}

class FeeDraft {
  const FeeDraft({
    required this.annualFee,
    required this.installments,
    required this.frequency,
    required this.firstDueDate,
    required this.initialAmount,
    required this.paymentDate,
    required this.method,
    this.note,
  });

  final int annualFee;
  final int installments;
  final FeeFrequency frequency;
  final DateTime firstDueDate;
  final int initialAmount;
  final DateTime paymentDate;
  final PaymentMethod method;
  final String? note;
}

class AdmissionDraft {
  const AdmissionDraft({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.parentName,
    required this.parentPhone,
    required this.yearId,
    required this.classId,
    required this.enrolledOn,
    required this.active,
    this.gender,
    this.altPhone,
    this.address,
    this.fee,
  });

  final String studentId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final Gender? gender;
  final String parentName;
  final String parentPhone;
  final String? altPhone;
  final String? address;
  final String yearId;
  final String classId;
  final DateTime enrolledOn;
  final bool active;
  final FeeDraft? fee;
}

String _d(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Application state: the signed-in user plus repositories of tuition data.
///
/// Two modes:
/// * **Connected** ([AppState.remote]): data comes from the TutorDesk API.
///   Every change is sent to the server, then the app re-syncs. The server is
///   the source of truth and enforces permissions and locks.
/// * **Offline sample data** ([AppState.new]): in-memory demo data, used by
///   the automated widget tests.
class AppState extends ChangeNotifier {
  AppState({DateTime? now, MessageTransport? transport}) : _api = null {
    final start = now ?? DateTime.now();
    _clockOffset = start.difference(DateTime.now());
    _transport = transport ?? SimulatedMessageTransport();
    _load(buildMockSeed(start));
    _selectedYearId = academic.currentYear.id;
  }

  /// Connected to the backend. Call [restoreSession] or one of the sign-in
  /// methods before showing the app.
  AppState.remote({SessionStore? store})
    : _api = ApiClient(baseUrl: SessionStore.defaultServer),
      _store = store ?? SessionStore() {
    _clockOffset = Duration.zero;
    _transport = SimulatedMessageTransport();
    _api!.onUnauthorized = signOut;
    smsSender = SmsSender(_api, _changed);
    _load(emptySeed());
    _selectedYearId = academic.currentYear.id;
  }

  final ApiClient? _api;
  SessionStore? _store;

  /// Sends queued parent SMS from this phone's SIM when the admin turns it on.
  SmsSender? smsSender;
  bool get isRemote => _api != null;
  String get serverUrl => _api?.baseUrl ?? '';

  late Tuition tuition;
  late AdminUser admin;
  late AcademicRepository academic;
  late StudentRepository students;
  late FeeRepository fees;
  late AttendanceRepository attendance;
  late ExamRepository exams;
  late StaffRepository staff;
  late NotificationRepository notifications;
  late MessagingRepository messaging;
  late List<TuitionEvent> events;

  /// Device-only preferences.
  final notificationPrefs = <String, bool>{
    'Attendance completed': true,
    'Exam results published': true,
    'New admissions': true,
    'Failed messages': true,
    'Payments recorded': true,
    'Daily summary at 8 PM': false,
  };
  final appPrefs = <String, bool>{
    'Confirm before sending messages': true,
    'Show parent phone numbers in lists': true,
    'Haptic feedback when marking attendance': true,
  };
  late final MessageTransport _transport;
  var _disposed = false;
  Timer? _poll;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Call after mutating a model object directly (offline mode only).
  void touch() => _changed();

  void _load(MockSeed seed) {
    tuition = seed.tuition;
    admin = seed.admin;
    academic = AcademicRepository(
      _changed,
      years: seed.years,
      classes: seed.classes,
      subjects: seed.subjects,
    );
    students = StudentRepository(
      _changed,
      students: seed.students,
      enrollments: seed.enrollments,
    );
    fees = FeeRepository(
      _changed,
      plans: seed.feePlans,
      payments: seed.payments,
    );
    attendance = AttendanceRepository(_changed, sessions: seed.sessions);
    exams = ExamRepository(_changed, exams: seed.exams);
    staff = StaffRepository(_changed, staff: seed.staff);
    notifications = NotificationRepository(
      _changed,
      notifications: seed.notifications,
      activity: seed.activity,
    );
    messaging = MessagingRepository(
      _changed,
      batches: seed.batches,
      sms: seed.sms,
      transport: _transport,
      onBatchSettled: _onBatchSettled,
    );
    events = seed.events;
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    smsSender?.stop();
    _transport.dispose();
    super.dispose();
  }

  /// Non-zero only when a fixed start time is injected (tests).
  late final Duration _clockOffset;

  DateTime get now => DateTime.now().add(_clockOffset);
  DateTime get today => Fmt.dateOnly(now);

  // ========================================================== connection

  /// Downloads everything the signed-in user may see and rebuilds the data.
  Future<void> refresh() async {
    final api = _api;
    if (api == null || api.token == null) return;
    final json = await api.get('/sync') as Map<String, dynamic>;
    final (seed, me) = parseSnapshot(json);
    _load(seed);
    _role = me.role;
    _staffId = me.role == UserRole.staff ? me.id : null;
    if (!academic.years.any((y) => y.id == _selectedYearId)) {
      _selectedYearId = academic.currentYear.id;
    }
    _schedulePolling();
    _syncSender();
    _changed();
  }

  /// The sender runs only for an admin, with device mode on at the server and
  /// this phone chosen as the sender.
  void _syncSender() {
    final sender = smsSender;
    if (sender == null) return;
    if (isAdmin &&
        sender.enabled &&
        messaging.sms.mode == SendingMode.androidDevice) {
      sender.start();
    } else {
      sender.stop();
    }
  }

  /// Chooses how parent SMS are sent. `useThisPhone` makes this phone the
  /// sender (asks for SMS permission first); false switches back to simulated.
  Future<void> setSmsMode({
    required bool useThisPhone,
    String deviceName = '',
  }) async {
    final api = _api;
    final sender = smsSender;
    if (api == null || sender == null) return;
    if (useThisPhone) {
      if (!await sender.requestPermission()) {
        throw const ApiException(
          0,
          'permission',
          'SMS permission was not allowed. Allow "SMS" for TutorDesk in Android settings.',
        );
      }
      await api.put('/messages/sms-settings', {
        'mode': 'device',
        'deviceName': deviceName,
      });
      await sender.setEnabled(true, name: deviceName);
    } else {
      await api.put('/messages/sms-settings', {'mode': 'simulated'});
      await sender.setEnabled(false);
    }
    await refresh();
  }

  /// One line for toasts after queueing messages.
  String get smsDeliveryNote => messaging.sms.mode == SendingMode.androidDevice
      ? 'They will be sent from the SIM of ${messaging.sms.deviceName}.'
      : 'SMS delivery is simulated — parents do not receive real SMS.';

  /// While any message is still queued or sending, re-sync every 2 seconds
  /// so delivery statuses update live.
  void _schedulePolling() {
    final pending = messaging.batches.any((b) => b.pending > 0);
    if (pending && _poll == null) {
      _poll = Timer.periodic(const Duration(seconds: 2), (_) {
        refresh().catchError((_) {});
      });
    } else if (!pending) {
      _poll?.cancel();
      _poll = null;
    }
  }

  /// Restores a saved login on app start. Returns true if signed in.
  Future<bool> restoreSession() async {
    final api = _api;
    if (api == null) return false;
    final saved = await _store!.load();
    api.baseUrl = saved.server;
    api.token = saved.token;
    await smsSender?.load();
    if (saved.token == null) return false;
    try {
      await refresh();
      return true;
    } on ApiException catch (e) {
      if (e.status == 401) {
        api.token = null;
        await _store!.save(server: saved.server);
      }
      rethrow;
    }
  }

  Future<void> _signInWith(
    String server,
    Future<dynamic> Function(ApiClient api) call,
  ) async {
    final api = _api!;
    api.baseUrl = server.trim();
    api.token = null;
    final res = await call(api) as Map<String, dynamic>;
    api.token = res['token'] as String;
    await _store!.save(server: api.baseUrl, token: api.token);
    await refresh();
  }

  Future<void> login({
    required String server,
    required String identifier,
    required String password,
  }) => _signInWith(
    server,
    (api) => api.post('/auth/login', {
      'identifier': identifier,
      'password': password,
    }),
  );

  Future<void> registerTuition({
    required String server,
    required String tuitionName,
    required String city,
    required String adminName,
    required String phone,
    required String email,
    required String password,
  }) => _signInWith(
    server,
    (api) => api.post('/auth/register', {
      'tuitionName': tuitionName,
      'city': city,
      'adminName': adminName,
      'phone': phone,
      if (email.isNotEmpty) 'email': email,
      'password': password,
    }),
  );

  Future<void> acceptInvite({
    required String server,
    required String phone,
    required String code,
    required String password,
  }) => _signInWith(
    server,
    (api) => api.post('/auth/accept-invite', {
      'phone': phone,
      'code': code,
      'password': password,
    }),
  );

  // =============================================================== session

  UserRole? _role;
  String? _staffId;
  late String _selectedYearId;

  UserRole? get role => _role;
  bool get isSignedIn => _role != null;
  bool get isAdmin => _role == UserRole.admin;
  bool get isStaff => _role == UserRole.staff;

  StaffMember? get currentStaff {
    final id = _staffId;
    if (id == null) return null;
    for (final s in staff.all) {
      if (s.id == id) return s;
    }
    return null;
  }

  String get userName => isAdmin ? admin.name : (currentStaff?.name ?? '');
  String get userFirstName => userName.split(' ').first;
  String get userEmail => isAdmin ? admin.email : (currentStaff?.email ?? '');
  String get userPhone => isAdmin ? admin.phone : (currentStaff?.phone ?? '');
  String get userRoleLabel =>
      isAdmin ? UserRole.admin.label : (currentStaff?.designation ?? 'Staff');

  void signInAsAdmin() {
    _role = UserRole.admin;
    _staffId = null;
    _selectedYearId = academic.currentYear.id;
    _changed();
  }

  void signInAsStaff(String staffId) {
    _role = UserRole.staff;
    _staffId = staffId;
    _selectedYearId = academic.currentYear.id;
    _changed();
  }

  void signOut() {
    _role = null;
    _staffId = null;
    _poll?.cancel();
    _poll = null;
    smsSender?.stop();
    final api = _api;
    if (api != null) {
      api.token = null;
      _store?.save(server: api.baseUrl);
      _load(emptySeed());
      _selectedYearId = academic.currentYear.id;
    }
    _changed();
  }

  /// UI-level permission check. Admin can do everything. The server
  /// enforces the same rules independently.
  bool can(StaffPermission permission) {
    if (isAdmin) return true;
    final member = currentStaff;
    return member != null &&
        member.isActive &&
        member.permissions.contains(permission);
  }

  bool get canSeeFinance => isAdmin;
  bool get canOpenMessages => can(StaffPermission.sendParentMessages);

  /// Sending requires both the messaging and the SMS permission.
  bool get canSendMessages =>
      can(StaffPermission.sendParentMessages) && can(StaffPermission.sendSms);

  AcademicYear get selectedYear => academic.years.firstWhere(
    (y) => y.id == _selectedYearId,
    orElse: () => academic.currentYear,
  );
  AcademicYear get currentYear => academic.currentYear;

  void selectYear(String id) {
    _selectedYearId = id;
    _changed();
  }

  // =============================================================== classes

  /// Running classes the current user may work with.
  List<SchoolClass> get visibleClasses {
    final running = academic.runningClasses;
    if (isAdmin) return running;
    final ids = currentStaff?.assignedClassIds ?? const <String>[];
    return running.where((c) => ids.contains(c.id)).toList();
  }

  bool canAccessClass(String classId) =>
      isAdmin || (currentStaff?.assignedClassIds.contains(classId) ?? false);

  int enrolledCount(String classId, [String? yearId]) =>
      students.studentsIn(classId, yearId ?? _selectedYearId).length;

  Future<SchoolClass> addClass({
    required String name,
    required int grade,
    required String sessionLabel,
    required String room,
    required List<String> subjectIds,
  }) async {
    final api = _api;
    if (api != null) {
      final res =
          await api.post('/classes', {
                'name': name,
                'grade': grade,
                'sessionLabel': sessionLabel,
                'room': room,
                'subjectIds': subjectIds,
              })
              as Map<String, dynamic>;
      await refresh();
      return academic.classById(res['id'] as String);
    }
    return academic.addClass(
      name: name,
      grade: grade,
      sessionLabel: sessionLabel,
      room: room,
      subjectIds: subjectIds,
    );
  }

  Future<void> updateClass(
    SchoolClass cls, {
    required String name,
    required int grade,
    required String sessionLabel,
    required String room,
    required List<String> subjectIds,
    required bool isActive,
  }) async {
    final api = _api;
    if (api != null) {
      await api.patch('/classes/${cls.id}', {
        'name': name,
        'grade': grade,
        'sessionLabel': sessionLabel,
        'room': room,
        'subjectIds': subjectIds,
        'isActive': isActive,
      });
      return refresh();
    }
    academic.updateClass(
      cls,
      name: name,
      grade: grade,
      sessionLabel: sessionLabel,
      room: room,
      subjectIds: subjectIds,
      isActive: isActive,
    );
  }

  Future<void> assignStaffToClass(String classId, Set<String> staffIds) async {
    final api = _api;
    if (api != null) {
      await api.put('/classes/$classId/staff', {'staffIds': staffIds.toList()});
      return refresh();
    }
    staff.assignToClass(classId, staffIds);
  }

  Future<void> addYear({
    required String label,
    required DateTime start,
    required DateTime end,
  }) async {
    final api = _api;
    if (api != null) {
      await api.post('/academic-years', {
        'label': label,
        'startDate': _d(start),
        'endDate': _d(end),
      });
      return refresh();
    }
    academic.addYear(label: label, start: start, end: end);
  }

  Future<void> setCurrentYear(String yearId) async {
    final api = _api;
    if (api != null) {
      await api.post('/academic-years/$yearId/make-current');
      await refresh();
    } else {
      academic.setCurrentYear(yearId);
    }
    selectYear(yearId);
  }

  // ============================================================== students

  /// Students enrolled in [yearId], limited to the user's classes for staff.
  List<StudentEnrollment> directory({String? yearId}) {
    final year = yearId ?? _selectedYearId;
    final rows = <StudentEnrollment>[];
    for (final e in students.enrollmentsIn(year, includeInactive: true)) {
      if (!canAccessClass(e.classId)) continue;
      final s = students.tryById(e.studentId);
      if (s != null) rows.add(StudentEnrollment(s, e));
    }
    rows.sort((a, b) => a.student.fullName.compareTo(b.student.fullName));
    return rows;
  }

  int get activeStudentCount => directory(yearId: currentYear.id)
      .where(
        (r) =>
            r.student.isActive &&
            r.enrollment.status != EnrollmentStatus.withdrawn,
      )
      .length;

  Enrollment? enrollmentOf(String studentId, [String? yearId]) =>
      students.enrollmentFor(studentId, yearId ?? _selectedYearId) ??
      students.enrollmentFor(studentId, currentYear.id);

  String classNameOf(String studentId, [String? yearId]) {
    final e = enrollmentOf(studentId, yearId);
    return e == null ? 'Not enrolled' : academic.classById(e.classId).name;
  }

  List<Enrollment> historyOf(String studentId) =>
      students.enrollmentsOf(studentId, academic.years);

  /// The ID shown on the admission form. The server assigns the final one.
  String get nextStudentIdPreview =>
      isRemote ? 'Assigned on save' : students.nextStudentId();

  Future<Student> addStudent(AdmissionDraft d) async {
    final api = _api;
    if (api != null) {
      final fee = d.fee;
      final res =
          await api.post('/students', {
                'firstName': d.firstName,
                'lastName': d.lastName,
                'dateOfBirth': _d(d.dateOfBirth),
                if (d.gender != null) 'gender': d.gender!.name,
                'parentName': d.parentName,
                'parentPhone': d.parentPhone,
                if (d.altPhone != null) 'altPhone': d.altPhone,
                if (d.address != null) 'address': d.address,
                'yearId': d.yearId,
                'classId': d.classId,
                'enrolledOn': _d(d.enrolledOn),
                'active': d.active,
                if (fee != null && isAdmin)
                  'fee': {
                    'annualFee': fee.annualFee,
                    'installmentCount': fee.installments,
                    'frequency': fee.frequency.name,
                    'firstDueDate': _d(fee.firstDueDate),
                    'initialAmount': fee.initialAmount,
                    'paymentDate': _d(fee.paymentDate),
                    'method': fee.method.name,
                    if (fee.note != null) 'note': fee.note,
                  },
              })
              as Map<String, dynamic>;
      await refresh();
      return students.byId((res['student'] as Map)['id'] as String);
    }
    final student = Student(
      id: d.studentId,
      firstName: d.firstName,
      lastName: d.lastName,
      dateOfBirth: d.dateOfBirth,
      gender: d.gender,
      parentName: d.parentName,
      parentPhone: d.parentPhone,
      altPhone: d.altPhone,
      address: d.address,
      admittedOn: d.enrolledOn,
      isActive: d.active,
    );
    final enrollment = Enrollment(
      id: students.newEnrollmentId(),
      studentId: student.id,
      academicYearId: d.yearId,
      classId: d.classId,
      enrolledOn: d.enrolledOn,
      status: d.active ? EnrollmentStatus.active : EnrollmentStatus.withdrawn,
    );
    students.add(student, enrollment);
    final fee = d.fee;
    if (fee != null && isAdmin) {
      fees.addPlan(
        enrollmentId: enrollment.id,
        annualFee: fee.annualFee,
        installmentCount: fee.installments,
        frequency: fee.frequency,
        firstDueDate: fee.firstDueDate,
        note: fee.note,
      );
      if (fee.initialAmount > 0) {
        fees.record(
          enrollmentId: enrollment.id,
          amount: fee.initialAmount,
          date: fee.paymentDate,
          method: fee.method,
          recordedBy: userName,
          note: 'Initial payment at admission',
        );
      }
    }
    final className = academic.classById(d.classId).name;
    notifications
      ..add(
        type: NotificationType.student,
        title: 'New admission: ${student.fullName}',
        body: '$className · ${academic.yearById(d.yearId).label}',
      )
      ..log(
        ActivityEvent(
          type: ActivityType.student,
          title: 'Student admitted',
          subtitle: '${student.fullName} · $className',
          at: now,
        ),
      );
    return student;
  }

  /// Saves edits made to [student]'s fields.
  Future<void> saveStudent(Student student) async {
    final api = _api;
    if (api != null) {
      await api.patch('/students/${student.id}', {
        'firstName': student.firstName,
        'lastName': student.lastName,
        'dateOfBirth': _d(student.dateOfBirth),
        'gender': student.gender?.name,
        'parentName': student.parentName,
        'parentPhone': student.parentPhone,
        'altPhone': student.altPhone,
        'address': student.address,
        'isActive': student.isActive,
      });
      return refresh();
    }
    students.update(student);
  }

  // ================================================================== fees

  FeeSummary feeSummaryFor(String enrollmentId) =>
      fees.summaryFor(enrollmentId, today);

  List<FeeRow> feeDirectory({String? yearId}) {
    assert(isAdmin, 'Fees are admin-only');
    final year = yearId ?? _selectedYearId;
    final rows = <FeeRow>[];
    for (final e in students.enrollmentsIn(year, includeInactive: true)) {
      final s = students.tryById(e.studentId);
      if (s == null) continue;
      final plan = fees.planFor(e.id);
      if (plan == null && e.status == EnrollmentStatus.withdrawn) continue;
      rows.add(
        FeeRow(
          student: s,
          enrollment: e,
          plan: plan,
          summary: feeSummaryFor(e.id),
        ),
      );
    }
    rows.sort((a, b) => a.student.fullName.compareTo(b.student.fullName));
    return rows;
  }

  FeeSummary feeTotals({String? yearId, String? classId}) {
    var total = FeeSummary.empty;
    for (final row in feeDirectory(yearId: yearId)) {
      if (classId != null && row.enrollment.classId != classId) continue;
      total = total + row.summary;
    }
    return total;
  }

  Future<void> recordPayment({
    required Enrollment enrollment,
    required int amount,
    required DateTime date,
    required PaymentMethod method,
    String? reference,
    String? note,
  }) async {
    assert(isAdmin, 'Payments are admin-only');
    final api = _api;
    if (api != null) {
      await api.post('/fees/payments', {
        'enrollmentId': enrollment.id,
        'amount': amount,
        'date': _d(date),
        'method': method.name,
        'reference': ?reference,
        'note': ?note,
      });
      return refresh();
    }
    fees.record(
      enrollmentId: enrollment.id,
      amount: amount,
      date: date,
      method: method,
      recordedBy: userName,
      reference: reference,
      note: note,
    );
    final student = students.byId(enrollment.studentId);
    notifications.log(
      ActivityEvent(
        type: ActivityType.payment,
        title: 'Payment recorded · ${Fmt.currency(amount)}',
        subtitle: '${student.fullName} · ${method.label}',
        at: now,
        adminOnly: true,
      ),
    );
  }

  Future<FeeSetupResult> setFeePlan({
    required Enrollment enrollment,
    required int annualFee,
    required int installments,
    required FeeFrequency frequency,
    required DateTime firstDueDate,
  }) async {
    final api = _api;
    if (api != null) {
      try {
        await api.post('/fees/enrollments/${enrollment.id}/plan', {
          'annualFee': annualFee,
          'installmentCount': installments,
          'frequency': frequency.name,
          'firstDueDate': _d(firstDueDate),
        });
      } on ApiException catch (e) {
        if (e.isConflict) return FeeSetupResult.alreadyExists;
        rethrow;
      }
      await refresh();
      return FeeSetupResult.created;
    }
    if (fees.planFor(enrollment.id) != null) {
      return FeeSetupResult.alreadyExists;
    }
    fees.addPlan(
      enrollmentId: enrollment.id,
      annualFee: annualFee,
      installmentCount: installments,
      frequency: frequency,
      firstDueDate: firstDueDate,
    );
    return FeeSetupResult.created;
  }

  // ============================================================ attendance

  List<Student> rosterFor(String classId) =>
      students.studentsIn(classId, currentYear.id);

  AttendanceSession? todaySession(String classId) =>
      attendance.sessionFor(classId, today);

  /// Today's session for [classId] by matching class + date (server IDs are
  /// not derived from the date like the offline ones).
  AttendanceSession? _sessionOn(String classId, DateTime day) {
    for (final s in attendance.forClass(classId)) {
      if (Fmt.isSameDay(s.date, day)) return s;
    }
    return null;
  }

  TodayAttendance todayAttendance({List<SchoolClass>? classes}) {
    final list = classes ?? visibleClasses;
    var marked = 0, present = 0, absent = 0, other = 0, notMarked = 0;
    for (final c in list) {
      final session = todaySessionFor(c.id);
      if (session == null) {
        notMarked += rosterFor(c.id).length;
        continue;
      }
      marked++;
      present += session.presentCount + session.lateCount;
      absent += session.absentCount;
      other += session.lateCount + session.leaveCount;
    }
    return TodayAttendance(
      classesMarked: marked,
      classesTotal: list.length,
      present: present,
      absent: absent,
      lateOrLeave: other,
      notMarked: notMarked,
    );
  }

  /// Works in both modes (offline IDs encode the date; server IDs do not).
  AttendanceSession? todaySessionFor(String classId) =>
      isRemote ? _sessionOn(classId, today) : todaySession(classId);

  /// Saves today's attendance. If someone already saved this class today, the
  /// existing (locked) session is returned with `created: false`.
  Future<AttendanceSaveResult> saveAttendance(
    String classId,
    Map<String, AttendanceStatus> records,
  ) async {
    final api = _api;
    if (api != null) {
      String? sessionId;
      var created = true;
      try {
        final res =
            await api.post('/attendance/sessions', {
                  'classId': classId,
                  'records': {
                    for (final e in records.entries) e.key: e.value.name,
                  },
                })
                as Map<String, dynamic>;
        sessionId = res['id'] as String;
      } on ApiException catch (e) {
        if (!e.isConflict) rethrow;
        created = false;
        sessionId = ((e.details as Map?)?['session'] as Map?)?['id'] as String?;
      }
      await refresh();
      final session =
          (sessionId == null ? null : attendance.byId(sessionId)) ??
          todaySessionFor(classId)!;
      return AttendanceSaveResult(session, created: created);
    }
    final result = attendance.save(
      classId: classId,
      yearId: currentYear.id,
      date: today,
      records: records,
      markedBy: userName,
    );
    if (result.created) {
      final className = academic.classById(classId).name;
      notifications
        ..log(
          ActivityEvent(
            type: ActivityType.attendance,
            title: 'Attendance marked for $className',
            subtitle:
                '$userName · ${result.session.presentCount + result.session.lateCount} of ${result.session.total} present',
            at: now,
          ),
        )
        ..add(
          type: NotificationType.attendance,
          title: 'Attendance marked for $className',
          body: '$userName saved today\'s session.',
        );
    }
    return result;
  }

  Future<void> correctAttendance(
    AttendanceSession session,
    Map<String, AttendanceStatus> records,
    String note,
  ) async {
    final api = _api;
    if (api != null) {
      await api.patch('/attendance/sessions/${session.id}', {
        'note': note,
        'records': {for (final e in records.entries) e.key: e.value.name},
      });
      return refresh();
    }
    attendance.correct(session, records: records, by: userName, note: note);
  }

  // ================================================================= exams

  List<Exam> get visibleExams =>
      exams.all.where((e) => canAccessClass(e.classId)).toList();

  List<Student> examRoster(Exam exam) =>
      students.studentsIn(exam.classId, exam.academicYearId);

  StudentResult resultFor(Exam exam, String studentId) => StudentResult(
    studentId: studentId,
    exam: exam,
    subjects: [
      for (final s in exam.subjects)
        SubjectResult(
          subject: academic.subjectById(s.subjectId),
          maxMarks: s.maxMarks,
          entry: exam.markFor(s.subjectId, studentId),
        ),
    ],
  );

  /// Entered marks / expected marks across all subjects and students.
  (int, int) marksProgress(Exam exam, {String? subjectId}) {
    final roster = examRoster(exam);
    var entered = 0, total = 0;
    for (final s in exam.subjects) {
      if (subjectId != null && s.subjectId != subjectId) continue;
      for (final st in roster) {
        total++;
        if (exam.markFor(s.subjectId, st.id)?.isEntered ?? false) entered++;
      }
    }
    return (entered, total);
  }

  double? classAverage(Exam exam) {
    final results = examRoster(exam)
        .map((s) => resultFor(exam, s.id))
        .where((r) => r.isComplete && !r.absentInAll)
        .toList();
    if (results.isEmpty) return null;
    return results.fold<double>(0, (sum, r) => sum + r.percent) /
        results.length;
  }

  List<Map<String, Object>> _subjectsJson(List<ExamSubject> subjects) => [
    for (final s in subjects)
      {'subjectId': s.subjectId, 'maxMarks': s.maxMarks},
  ];

  Future<Exam> createExam({
    required String name,
    required String classId,
    required DateTime date,
    required List<ExamSubject> subjects,
    required String description,
    required bool isDraft,
    String? yearId,
  }) async {
    final api = _api;
    if (api != null) {
      final res =
          await api.post('/exams', {
                'name': name,
                'classId': classId,
                'date': _d(date),
                'subjects': _subjectsJson(subjects),
                'description': description,
                'isDraft': isDraft,
                'academicYearId': yearId ?? currentYear.id,
              })
              as Map<String, dynamic>;
      await refresh();
      return exams.byId(res['id'] as String);
    }
    final exam = exams.create(
      name: name,
      academicYearId: yearId ?? currentYear.id,
      classId: classId,
      date: date,
      subjects: subjects,
      description: description,
      isDraft: isDraft,
      createdBy: userName,
    );
    notifications.log(
      ActivityEvent(
        type: ActivityType.exam,
        title: isDraft ? 'Exam draft created' : 'Exam scheduled',
        subtitle: '$name · ${academic.classById(classId).name}',
        at: now,
      ),
    );
    return exam;
  }

  Future<void> updateExam(
    Exam exam, {
    required String name,
    required String classId,
    required DateTime date,
    required List<ExamSubject> subjects,
    required String description,
    required bool isDraft,
  }) async {
    final api = _api;
    if (api != null) {
      await api.patch('/exams/${exam.id}', {
        'name': name,
        'classId': classId,
        'date': _d(date),
        'subjects': _subjectsJson(subjects),
        'description': description,
        'isDraft': isDraft,
      });
      return refresh();
    }
    exams.update(
      exam,
      name: name,
      classId: classId,
      date: date,
      subjects: subjects,
      description: description,
      isDraft: isDraft,
    );
  }

  /// Saves one subject's marks. Pass `resync: false` when saving several
  /// subjects in a row, then call [refresh] once.
  Future<void> saveMarks(
    Exam exam,
    String subjectId,
    Map<String, MarkEntry> entries, {
    String? correctionNote,
    bool resync = true,
  }) async {
    final api = _api;
    if (api != null) {
      await api.put('/exams/${exam.id}/marks/$subjectId', {
        'entries': {
          for (final e in entries.entries)
            e.key: e.value.absent ? {'absent': true} : {'marks': e.value.marks},
        },
        'correctionNote': ?correctionNote,
      });
      if (resync) await refresh();
      return;
    }
    exams.saveMarks(exam, subjectId, entries);
    if (correctionNote != null) {
      exams.logCorrection(
        exam,
        '${Fmt.dateTime(now)} · $userName · ${academic.subjectById(subjectId).name}: $correctionNote',
      );
    }
  }

  Future<void> publishResults(Exam exam) async {
    final api = _api;
    if (api != null) {
      await api.post('/exams/${exam.id}/publish');
      return refresh();
    }
    exams.publish(exam);
    final className = academic.classById(exam.classId).name;
    notifications
      ..log(
        ActivityEvent(
          type: ActivityType.exam,
          title: 'Results published',
          subtitle: '${exam.name} · $className',
          at: now,
        ),
      )
      ..add(
        type: NotificationType.exam,
        title: 'Results published: ${exam.name}',
        body: '$className results are ready to share with parents.',
      );
  }

  String resultMessage(Exam exam, Student student) =>
      MessageTemplates.examResult(
        examName: exam.name,
        student: student.fullName,
        result: resultFor(exam, student.id),
        tuition: tuition.name,
      );

  String resultsSourceKey(Exam exam) => 'exam:${exam.id}:r${exam.revision}';

  /// Turns a batch response from the server into a [BatchResult].
  Future<BatchResult> _remoteBatch(Future<dynamic> request) async {
    final res = await request as Map<String, dynamic>;
    await refresh();
    final id = (res['batch'] as Map)['id'] as String;
    return BatchResult(messaging.byId(id)!, created: res['created'] == true);
  }

  Future<BatchResult> sendResults(Exam exam, List<Student> recipients) async {
    assert(canSendMessages);
    final api = _api;
    if (api != null) {
      return _remoteBatch(
        api.post('/messages/exam-results/${exam.id}', {
          'studentIds': [for (final s in recipients) s.id],
        }),
      );
    }
    final className = academic.classById(exam.classId).name;
    final drafts = [
      for (final s in recipients)
        RecipientDraft(
          studentId: s.id,
          studentName: s.fullName,
          parentName: s.parentName,
          phone: s.parentPhone,
          body: resultMessage(exam, s),
        ),
    ];
    final result = messaging.createBatch(
      sourceKey: resultsSourceKey(exam),
      title: exam.revision > 0
          ? '${exam.name} results (corrected)'
          : '${exam.name} results',
      category: MessageCategory.examResults,
      classIds: [exam.classId],
      createdBy: userName,
      previewBody: drafts.isEmpty ? '' : drafts.first.body,
      recipients: drafts,
    );
    if (result.created) {
      notifications.log(
        ActivityEvent(
          type: ActivityType.message,
          title: 'Results sent to parents',
          subtitle:
              '${exam.name} · $className · ${Fmt.plural(drafts.length, 'parent')}',
          at: now,
        ),
      );
    }
    return result;
  }

  // ============================================================= messaging

  List<MessageBatch> get visibleBatches => messaging.batches.where((b) {
    if (isAdmin) return true;
    if (b.category == MessageCategory.feeReminder) return false;
    return b.classIds.any(canAccessClass);
  }).toList();

  String attendanceSourceKey(AttendanceSession s) => 'attendance:${s.id}';

  Future<BatchResult> notifyAttendance(
    AttendanceSession session,
    Set<AttendanceStatus> include, {
    Set<String> excludeStudentIds = const {},
  }) async {
    assert(canSendMessages);
    final api = _api;
    if (api != null) {
      return _remoteBatch(
        api.post('/messages/attendance/${session.id}', {
          'statuses': [for (final s in include) s.name],
          'excludeStudentIds': excludeStudentIds.toList(),
        }),
      );
    }
    final drafts = <RecipientDraft>[];
    session.records.forEach((studentId, status) {
      if (!include.contains(status) || excludeStudentIds.contains(studentId)) {
        return;
      }
      final s = students.tryById(studentId);
      if (s == null) return;
      drafts.add(
        RecipientDraft(
          studentId: s.id,
          studentName: s.fullName,
          parentName: s.parentName,
          phone: s.parentPhone,
          body: MessageTemplates.attendance(status, s.fullName, tuition.name),
        ),
      );
    });
    drafts.sort((a, b) => a.studentName.compareTo(b.studentName));
    final className = academic.classById(session.classId).name;
    return messaging.createBatch(
      sourceKey: attendanceSourceKey(session),
      title: '$className attendance · ${Fmt.shortDate(session.date)}',
      category: MessageCategory.attendance,
      classIds: [session.classId],
      createdBy: userName,
      previewBody: MessageTemplates.attendance(
        include.contains(AttendanceStatus.absent)
            ? AttendanceStatus.absent
            : AttendanceStatus.present,
        '[Student Name]',
        tuition.name,
      ),
      recipients: drafts,
    );
  }

  /// [draftKey] is generated once per composer, so double taps cannot create
  /// a second batch.
  Future<BatchResult> sendAnnouncement({
    required String draftKey,
    required String title,
    required String body,
    required List<String> classIds,
    List<Student>? selected,
  }) async {
    assert(canSendMessages);
    final api = _api;
    if (api != null) {
      return _remoteBatch(
        api.post('/messages/announcements', {
          'draftKey': draftKey,
          'title': title,
          'body': body,
          'classIds': classIds,
          if (selected != null) 'studentIds': [for (final s in selected) s.id],
        }),
      );
    }
    final list =
        selected ??
        [for (final c in classIds) ...students.studentsIn(c, currentYear.id)];
    final message = MessageTemplates.announcement(title, body, tuition.name);
    return messaging.createBatch(
      sourceKey: 'announcement:$draftKey',
      title: title,
      category: MessageCategory.announcement,
      classIds: classIds,
      createdBy: userName,
      previewBody: message,
      recipients: [
        for (final s in list)
          RecipientDraft(
            studentId: s.id,
            studentName: s.fullName,
            parentName: s.parentName,
            phone: s.parentPhone,
            body: message,
          ),
      ],
    );
  }

  String get feeReminderKey => 'fees:reminder:${_d(today)}';

  List<FeeRow> get overdueRows => feeDirectory(
    yearId: currentYear.id,
  ).where((r) => r.summary.overdue > 0 && r.student.isActive).toList();

  Future<BatchResult> sendFeeReminders() async {
    assert(isAdmin);
    final api = _api;
    if (api != null) return _remoteBatch(api.post('/messages/fee-reminders'));
    final rows = overdueRows;
    return messaging.createBatch(
      sourceKey: feeReminderKey,
      title: 'Fee reminder · ${Fmt.shortDate(today)}',
      category: MessageCategory.feeReminder,
      classIds: rows.map((r) => r.enrollment.classId).toSet().toList(),
      createdBy: userName,
      previewBody: MessageTemplates.feeReminder(
        '[Student Name]',
        2000,
        tuition.name,
      ),
      recipients: [
        for (final r in rows)
          RecipientDraft(
            studentId: r.student.id,
            studentName: r.student.fullName,
            parentName: r.student.parentName,
            phone: r.student.parentPhone,
            body: MessageTemplates.feeReminder(
              r.student.fullName,
              r.summary.overdue,
              tuition.name,
            ),
          ),
      ],
    );
  }

  /// Retries failed (and stuck pending) recipients only. Returns the count.
  Future<int> retryBatch(MessageBatch batch) async {
    final api = _api;
    if (api != null) {
      final res =
          await api.post('/messages/batches/${batch.id}/retry')
              as Map<String, dynamic>;
      await refresh();
      return ((res['retried'] as num?) ?? 0).toInt() +
          ((res['pending'] as num?) ?? 0).toInt();
    }
    return messaging.retryFailed(batch) + messaging.processPending(batch);
  }

  /// In connected mode stuck messages are handled by [retryBatch].
  bool hasStuckPending(MessageBatch batch) =>
      !isRemote && messaging.hasStuckPending(batch);

  ({int sentToday, int failed, int pending}) get messageStats {
    var sent = 0, failed = 0, pending = 0;
    for (final b in visibleBatches) {
      failed += b.failed;
      pending += b.pending;
      for (final r in b.recipients) {
        if (r.status.isSuccessful && Fmt.isSameDay(r.updatedAt, now)) sent++;
      }
    }
    return (sentToday: sent, failed: failed, pending: pending);
  }

  void _onBatchSettled(MessageBatch batch) {
    if (batch.failed == 0) return;
    notifications.add(
      type: NotificationType.messageFailed,
      title: '${Fmt.plural(batch.failed, 'message')} failed',
      body: '${batch.title} · Retry failed messages from the batch details.',
      adminOnly: batch.category == MessageCategory.feeReminder,
    );
  }

  // ========================================================= notifications

  Future<void> markNotificationRead(AppNotification n) async {
    if (n.isRead) return;
    notifications.markRead(n);
    await _api?.post('/notifications/${n.id}/read');
  }

  Future<void> markAllNotificationsRead() async {
    notifications.markAllRead(isAdmin: isAdmin);
    await _api?.post('/notifications/read-all');
  }

  // ================================================================= staff

  Future<void> setStaffPermission(
    StaffMember member,
    StaffPermission p,
    bool granted,
  ) async {
    final api = _api;
    if (api != null) {
      final next = {...member.permissions};
      granted ? next.add(p) : next.remove(p);
      await api.put('/staff/${member.id}/permissions', {
        'permissions': [for (final x in next) x.name],
      });
      return refresh();
    }
    staff.setPermission(member, p, granted);
  }

  Future<StaffMember> addStaff({
    required String name,
    required String email,
    required String phone,
    required String designation,
    required List<String> classIds,
    required bool isActive,
  }) async {
    final api = _api;
    if (api != null) {
      final res =
          await api.post('/staff', {
                'name': name,
                if (email.isNotEmpty) 'email': email,
                'phone': phone,
                'designation': designation,
                'assignedClassIds': classIds,
                'isActive': isActive,
              })
              as Map<String, dynamic>;
      await refresh();
      return staff.byId(res['id'] as String);
    }
    final member = staff.add(
      name: name,
      email: email,
      phone: phone,
      designation: designation,
      classIds: classIds,
      isActive: isActive,
    );
    notifications.log(
      ActivityEvent(
        type: ActivityType.staff,
        title: 'Staff member added',
        subtitle: '$name · $designation',
        at: now,
        adminOnly: true,
      ),
    );
    return member;
  }

  Future<void> updateStaff(
    StaffMember member, {
    required String name,
    required String email,
    required String phone,
    required String designation,
    required List<String> classIds,
    required bool isActive,
  }) async {
    final api = _api;
    if (api != null) {
      await api.patch('/staff/${member.id}', {
        'name': name,
        'email': email,
        'phone': phone,
        'designation': designation,
        'assignedClassIds': classIds,
        'isActive': isActive,
      });
      return refresh();
    }
    staff.update(
      member,
      name: name,
      email: email,
      phone: phone,
      designation: designation,
      classIds: classIds,
      isActive: isActive,
    );
  }

  /// Connected: issues a fresh invite code. Offline: marks the invite accepted.
  Future<void> resetInvite(StaffMember member) async {
    final api = _api;
    if (api != null) {
      await api.post('/staff/${member.id}/reset-invite');
      return refresh();
    }
    staff.markInvitationAccepted(member);
  }

  // ============================================================ settings

  Future<void> updateTuition({
    required String name,
    required String city,
    required String address,
    required String phone,
    required String email,
  }) async {
    final api = _api;
    if (api != null) {
      await api.patch('/tuition', {
        'name': name,
        'city': city,
        'address': address,
        'phone': phone,
        'email': email,
      });
      return refresh();
    }
    tuition
      ..name = name
      ..city = city
      ..address = address
      ..phone = phone
      ..email = email;
    _changed();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    final api = _api;
    if (api != null) {
      await api.patch('/me', {'name': name, 'email': email, 'phone': phone});
      return refresh();
    }
    if (isAdmin) {
      admin
        ..name = name
        ..email = email
        ..phone = phone;
      _changed();
    } else {
      final m = currentStaff!;
      staff.update(
        m,
        name: name,
        email: email,
        phone: phone,
        designation: m.designation,
        classIds: m.assignedClassIds,
        isActive: m.isActive,
      );
    }
  }

  // ============================================================ promotion

  Future<PromotionResult> promote({
    required AcademicYear from,
    required AcademicYear to,
    required SchoolClass toClass,
    required List<String> studentIds,
    int? annualFee,
    int installments = 1,
  }) async {
    assert(isAdmin);
    final api = _api;
    if (api != null) {
      final res =
          await api.post('/promotions', {
                'fromYearId': from.id,
                'toYearId': to.id,
                'toClassId': toClass.id,
                'studentIds': studentIds,
                if (annualFee != null && annualFee > 0) 'annualFee': annualFee,
                'installments': installments,
              })
              as Map<String, dynamic>;
      await refresh();
      final promotedIds = [
        for (final e in (res['promoted'] as List)) (e as Map)['id'] as String,
      ];
      return PromotionResult(
        promoted: [for (final id in promotedIds) ?students.enrollmentById(id)],
        skipped: [for (final s in (res['skipped'] as List)) s as String],
      );
    }
    final result = students.promote(
      fromYearId: from.id,
      toYearId: to.id,
      toClassId: toClass.id,
      studentIds: studentIds,
      enrolledOn: to.startDate,
    );
    // The new year's fee is a separate agreement; earlier plans are untouched.
    if (annualFee != null && annualFee > 0) {
      for (final e in result.promoted) {
        fees.addPlan(
          enrollmentId: e.id,
          annualFee: annualFee,
          installmentCount: installments,
          frequency: installments == 1
              ? FeeFrequency.custom
              : FeeFrequency.monthly,
          firstDueDate: DateTime(to.startDate.year, to.startDate.month, 10),
        );
      }
    }
    if (result.promoted.isNotEmpty) {
      notifications.log(
        ActivityEvent(
          type: ActivityType.student,
          title: 'Students promoted',
          subtitle:
              '${Fmt.plural(result.promoted.length, 'student')} → ${toClass.name}, ${to.label}',
          at: now,
          adminOnly: true,
        ),
      );
    }
    return result;
  }
}

enum FeeSetupResult { created, alreadyExists }
