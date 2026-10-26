import 'package:flutter/widgets.dart';

import '../core/utils/formatters.dart';
import '../shared/models/models.dart';
import 'message_templates.dart';
import 'mock_data.dart';
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

/// Application state for the static phase: the signed-in demo role plus the
/// mock repositories. Everything is in memory and resets on restart.
///
/// Role and permission checks here only shape the UI. They are not security;
/// the future backend must enforce access control and tenant isolation.
class AppState extends ChangeNotifier {
  AppState({DateTime? now, MessageTransport? transport}) {
    final start = now ?? DateTime.now();
    _clockOffset = start.difference(DateTime.now());
    final seed = buildMockSeed(start);
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
    _transport = transport ?? SimulatedMessageTransport();
    messaging = MessagingRepository(
      _changed,
      batches: seed.batches,
      sms: seed.sms,
      transport: _transport,
      onBatchSettled: _onBatchSettled,
    );
    events = seed.events;
    _selectedYearId = academic.currentYear.id;
  }

  late final Tuition tuition;
  late final AdminUser admin;
  late final AcademicRepository academic;
  late final StudentRepository students;
  late final FeeRepository fees;
  late final AttendanceRepository attendance;
  late final ExamRepository exams;
  late final StaffRepository staff;
  late final NotificationRepository notifications;
  late final MessagingRepository messaging;
  late final List<TuitionEvent> events;

  /// In-memory preferences (reset on restart).
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

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Call after mutating a model object directly (e.g. settings forms).
  void touch() => _changed();

  @override
  void dispose() {
    _disposed = true;
    _transport.dispose();
    super.dispose();
  }

  /// Non-zero only when a fixed start time is injected (tests, demos).
  late final Duration _clockOffset;

  DateTime get now => DateTime.now().add(_clockOffset);
  DateTime get today => Fmt.dateOnly(now);

  // =============================================================== session

  UserRole? _role;
  String? _staffId;
  late String _selectedYearId;

  UserRole? get role => _role;
  bool get isSignedIn => _role != null;
  bool get isAdmin => _role == UserRole.admin;
  bool get isStaff => _role == UserRole.staff;

  StaffMember? get currentStaff =>
      _staffId == null ? null : staff.byId(_staffId!);

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
    _changed();
  }

  /// UI-level permission check. Admin can do everything.
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

  AcademicYear get selectedYear => academic.yearById(_selectedYearId);
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

  Student addStudent(AdmissionDraft d) {
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

  Payment recordPayment({
    required Enrollment enrollment,
    required int amount,
    required DateTime date,
    required PaymentMethod method,
    String? reference,
    String? note,
  }) {
    assert(isAdmin, 'Payments are admin-only');
    final payment = fees.record(
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
    return payment;
  }

  FeeSetupResult setFeePlan({
    required Enrollment enrollment,
    required int annualFee,
    required int installments,
    required FeeFrequency frequency,
    required DateTime firstDueDate,
  }) {
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

  TodayAttendance todayAttendance({List<SchoolClass>? classes}) {
    final list = classes ?? visibleClasses;
    var marked = 0, present = 0, absent = 0, other = 0, notMarked = 0;
    for (final c in list) {
      final session = todaySession(c.id);
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

  AttendanceSaveResult saveAttendance(
    String classId,
    Map<String, AttendanceStatus> records,
  ) {
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
                '$userName · ${result.session.presentCount + result.session.lateCount}'
                ' of ${result.session.total} present',
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

  void correctAttendance(
    AttendanceSession session,
    Map<String, AttendanceStatus> records,
    String note,
  ) {
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

  Exam createExam({
    required String name,
    required String classId,
    required DateTime date,
    required List<ExamSubject> subjects,
    required String description,
    required bool isDraft,
    String? yearId,
  }) {
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

  void saveMarks(
    Exam exam,
    String subjectId,
    Map<String, MarkEntry> entries, {
    String? correctionNote,
  }) {
    exams.saveMarks(exam, subjectId, entries);
    if (correctionNote != null) {
      exams.logCorrection(
        exam,
        '${Fmt.dateTime(now)} · $userName · ${academic.subjectById(subjectId).name}: $correctionNote',
      );
    }
  }

  void publishResults(Exam exam) {
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

  BatchResult sendResults(Exam exam, List<Student> recipients) {
    assert(canSendMessages);
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

  BatchResult notifyAttendance(
    AttendanceSession session,
    Set<AttendanceStatus> include, {
    Set<String> excludeStudentIds = const {},
  }) {
    assert(canSendMessages);
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
  BatchResult sendAnnouncement({
    required String draftKey,
    required String title,
    required String body,
    required List<String> classIds,
    List<Student>? selected,
  }) {
    assert(canSendMessages);
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

  String get feeReminderKey =>
      'fees:reminder:${today.year}-${today.month}-${today.day}';

  List<FeeRow> get overdueRows => feeDirectory(
    yearId: currentYear.id,
  ).where((r) => r.summary.overdue > 0 && r.student.isActive).toList();

  BatchResult sendFeeReminders() {
    assert(isAdmin);
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

  // ================================================================= staff

  void setStaffPermission(
    StaffMember member,
    StaffPermission p,
    bool granted,
  ) => staff.setPermission(member, p, granted);

  StaffMember addStaff({
    required String name,
    required String email,
    required String phone,
    required String designation,
    required List<String> classIds,
    required bool isActive,
  }) {
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

  // ============================================================ promotion

  PromotionResult promote({
    required AcademicYear from,
    required AcademicYear to,
    required SchoolClass toClass,
    required List<String> studentIds,
    int? annualFee,
    int installments = 1,
  }) {
    assert(isAdmin);
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
