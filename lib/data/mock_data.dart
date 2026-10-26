import 'dart:math';

import '../shared/models/models.dart';
import 'message_templates.dart';

/// Everything the demo starts with. Generated deterministically so totals are
/// consistent between runs. All people, numbers and contacts are fictional.
class MockSeed {
  MockSeed({
    required this.tuition,
    required this.admin,
    required this.staff,
    required this.years,
    required this.classes,
    required this.subjects,
    required this.students,
    required this.enrollments,
    required this.feePlans,
    required this.payments,
    required this.sessions,
    required this.exams,
    required this.batches,
    required this.notifications,
    required this.activity,
    required this.sms,
    required this.events,
  });

  final Tuition tuition;
  final AdminUser admin;
  final List<StaffMember> staff;
  final List<AcademicYear> years;
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final List<Student> students;
  final List<Enrollment> enrollments;
  final List<FeePlan> feePlans;
  final List<Payment> payments;
  final List<AttendanceSession> sessions;
  final List<Exam> exams;
  final List<MessageBatch> batches;
  final List<AppNotification> notifications;
  final List<ActivityEvent> activity;
  final SmsSettings sms;
  final List<TuitionEvent> events;
}

const kCurrentYearId = 'ay-2026';

MockSeed buildMockSeed(DateTime now) => _SeedBuilder(now).build();

class _SeedBuilder {
  _SeedBuilder(this.now) : today = DateTime(now.year, now.month, now.day);

  final DateTime now;
  final DateTime today;
  final _rnd = Random(2026);

  static const _boys = [
    'Vihaan', 'Arjun', 'Sai', 'Reyansh', 'Ayaan', 'Krishna', 'Ishaan', //
    'Shaurya', 'Atharv', 'Advait', 'Om', 'Rudra', 'Kabir', 'Aditya', 'Yash',
    'Pranav', 'Siddharth', 'Tanmay', 'Omkar', 'Soham', 'Harsh', 'Rohan',
    'Varun', 'Nikhil', 'Aryan', 'Dhruv', 'Parth', 'Vedant', 'Mihir', 'Kunal',
  ];
  static const _girls = [
    'Ananya', 'Diya', 'Saanvi', 'Aadhya', 'Ira', 'Myra', 'Anvi', 'Riya', //
    'Kavya', 'Isha', 'Sanika', 'Gauri', 'Mrunal', 'Shravani', 'Tanvi',
    'Rutuja', 'Sakshi', 'Aditi', 'Janhavi', 'Siya', 'Prachi', 'Vaishnavi',
    'Swara', 'Avni', 'Khushi', 'Nidhi', 'Ketaki', 'Mansi', 'Shruti', 'Tejal',
  ];
  static const _surnames = [
    'Patil', 'Pawar', 'Jadhav', 'Shinde', 'Deshmukh', 'Kulkarni', 'Joshi', //
    'Chavan', 'More', 'Gaikwad', 'Bhosale', 'Kale', 'Wagh', 'Sawant',
    'Sharma', 'Mehta', 'Shah', 'Iyer', 'Nair', 'Reddy', 'Gupta', 'Verma',
    'Agarwal', 'Thakur', 'Mane', 'Kadam', 'Salunkhe', 'Nikam', 'Sonawane',
    'Borse',
  ];
  static const _fathers = [
    'Sunil', 'Rajesh', 'Sanjay', 'Mahesh', 'Prakash', 'Anil', 'Vijay', //
    'Santosh', 'Ramesh', 'Dinesh', 'Nitin', 'Sachin', 'Ajay', 'Manoj',
    'Deepak', 'Rahul', 'Amol', 'Yogesh', 'Kiran', 'Sandeep',
  ];
  static const _mothers = [
    'Sunita', 'Kavita', 'Meena', 'Swati', 'Asha', 'Vaishali', 'Archana', //
    'Manisha', 'Rupali', 'Jyoti',
  ];
  static const _areas = [
    'Gangapur Road', 'College Road', 'Indira Nagar', 'Panchavati', //
    'Nashik Road', 'Satpur', 'Cidco', 'Pathardi Phata', 'Govind Nagar',
  ];
  static const _buildings = [
    'Shree Residency', 'Sai Darshan Apartments', 'Krishna Kunj', //
    'Om Heights', 'Ganga Vihar', 'Samarth Park', 'Pushpak Society',
  ];
  static const _baseFee = {
    4: 10000,
    5: 12000,
    6: 13000,
    7: 14000,
    8: 16000,
    9: 18000,
    10: 20000,
  };

  final students = <Student>[];
  final enrollments = <Enrollment>[];
  final feePlans = <FeePlan>[];
  final payments = <Payment>[];
  final sessions = <AttendanceSession>[];
  final exams = <Exam>[];
  final batches = <MessageBatch>[];
  final _ability = <String, double>{};
  final _reliability = <String, double>{};
  final _usedNames = <String>{};
  var _enr = 0;
  var _fee = 0;
  var _payCounter = 0;

  final tuition = Tuition(
    id: 'tui-1',
    name: 'Bright Future Classes',
    city: 'Nashik',
    address: '2nd Floor, Sai Plaza, College Road, Nashik 422005',
    phone: '9822041567',
    email: 'hello@brightfutureclasses.in',
  );

  final admin = AdminUser(
    id: 'adm-1',
    name: 'Rahul Sharma',
    email: 'rahul@brightfutureclasses.in',
    phone: '9822041567',
  );

  final years = [
    AcademicYear(
      id: 'ay-2024',
      label: '2024–25',
      startDate: DateTime(2024, 6, 1),
      endDate: DateTime(2025, 4, 30),
      status: YearStatus.closed,
    ),
    AcademicYear(
      id: 'ay-2025',
      label: '2025–26',
      startDate: DateTime(2025, 6, 1),
      endDate: DateTime(2026, 4, 30),
      status: YearStatus.closed,
    ),
    AcademicYear(
      id: kCurrentYearId,
      label: '2026–27',
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2027, 4, 30),
      status: YearStatus.active,
    ),
    AcademicYear(
      id: 'ay-2027',
      label: '2027–28',
      startDate: DateTime(2027, 6, 1),
      endDate: DateTime(2028, 4, 30),
      status: YearStatus.upcoming,
    ),
  ];

  static const _junior = ['sub-math', 'sub-sci', 'sub-eng'];
  static const _senior = ['sub-math', 'sub-sci', 'sub-eng', 'sub-ss'];

  final classes = [
    SchoolClass(
      id: 'cls-4',
      name: 'Class 4',
      grade: 4,
      sessionLabel: '4:00 – 5:00 PM',
      room: 'Room 1',
      subjectIds: [..._junior],
      isActive: false,
    ),
    SchoolClass(
      id: 'cls-5',
      name: 'Class 5',
      grade: 5,
      sessionLabel: '4:00 – 5:00 PM',
      room: 'Room 1',
      subjectIds: [..._junior],
    ),
    SchoolClass(
      id: 'cls-6',
      name: 'Class 6',
      grade: 6,
      sessionLabel: '5:00 – 6:00 PM',
      room: 'Room 1',
      subjectIds: [..._junior],
    ),
    SchoolClass(
      id: 'cls-7',
      name: 'Class 7',
      grade: 7,
      sessionLabel: '6:00 – 7:00 PM',
      room: 'Room 2',
      subjectIds: [..._junior],
    ),
    SchoolClass(
      id: 'cls-8',
      name: 'Class 8',
      grade: 8,
      sessionLabel: '7:00 – 8:00 AM',
      room: 'Room 2',
      subjectIds: [..._senior],
    ),
    SchoolClass(
      id: 'cls-9',
      name: 'Class 9',
      grade: 9,
      sessionLabel: '8:00 – 9:30 AM',
      room: 'Room 3',
      subjectIds: [..._senior],
    ),
    SchoolClass(
      id: 'cls-10',
      name: 'Class 10',
      grade: 10,
      sessionLabel: '6:00 – 7:30 PM',
      room: 'Room 3',
      subjectIds: [..._senior],
    ),
  ];

  final subjects = const [
    Subject(id: 'sub-math', name: 'Mathematics', code: 'MATH'),
    Subject(id: 'sub-sci', name: 'Science', code: 'SCI'),
    Subject(id: 'sub-eng', name: 'English', code: 'ENG'),
    Subject(id: 'sub-ss', name: 'Social Studies', code: 'SST'),
    Subject(id: 'sub-hin', name: 'Hindi', code: 'HIN'),
    Subject(id: 'sub-mar', name: 'Marathi', code: 'MAR'),
  ];

  late final staff = [
    StaffMember(
      id: 'stf-1',
      name: 'Sneha Kulkarni',
      phone: '9881234570',
      email: 'sneha.k@brightfutureclasses.in',
      designation: 'Mathematics teacher',
      assignedClassIds: ['cls-5', 'cls-6', 'cls-7'],
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.markAttendance,
        StaffPermission.viewExamResults,
        StaffPermission.enterMarks,
        StaffPermission.sendParentMessages,
        StaffPermission.sendSms,
      },
      joinedOn: DateTime(2023, 6, 5),
    ),
    StaffMember(
      id: 'stf-2',
      name: 'Amit Deshmukh',
      phone: '9762045318',
      email: 'amit.d@brightfutureclasses.in',
      designation: 'Science teacher',
      assignedClassIds: ['cls-8', 'cls-9', 'cls-10'],
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.markAttendance,
        StaffPermission.viewExamResults,
        StaffPermission.enterMarks,
      },
      joinedOn: DateTime(2024, 6, 3),
    ),
    StaffMember(
      id: 'stf-3',
      name: 'Pooja Joshi',
      phone: '8805512946',
      email: 'pooja.j@brightfutureclasses.in',
      designation: 'English teacher',
      assignedClassIds: ['cls-5', 'cls-8'],
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.markAttendance,
        StaffPermission.viewExamResults,
        StaffPermission.enterMarks,
        StaffPermission.sendParentMessages,
      },
      joinedOn: DateTime(2025, 7, 1),
    ),
    StaffMember(
      id: 'stf-4',
      name: 'Vikram Patil',
      phone: '9423087651',
      email: 'vikram.p@brightfutureclasses.in',
      designation: 'Social studies teacher',
      assignedClassIds: ['cls-9', 'cls-10'],
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.markAttendance,
      },
      joinedOn: DateTime(2025, 6, 9),
    ),
    StaffMember(
      id: 'stf-5',
      name: 'Neha Gaikwad',
      phone: '7798456120',
      email: 'neha.g@brightfutureclasses.in',
      designation: 'Front desk coordinator',
      assignedClassIds: ['cls-5', 'cls-6', 'cls-7', 'cls-8', 'cls-9', 'cls-10'],
      permissions: {
        StaffPermission.viewStudents,
        StaffPermission.editStudents,
        StaffPermission.sendParentMessages,
        StaffPermission.sendSms,
      },
      joinedOn: today,
      accountStatus: AccountStatus.invitationPending,
    ),
  ];

  MockSeed build() {
    _buildStudents();
    _buildAttendance();
    _buildExams();
    _buildBatches();
    return MockSeed(
      tuition: tuition,
      admin: admin,
      staff: staff,
      years: years,
      classes: classes,
      subjects: subjects,
      students: students,
      enrollments: enrollments,
      feePlans: feePlans,
      payments: payments,
      sessions: sessions,
      exams: exams,
      batches: batches,
      notifications: _notifications(),
      activity: _activity(),
      sms: SmsSettings(
        mode: SendingMode.androidDevice,
        deviceName: 'Redmi Note 12 · Front desk',
        lastSync: now.subtract(const Duration(minutes: 12)),
        monthlyAllowance: 3000,
        usedThisMonth: 1264,
        senderSignature: 'Bright Future Classes',
      ),
      events: [
        TuitionEvent(
          title: 'Parent–teacher meeting',
          date: today.add(const Duration(days: 4)),
          subtitle: 'Classes 9 & 10 · 11:00 AM, Room 3',
        ),
        TuitionEvent(
          title: 'Diwali holidays',
          date: DateTime(2026, 11, 7),
          endDate: DateTime(2026, 11, 10),
          subtitle: 'All batches closed',
        ),
        TuitionEvent(
          title: 'Second-term fee instalment due',
          date: DateTime(2026, 12, 10),
          subtitle: 'Quarterly plans',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- students

  void _buildStudents() {
    const counts = {
      'cls-5': 22,
      'cls-6': 21,
      'cls-7': 23,
      'cls-8': 20,
      'cls-9': 22,
      'cls-10': 20,
    };
    const fixed = [
      ('Ganesh', 'Pawar', Gender.male),
      ('Aarav', 'Sharma', Gender.male),
      ('Priya', 'Patil', Gender.female),
    ];
    for (final f in fixed) {
      _usedNames.add('${f.$1} ${f.$2}');
    }
    var n = 0;
    for (final entry in counts.entries) {
      final cls = classes.firstWhere((c) => c.id == entry.key);
      for (var i = 0; i < entry.value; i++) {
        n++;
        final name = n <= fixed.length ? fixed[n - 1] : _randomName();
        _addStudent(n, name.$1, name.$2, name.$3, cls);
      }
    }
    // A few withdrawn students so the inactive filter has data.
    for (final classId in ['cls-6', 'cls-7', 'cls-9']) {
      n++;
      final name = _randomName();
      final cls = classes.firstWhere((c) => c.id == classId);
      _addStudent(n, name.$1, name.$2, name.$3, cls, active: false);
    }
  }

  (String, String, Gender) _randomName() {
    while (true) {
      final female = _rnd.nextBool();
      final first = female
          ? _girls[_rnd.nextInt(_girls.length)]
          : _boys[_rnd.nextInt(_boys.length)];
      final last = _surnames[_rnd.nextInt(_surnames.length)];
      if (_usedNames.add('$first $last')) {
        return (first, last, female ? Gender.female : Gender.male);
      }
    }
  }

  String _phone() {
    final lead = ['98', '97', '96', '94', '93', '88', '87', '77', '70'];
    final buffer = StringBuffer(lead[_rnd.nextInt(lead.length)]);
    for (var i = 0; i < 8; i++) {
      buffer.write(_rnd.nextInt(10));
    }
    return buffer.toString();
  }

  void _addStudent(
    int n,
    String first,
    String last,
    Gender gender,
    SchoolClass cls, {
    bool active = true,
  }) {
    final id = 'STU-${n.toString().padLeft(4, '0')}';
    final grade = cls.grade;
    final useMother = _rnd.nextDouble() < 0.25;
    final parentFirst = useMother
        ? _mothers[_rnd.nextInt(_mothers.length)]
        : _fathers[_rnd.nextInt(_fathers.length)];

    var prior = 0;
    if (n == 1) {
      prior = 1; // Ganesh: Class 4 in 2025–26.
    } else if (grade == 5) {
      prior = _rnd.nextDouble() < 0.3 ? 1 : 0;
    } else if (_rnd.nextDouble() < 0.65) {
      prior = grade >= 7 && _rnd.nextDouble() < 0.45 ? 2 : 1;
    }

    final firstEnrolment = prior > 0
        ? DateTime(2026 - prior, 6, 1 + _rnd.nextInt(20))
        : DateTime(2026, 6, 1 + _rnd.nextInt(n % 9 == 0 ? 100 : 40));

    final student = Student(
      id: id,
      firstName: first,
      lastName: last,
      gender: gender,
      dateOfBirth: DateTime(
        2026 - grade - 5 - _rnd.nextInt(2),
        1 + _rnd.nextInt(12),
        1 + _rnd.nextInt(28),
      ),
      parentName: '$parentFirst $last',
      parentPhone: _phone(),
      altPhone: _rnd.nextDouble() < 0.35 ? _phone() : null,
      address: _rnd.nextDouble() < 0.85
          ? 'Flat ${1 + _rnd.nextInt(40)}, '
                '${_buildings[_rnd.nextInt(_buildings.length)]}, '
                '${_areas[_rnd.nextInt(_areas.length)]}, Nashik'
          : null,
      admittedOn: firstEnrolment,
      isActive: active,
    );
    students.add(student);
    _ability[id] = 0.48 + _rnd.nextDouble() * 0.46;
    _reliability[id] = 0.8 + _rnd.nextDouble() * 0.18;

    String? previousId;
    for (var p = prior; p >= 1; p--) {
      final e = Enrollment(
        id: 'enr-${++_enr}',
        studentId: id,
        academicYearId: 'ay-${2026 - p}',
        classId: 'cls-${grade - p}',
        enrolledOn: p == prior ? firstEnrolment : DateTime(2026 - p, 6, 1),
        status: EnrollmentStatus.promoted,
        promotedFromId: previousId,
      );
      enrollments.add(e);
      _feesFor(e, grade - p, n: n);
      previousId = e.id;
    }
    final current = Enrollment(
      id: 'enr-${++_enr}',
      studentId: id,
      academicYearId: kCurrentYearId,
      classId: cls.id,
      enrolledOn: prior > 0 ? DateTime(2026, 6, 1) : firstEnrolment,
      status: active ? EnrollmentStatus.active : EnrollmentStatus.withdrawn,
      promotedFromId: previousId,
    );
    enrollments.add(current);
    _feesFor(current, grade, n: n);
  }

  // -------------------------------------------------------------------- fees

  PaymentMethod _method() {
    final r = _rnd.nextDouble();
    if (r < 0.45) return PaymentMethod.upi;
    if (r < 0.8) return PaymentMethod.cash;
    if (r < 0.92) return PaymentMethod.bankTransfer;
    return PaymentMethod.cheque;
  }

  String? _reference(PaymentMethod method) {
    String digits(int count) =>
        List.generate(count, (_) => _rnd.nextInt(10)).join();
    return switch (method) {
      PaymentMethod.upi => 'UPI ${digits(12)}',
      PaymentMethod.bankTransfer => 'NEFT ${digits(10)}',
      PaymentMethod.cheque => 'CHQ ${digits(6)}',
      PaymentMethod.card => 'CARD ${digits(6)}',
      PaymentMethod.cash => null,
    };
  }

  void _pay(String enrollmentId, int amount, DateTime date, {String? note}) {
    if (amount <= 0) return;
    final method = _method();
    payments.add(
      Payment(
        id: 'pay-${++_payCounter}',
        enrollmentId: enrollmentId,
        amount: amount,
        date: date,
        method: method,
        reference: _reference(method),
        note: note,
        recordedBy: 'Rahul Sharma',
      ),
    );
  }

  void _feesFor(Enrollment e, int grade, {required int n}) {
    final startYear = int.parse(e.academicYearId.substring(3));
    final isCurrent = e.academicYearId == kCurrentYearId;

    if (n == 1) {
      _ganeshFees(e, isCurrent);
      return;
    }

    var fee = _baseFee[grade]! - 1000 * (2026 - startYear);
    if (_rnd.nextDouble() < 0.15) {
      fee -= const [500, 1000, 1500][_rnd.nextInt(3)];
    }
    const counts = [1, 2, 3, 4, 4, 6, 6, 10, 10, 10];
    final count = counts[_rnd.nextInt(counts.length)];
    final frequency = switch (count) {
      2 => FeeFrequency.halfYearly,
      3 || 4 => FeeFrequency.quarterly,
      6 || 10 => FeeFrequency.monthly,
      _ => FeeFrequency.custom,
    };
    final yearStartDue = DateTime(startYear, 6, 10);
    final afterJoin = e.enrolledOn.add(const Duration(days: 7));
    final firstDue = afterJoin.isAfter(yearStartDue) ? afterJoin : yearStartDue;

    final plan = FeePlan(
      id: 'fee-${++_fee}',
      enrollmentId: e.id,
      annualFee: fee,
      installmentCount: count,
      frequency: frequency,
      firstDueDate: firstDue,
      note: fee < (_baseFee[grade]! - 1000 * (2026 - startYear))
          ? 'Sibling / early-admission concession'
          : null,
    );
    feePlans.add(plan);
    final schedule = plan.schedule;

    if (!isCurrent) {
      // Previous years: mostly settled, a few dues carried on that enrollment.
      final target = _rnd.nextDouble() < 0.9
          ? fee
          : fee - const [1000, 1500, 2000][_rnd.nextInt(3)];
      _payBySchedule(e, schedule, target, DateTime(startYear + 1, 4, 30));
      return;
    }

    if (e.status == EnrollmentStatus.withdrawn) {
      _payBySchedule(e, schedule, schedule.first.amount, today);
      return;
    }

    final r = _rnd.nextDouble();
    if (r < 0.32) {
      _pay(e.id, fee, e.enrolledOn, note: 'Full annual fee at admission');
    } else if (r < 0.86) {
      final dueCount = schedule.where((i) => !i.dueDate.isAfter(today)).length;
      final k = max(1, dueCount - _rnd.nextInt(3));
      var target = schedule.take(k).fold<int>(0, (s, i) => s + i.amount);
      if (_rnd.nextDouble() < 0.3) target -= 500;
      if (target >= fee) target = fee - 1000;
      _payBySchedule(e, schedule, target, today);
    }
    // else: nothing paid yet.
  }

  void _payBySchedule(
    Enrollment e,
    List<Installment> schedule,
    int target,
    DateTime latest,
  ) {
    var paid = 0;
    for (final inst in schedule) {
      if (paid >= target) break;
      var date = inst.dueDate.subtract(Duration(days: _rnd.nextInt(6)));
      if (date.isBefore(e.enrolledOn)) date = e.enrolledOn;
      if (date.isAfter(latest)) date = latest;
      final amount = min(inst.amount, target - paid);
      _pay(e.id, amount, date);
      paid += amount;
    }
    if (paid < target) _pay(e.id, target - paid, latest);
  }

  void _ganeshFees(Enrollment e, bool isCurrent) {
    if (!isCurrent) {
      final plan = FeePlan(
        id: 'fee-${++_fee}',
        enrollmentId: e.id,
        annualFee: 9000,
        installmentCount: 3,
        frequency: FeeFrequency.quarterly,
        firstDueDate: DateTime(2025, 6, 10),
      );
      feePlans.add(plan);
      for (final inst in plan.schedule) {
        payments.add(
          Payment(
            id: 'pay-${++_payCounter}',
            enrollmentId: e.id,
            amount: inst.amount,
            date: inst.dueDate,
            method: PaymentMethod.cash,
            recordedBy: 'Rahul Sharma',
          ),
        );
      }
      return;
    }
    feePlans.add(
      FeePlan(
        id: 'fee-${++_fee}',
        enrollmentId: e.id,
        annualFee: 12000,
        installmentCount: 6,
        frequency: FeeFrequency.monthly,
        firstDueDate: DateTime(2026, 6, 15),
      ),
    );
    final ganeshPayments = [
      (
        2000,
        DateTime(2026, 6, 1),
        PaymentMethod.cash,
        null,
        'Initial payment at re-enrolment',
      ),
      (
        2000,
        DateTime(2026, 7, 12),
        PaymentMethod.upi,
        'UPI 618204937215',
        null,
      ),
      (
        2000,
        DateTime(2026, 8, 14),
        PaymentMethod.upi,
        'UPI 622591048376',
        null,
      ),
      (2000, DateTime(2026, 9, 16), PaymentMethod.cash, null, null),
      (
        2000,
        today,
        PaymentMethod.upi,
        'UPI 630117254890',
        'October instalment',
      ),
    ];
    for (final p in ganeshPayments) {
      if (p.$2.isAfter(today)) continue;
      payments.add(
        Payment(
          id: 'pay-${++_payCounter}',
          enrollmentId: e.id,
          amount: p.$1,
          date: p.$2,
          method: p.$3,
          reference: p.$4,
          note: p.$5,
          recordedBy: 'Rahul Sharma',
        ),
      );
    }
  }

  // -------------------------------------------------------------- attendance

  List<Student> _activeIn(String classId, {DateTime? on}) {
    final ids = enrollments
        .where(
          (e) =>
              e.academicYearId == kCurrentYearId &&
              e.classId == classId &&
              e.status == EnrollmentStatus.active &&
              (on == null || !e.enrolledOn.isAfter(on)),
        )
        .map((e) => e.studentId)
        .toSet();
    return students.where((s) => ids.contains(s.id)).toList();
  }

  String _markerFor(String classId) => staff
      .firstWhere(
        (s) =>
            s.assignedClassIds.contains(classId) &&
            s.accountStatus == AccountStatus.active,
      )
      .name;

  AttendanceStatus _roll(String studentId) {
    final r = _rnd.nextDouble();
    final reliability = _reliability[studentId]!;
    if (r < reliability) {
      return _rnd.nextDouble() < 0.05
          ? AttendanceStatus.late
          : AttendanceStatus.present;
    }
    return _rnd.nextDouble() < 0.25
        ? AttendanceStatus.leave
        : AttendanceStatus.absent;
  }

  void _buildAttendance() {
    final running = classes.where((c) => c.isActive).toList();
    final yearStart = DateTime(2026, 6, 1);
    for (var offset = 30; offset >= 1; offset--) {
      final date = today.subtract(Duration(days: offset));
      if (date.weekday == DateTime.sunday || date.isBefore(yearStart)) continue;
      for (final cls in running) {
        final roster = _activeIn(cls.id, on: date);
        if (roster.isEmpty) continue;
        sessions.add(
          AttendanceSession(
            id: _sessionId(cls.id, date),
            classId: cls.id,
            academicYearId: kCurrentYearId,
            date: date,
            records: {for (final s in roster) s.id: _roll(s.id)},
            markedBy: _markerFor(cls.id),
            markedAt: date.add(Duration(hours: 9 + cls.grade)),
          ),
        );
      }
    }
    // Today: 4 of 6 classes marked.
    const markedToday = ['cls-8', 'cls-9', 'cls-5', 'cls-6'];
    for (var i = 0; i < markedToday.length; i++) {
      final classId = markedToday[i];
      final roster = _activeIn(classId);
      sessions.add(
        AttendanceSession(
          id: _sessionId(classId, today),
          classId: classId,
          academicYearId: kCurrentYearId,
          date: today,
          records: {
            for (final s in roster)
              s.id: s.id == 'STU-0001' ? AttendanceStatus.present : _roll(s.id),
          },
          markedBy: _markerFor(classId),
          markedAt: now.subtract(Duration(minutes: 190 - i * 45)),
        ),
      );
    }
  }

  static String _sessionId(String classId, DateTime d) =>
      'att-$classId-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  // ------------------------------------------------------------------- exams

  Map<String, MarkEntry> _marks(
    List<Student> roster,
    double maxMarks, {
    Map<String, double> fixed = const {},
    Set<String> absent = const {},
    int? limit,
  }) {
    final result = <String, MarkEntry>{};
    for (final s in limit == null ? roster : roster.take(limit)) {
      if (absent.contains(s.id)) {
        result[s.id] = MarkEntry.absentEntry;
        continue;
      }
      final value =
          fixed[s.id] ??
          (maxMarks * (_ability[s.id]! + (_rnd.nextDouble() - 0.5) * 0.18))
              .clamp(0, maxMarks)
              .roundToDouble();
      result[s.id] = MarkEntry(marks: value);
    }
    return result;
  }

  void _buildExams() {
    final lastSunday = today.subtract(
      Duration(days: today.weekday == DateTime.sunday ? 7 : today.weekday),
    );

    final c5 = _activeIn('cls-5');
    exams.add(
      Exam(
        id: 'exm-1',
        name: 'Sunday Weekly Test',
        academicYearId: kCurrentYearId,
        classId: 'cls-5',
        date: lastSunday,
        description: 'Weekly revision test covering chapters taught this week.',
        createdBy: 'Sneha Kulkarni',
        subjects: const [
          ExamSubject(subjectId: 'sub-math', maxMarks: 50),
          ExamSubject(subjectId: 'sub-sci', maxMarks: 50),
          ExamSubject(subjectId: 'sub-eng', maxMarks: 50),
        ],
        resultsPublished: true,
        publishedAt: lastSunday.add(
          const Duration(days: 1, hours: 18, minutes: 30),
        ),
        marks: {
          'sub-math': _marks(
            c5,
            50,
            fixed: {'STU-0001': 42, 'STU-0002': 36, 'STU-0003': 45},
          ),
          'sub-sci': _marks(c5, 50, fixed: {'STU-0001': 44}),
          'sub-eng': _marks(
            c5,
            50,
            fixed: {'STU-0001': 40},
            absent: {c5[7].id},
          ),
        },
      ),
    );

    final c8 = _activeIn('cls-8');
    exams.add(
      Exam(
        id: 'exm-2',
        name: 'Unit Test 2',
        academicYearId: kCurrentYearId,
        classId: 'cls-8',
        date: today.subtract(const Duration(days: 5)),
        description: 'Linear equations and mensuration.',
        createdBy: 'Amit Deshmukh',
        subjects: const [ExamSubject(subjectId: 'sub-math', maxMarks: 25)],
        marks: {
          'sub-math': _marks(c8, 25, limit: 12, absent: {c8[3].id}),
        },
      ),
    );

    exams.add(
      Exam(
        id: 'exm-3',
        name: 'Mid-term Examination',
        academicYearId: kCurrentYearId,
        classId: 'cls-10',
        date: today.add(const Duration(days: 6)),
        description: 'Board-pattern mid-term paper. Bring geometry box.',
        createdBy: 'Rahul Sharma',
        subjects: const [
          ExamSubject(subjectId: 'sub-math', maxMarks: 80),
          ExamSubject(subjectId: 'sub-sci', maxMarks: 80),
          ExamSubject(subjectId: 'sub-eng', maxMarks: 80),
          ExamSubject(subjectId: 'sub-ss', maxMarks: 80),
        ],
      ),
    );

    exams.add(
      Exam(
        id: 'exm-4',
        name: 'Chapter Test: Algebra',
        academicYearId: kCurrentYearId,
        classId: 'cls-9',
        date: today.add(const Duration(days: 3)),
        createdBy: 'Amit Deshmukh',
        subjects: const [ExamSubject(subjectId: 'sub-math', maxMarks: 40)],
      ),
    );

    exams.add(
      Exam(
        id: 'exm-5',
        name: 'Grammar Quiz',
        academicYearId: kCurrentYearId,
        classId: 'cls-6',
        date: today.add(const Duration(days: 10)),
        description: 'Tenses and reported speech.',
        createdBy: 'Pooja Joshi',
        isDraft: true,
        subjects: const [ExamSubject(subjectId: 'sub-eng', maxMarks: 20)],
      ),
    );

    final c7 = _activeIn('cls-7');
    final sept = DateTime(2026, 9, 27);
    exams.add(
      Exam(
        id: 'exm-6',
        name: 'Monthly Test — September',
        academicYearId: kCurrentYearId,
        classId: 'cls-7',
        date: sept,
        createdBy: 'Sneha Kulkarni',
        subjects: const [
          ExamSubject(subjectId: 'sub-math', maxMarks: 100),
          ExamSubject(subjectId: 'sub-sci', maxMarks: 100),
        ],
        resultsPublished: true,
        publishedAt: sept.add(const Duration(days: 3, hours: 19)),
        marks: {
          'sub-math': _marks(c7, 100),
          'sub-sci': _marks(c7, 100, absent: {c7[11].id}),
        },
      ),
    );

    final c9 = _activeIn('cls-9');
    exams.add(
      Exam(
        id: 'exm-7',
        name: 'Mathematics Weekly Quiz',
        academicYearId: kCurrentYearId,
        classId: 'cls-9',
        date: today.subtract(const Duration(days: 2)),
        createdBy: 'Amit Deshmukh',
        subjects: const [ExamSubject(subjectId: 'sub-math', maxMarks: 30)],
        resultsPublished: true,
        publishedAt: now.subtract(const Duration(minutes: 140)),
        marks: {'sub-math': _marks(c9, 30)},
      ),
    );
  }

  // ---------------------------------------------------------------- messages

  DeliveryStatus _seedStatus(
    int i, {
    Set<int> failed = const {},
    Set<int> pending = const {},
  }) {
    if (failed.contains(i)) return DeliveryStatus.failed;
    if (pending.contains(i)) return DeliveryStatus.queued;
    return i % 3 == 2 ? DeliveryStatus.sent : DeliveryStatus.delivered;
  }

  StudentResult _resultFor(Exam exam, String studentId) => StudentResult(
    studentId: studentId,
    exam: exam,
    subjects: [
      for (final s in exam.subjects)
        SubjectResult(
          subject: subjects.firstWhere((x) => x.id == s.subjectId),
          maxMarks: s.maxMarks,
          entry: exam.markFor(s.subjectId, studentId),
        ),
    ],
  );

  void _buildBatches() {
    // 1. Exam results, Sunday Weekly Test (Class 5) — one failure to retry.
    final e1 = exams.first;
    final c5 = _activeIn('cls-5');
    final e1Recipients = <MessageRecipient>[];
    for (var i = 0; i < c5.length; i++) {
      final s = c5[i];
      final status = _seedStatus(i, failed: {9});
      e1Recipients.add(
        MessageRecipient(
          id: 'rcp-1-$i',
          studentId: s.id,
          studentName: s.fullName,
          parentName: s.parentName,
          phone: s.parentPhone,
          body: MessageTemplates.examResult(
            examName: e1.name,
            student: s.fullName,
            result: _resultFor(e1, s.id),
            tuition: tuition.name,
          ),
          status: status,
          attempts: 1,
          failureReason: status == DeliveryStatus.failed
              ? 'Number unreachable'
              : null,
          updatedAt: e1.publishedAt!.add(const Duration(minutes: 12)),
        ),
      );
    }
    batches.add(
      MessageBatch(
        id: 'bat-1',
        sourceKey: 'exam:${e1.id}:r0',
        title: '${e1.name} results',
        category: MessageCategory.examResults,
        classIds: const ['cls-5'],
        createdBy: 'Sneha Kulkarni',
        createdAt: e1.publishedAt!.add(const Duration(minutes: 10)),
        previewBody: e1Recipients.first.body,
        recipients: e1Recipients,
      ),
    );

    // 2. Today's attendance alerts for Class 8 — two failures.
    final s8 = sessions.firstWhere((s) => s.id == _sessionId('cls-8', today));
    final c8 = _activeIn('cls-8');
    final attRecipients = <MessageRecipient>[];
    for (var i = 0; i < c8.length; i++) {
      final s = c8[i];
      final status = _seedStatus(i, failed: {4, 13});
      attRecipients.add(
        MessageRecipient(
          id: 'rcp-2-$i',
          studentId: s.id,
          studentName: s.fullName,
          parentName: s.parentName,
          phone: s.parentPhone,
          body: MessageTemplates.attendance(
            s8.records[s.id] ?? AttendanceStatus.present,
            s.fullName,
            tuition.name,
          ),
          status: status,
          attempts: 1,
          failureReason: status == DeliveryStatus.failed
              ? 'Device reported send failure'
              : null,
          updatedAt: s8.markedAt.add(const Duration(minutes: 4)),
        ),
      );
    }
    batches.add(
      MessageBatch(
        id: 'bat-2',
        sourceKey: 'attendance:${s8.id}',
        title: 'Class 8 attendance · ${today.day}/${today.month}',
        category: MessageCategory.attendance,
        classIds: const ['cls-8'],
        createdBy: 'Amit Deshmukh',
        createdAt: s8.markedAt.add(const Duration(minutes: 3)),
        previewBody: MessageTemplates.attendance(
          AttendanceStatus.absent,
          '[Student Name]',
          tuition.name,
        ),
        recipients: attRecipients,
      ),
    );

    // 3. Announcement to all parents.
    const annTitle = 'Diwali holidays';
    const annBody =
        'Classes will remain closed from 7 to 10 November for Diwali. '
        'Regular batches resume on Wednesday, 11 November. Wishing your family a happy Diwali!';
    final allActive = students.where((s) => s.isActive).toList();
    final annAt = now.subtract(const Duration(days: 2, hours: 3));
    batches.add(
      MessageBatch(
        id: 'bat-3',
        sourceKey: 'announcement:ann-1',
        title: annTitle,
        category: MessageCategory.announcement,
        classIds: classes.where((c) => c.isActive).map((c) => c.id).toList(),
        createdBy: 'Rahul Sharma',
        createdAt: annAt,
        previewBody: MessageTemplates.announcement(
          annTitle,
          annBody,
          tuition.name,
        ),
        recipients: [
          for (var i = 0; i < allActive.length; i++)
            MessageRecipient(
              id: 'rcp-3-$i',
              studentId: allActive[i].id,
              studentName: allActive[i].fullName,
              parentName: allActive[i].parentName,
              phone: allActive[i].parentPhone,
              body: MessageTemplates.announcement(
                annTitle,
                annBody,
                tuition.name,
              ),
              status: _seedStatus(i),
              attempts: 1,
              updatedAt: annAt.add(const Duration(minutes: 20)),
            ),
        ],
      ),
    );

    // 4. Fee reminder (admin only) — failures and pending items.
    final remindAt = DateTime(today.year, today.month, today.day - 1, 19, 10);
    final due = <(Student, int)>[];
    for (final s in allActive) {
      final enr = enrollments.firstWhere(
        (e) => e.studentId == s.id && e.academicYearId == kCurrentYearId,
      );
      final plan = feePlans.firstWhere((p) => p.enrollmentId == enr.id);
      final paid = payments
          .where((p) => p.enrollmentId == enr.id)
          .fold<int>(0, (sum, p) => sum + p.amount);
      final dueSoFar = plan.schedule
          .where((i) => i.dueDate.isBefore(today))
          .fold<int>(0, (sum, i) => sum + i.amount);
      if (dueSoFar - paid > 0) due.add((s, dueSoFar - paid));
      if (due.length == 14) break;
    }
    batches.add(
      MessageBatch(
        id: 'bat-4',
        sourceKey: 'fees:reminder-oct',
        title: 'Fee reminder · ${today.month == 10 ? 'October' : 'This month'}',
        category: MessageCategory.feeReminder,
        classIds: classes.where((c) => c.isActive).map((c) => c.id).toList(),
        createdBy: 'Rahul Sharma',
        createdAt: remindAt,
        previewBody: MessageTemplates.feeReminder(
          '[Student Name]',
          2000,
          tuition.name,
        ),
        recipients: [
          for (var i = 0; i < due.length; i++)
            MessageRecipient(
              id: 'rcp-4-$i',
              studentId: due[i].$1.id,
              studentName: due[i].$1.fullName,
              parentName: due[i].$1.parentName,
              phone: due[i].$1.parentPhone,
              body: MessageTemplates.feeReminder(
                due[i].$1.fullName,
                due[i].$2,
                tuition.name,
              ),
              status: _seedStatus(i, failed: {2, 8}, pending: {11, 12, 13}),
              attempts: i >= 11 ? 0 : 1,
              failureReason: i == 2 || i == 8 ? 'SIM not available' : null,
              updatedAt: remindAt.add(const Duration(minutes: 6)),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- notifications etc

  List<AppNotification> _notifications() {
    final newest = students
        .where((s) => s.isActive)
        .reduce((a, b) => a.admittedOn.isAfter(b.admittedOn) ? a : b);
    return [
      AppNotification(
        id: 'ntf-1',
        type: NotificationType.messageFailed,
        title: '2 attendance alerts failed',
        body: 'Class 8 · Retry the failed messages from the batch details.',
        createdAt: now.subtract(const Duration(minutes: 38)),
      ),
      AppNotification(
        id: 'ntf-2',
        type: NotificationType.attendance,
        title: 'Attendance marked for Class 6',
        body: 'Sneha Kulkarni saved attendance for today\'s session.',
        createdAt: now.subtract(const Duration(minutes: 55)),
      ),
      AppNotification(
        id: 'ntf-3',
        type: NotificationType.payment,
        title: 'Payment recorded · ₹2,000',
        body: 'Received from parent of Ganesh Pawar (Class 5).',
        createdAt: now.subtract(const Duration(minutes: 80)),
        adminOnly: true,
      ),
      AppNotification(
        id: 'ntf-4',
        type: NotificationType.exam,
        title: 'Results published: Mathematics Weekly Quiz',
        body: 'Class 9 results are ready to share with parents.',
        createdAt: now.subtract(const Duration(minutes: 140)),
      ),
      AppNotification(
        id: 'ntf-5',
        type: NotificationType.staff,
        title: 'Invitation pending for Neha Gaikwad',
        body: 'Account setup is waiting for the staff member to accept.',
        createdAt: now.subtract(const Duration(hours: 4)),
        adminOnly: true,
      ),
      AppNotification(
        id: 'ntf-6',
        type: NotificationType.messageFailed,
        title: 'Fee reminders waiting to send',
        body:
            '3 messages are pending and 2 failed in yesterday\'s reminder batch.',
        createdAt: now.subtract(const Duration(hours: 20)),
        adminOnly: true,
        isRead: true,
      ),
      AppNotification(
        id: 'ntf-7',
        type: NotificationType.student,
        title: 'New admission: ${newest.fullName}',
        body: 'Enrolled for 2026–27.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      AppNotification(
        id: 'ntf-8',
        type: NotificationType.exam,
        title: 'Sunday Weekly Test results sent',
        body: 'Class 5 · 21 of 22 parents notified.',
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }

  List<ActivityEvent> _activity() => [
    ActivityEvent(
      type: ActivityType.attendance,
      title: 'Attendance marked for Class 5',
      subtitle: 'Sneha Kulkarni · ${_activeIn('cls-5').length} students',
      at: now.subtract(const Duration(minutes: 55)),
    ),
    ActivityEvent(
      type: ActivityType.payment,
      title: 'Payment recorded · ₹2,000',
      subtitle: 'Ganesh Pawar · UPI',
      at: now.subtract(const Duration(minutes: 80)),
      adminOnly: true,
    ),
    ActivityEvent(
      type: ActivityType.exam,
      title: 'Mathematics results published',
      subtitle: 'Mathematics Weekly Quiz · Class 9',
      at: now.subtract(const Duration(minutes: 140)),
    ),
    ActivityEvent(
      type: ActivityType.staff,
      title: 'Staff member added',
      subtitle: 'Neha Gaikwad · Front desk coordinator',
      at: now.subtract(const Duration(hours: 4)),
      adminOnly: true,
    ),
  ];
}
