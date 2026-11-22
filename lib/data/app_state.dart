import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'models.dart';

/// Client-side cache of the signed-in institute's data, backed by the Kaksha
/// API. Screens read the cached lists synchronously; every change goes to the
/// server first and updates the cache when it succeeds (errors are thrown as
/// [ApiException] for the screen to show).
class AppState extends ChangeNotifier {
  AppState._() {
    api.onUnauthorized = _expireSession;
    api.onAccessDenied = _denyAccess;
    api.onAccountBlocked = _expireSession;
  }
  static final AppState instance = AppState._();

  static const _tokenKey = 'auth_token';

  // ---- Session -----------------------------------------------------------
  String? userName;
  String? userEmail;
  String role = 'owner';
  bool canAccessFees = true;
  int trialDaysRemaining = 0;
  String instituteName = '';
  String institutePhone = '';
  String instituteAddress = '';
  DateTime? logoUpdatedAt;

  /// Institute setting: students can have a monthly fee.
  bool monthlyFees = false;

  // Access of the whole institute (trial / allowed from the admin page / blocked).
  String accessStatus = 'trial';
  bool accessAllowed = true;
  DateTime? accessUntil;
  String accessMessage = '';
  String supportPhone = '';
  String supportEmail = '';

  bool get isLoggedIn => api.token != null && userEmail != null;
  bool get isOwner => role == 'owner';

  /// Called when the server ends the session (token expired, password reset,
  /// login blocked); the app shows the login screen.
  VoidCallback? onSessionExpired;

  /// Called when the institute's trial/plan has ended or it was blocked; the
  /// app shows the access screen.
  VoidCallback? onAccessDenied;

  /// Restores the saved login on app start. Returns false if there is none
  /// or it is no longer valid; throws [ApiException] if the server can't be
  /// reached. Check [accessAllowed] afterwards.
  Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return false;
    api.token = token;
    try {
      final me = await api.get('/auth/me');
      _applySession(me);
      if (accessAllowed) await loadAll();
      return true;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await _clearSession();
        return false;
      }
      rethrow;
    }
  }

  /// Owner signup: creates the account and emails a verification code.
  Future<void> register({
    required String name,
    required String email,
    required String mobile,
    required String password,
    String referralCode = '',
  }) => api.post('/auth/register', {
    'name': name,
    'email': email,
    'mobile': mobile,
    'password': password,
    if (referralCode.isNotEmpty) 'referralCode': referralCode,
  });

  Future<void> verifyEmail(String email, String code) async => _startSession(
    await api.post('/auth/verify-email', {'email': email, 'code': code}),
  );

  Future<void> login(String identifier, String password) async => _startSession(
    await api.post('/auth/login', {
      'identifier': identifier,
      'password': password,
    }),
  );

  /// [purpose] is 'signup' or 'reset'.
  Future<void> resendOtp(String email, String purpose) =>
      api.post('/auth/resend-otp', {'email': email, 'purpose': purpose});

  Future<void> forgotPassword(String email) =>
      api.post('/auth/forgot-password', {'email': email});

  /// Returns the reset token for [resetPassword].
  Future<String> verifyResetOtp(String email, String code) async {
    final res = await api.post('/auth/verify-reset-otp', {
      'email': email,
      'code': code,
    });
    return res['resetToken'] as String;
  }

  Future<void> resetPassword(String resetToken, String password) => api.post(
    '/auth/reset-password',
    {'resetToken': resetToken, 'password': password},
  );

  Future<void> logout() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _startSession(dynamic res) async {
    api.token = res['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
    _applySession(res);
    if (accessAllowed) await loadAll();
  }

  void _applySession(dynamic res) {
    final user = res['user'] as Map<String, dynamic>;
    final inst = res['institute'] as Map<String, dynamic>?;
    userName = user['name'] as String?;
    userEmail = user['email'] as String?;
    role = user['role'] as String? ?? 'owner';
    canAccessFees = user['canAccessFees'] as bool? ?? false;
    if (inst != null) _applyInstitute(inst);
  }

  void _applyInstitute(Map<String, dynamic> inst) {
    instituteName = inst['name'] as String? ?? '';
    institutePhone = inst['phone'] as String? ?? '';
    instituteAddress = inst['address'] as String? ?? '';
    logoUpdatedAt = parseDate(inst['logoUpdatedAt']);
    monthlyFees = inst['monthlyFees'] as bool? ?? false;
    trialDaysRemaining = (inst['trialDaysRemaining'] as num?)?.toInt() ?? 0;
    final access = inst['access'] as Map<String, dynamic>? ?? const {};
    accessStatus = access['status'] as String? ?? 'trial';
    accessAllowed = access['allowed'] as bool? ?? true;
    accessUntil = parseDate(access['accessUntil']);
    accessMessage = access['message'] as String? ?? '';
    final support = inst['support'] as Map<String, dynamic>? ?? const {};
    supportPhone = support['phone'] as String? ?? '';
    supportEmail = support['email'] as String? ?? '';
  }

  /// Asks the server again (e.g. after the admin allowed this tuition).
  /// Loads everything when access is allowed.
  Future<void> recheckAccess() async {
    _applySession(await api.get('/auth/me'));
    if (accessAllowed) await loadAll();
    notifyListeners();
  }

  void _denyAccess(String code, String message) {
    if (!isLoggedIn) return;
    final wasAllowed = accessAllowed;
    accessAllowed = false;
    accessMessage = message;
    // Exact status for the access screen (blocked / plan ended / trial ended).
    if (code == 'ACCESS_BLOCKED') accessStatus = 'blocked';
    notifyListeners();
    if (wasAllowed) onAccessDenied?.call();
  }

  void _denyAccessFromStatus() {
    final message = accessMessage;
    accessAllowed = true; // so _denyAccess sees the change and navigates
    _denyAccess(
      accessStatus == 'blocked' ? 'ACCESS_BLOCKED' : 'ACCESS_EXPIRED',
      message,
    );
  }

  // ---- My profile ----------------------------------------------------------
  /// [instituteName] only for the owner.
  /// Institute fields are for the admin only.
  Future<void> updateProfile({
    String? name,
    String? instituteName,
    String? institutePhone,
    String? instituteAddress,
    bool? monthlyFees,
  }) async {
    final res = await api.patch('/account', {
      'name': ?name,
      'instituteName': ?instituteName,
      'institutePhone': ?institutePhone,
      'instituteAddress': ?instituteAddress,
      'monthlyFees': ?monthlyFees,
    });
    _applySession(res);
    notifyListeners();
  }

  /// Changes the password; other devices are signed out, this one stays in.
  Future<void> changePassword(String current, String next) async {
    final res = await api.post('/account/password', {
      'currentPassword': current,
      'newPassword': next,
    });
    api.token = res['token'] as String;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, api.token!);
  }

  // ---- Institute logo (receipts) --------------------------------------------
  /// Logo address (changes when the logo changes), or null without a logo.
  String? get logoUrl => logoUpdatedAt == null
      ? null
      : '$apiBaseUrl/account/logo?v=${logoUpdatedAt!.millisecondsSinceEpoch}';

  /// Admin only. [bytes]: an already-shrunk JPEG/PNG.
  Future<void> uploadLogo(List<int> bytes) async {
    _applyInstitute(
      (await api.put('/account/logo', {
        'image': base64Encode(bytes),
      }))['institute'],
    );
    _logoBytes = null;
    notifyListeners();
  }

  Future<void> removeLogo() async {
    _applyInstitute((await api.delete('/account/logo'))['institute']);
    _logoBytes = null;
    notifyListeners();
  }

  ({DateTime? version, List<int> bytes})? _logoBytes;

  /// The logo's bytes for PDF receipts (cached), or null without a logo.
  Future<List<int>?> logoBytes() async {
    final url = logoUrl;
    if (url == null) return null;
    if (_logoBytes case final c? when c.version == logoUpdatedAt) {
      return c.bytes;
    }
    try {
      final res = await api.client
          .get(Uri.parse(url), headers: authHeaders)
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return null;
      _logoBytes = (version: logoUpdatedAt, bytes: res.bodyBytes);
      return res.bodyBytes;
    } catch (_) {
      return null; // receipt without logo
    }
  }

  /// Copies students' details (not fees/attendance/marks) into [to].
  /// Returns how many were copied and who was skipped (roll number taken).
  Future<({int copied, List<String> skipped})> copyStudents(
    String fromClassId,
    String to,
    List<String> studentIds,
  ) async {
    final res = await api.post('/classes/$fromClassId/students/copy', {
      'to': to,
      'students': studentIds,
    });
    await loadAll();
    return (
      copied: (res['copied'] as num).toInt(),
      skipped: [for (final n in res['skipped'] as List) n as String],
    );
  }

  /// Owner only: deletes the institute with all its data, then signs out.
  Future<void> deleteAccount(String password) async {
    await api.deleteWithBody('/account', {'password': password});
    await logout();
  }

  Future<void> _clearSession() async {
    api.token = null;
    userName = null;
    userEmail = null;
    classes.clear();
    students.clear();
    tests.clear();
    users.clear();
    smsBatches.clear();
    presentToday = 0;
    accessAllowed = true;
    accessMessage = '';
    _invalidateAttendance();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Why the last session ended (shown on the login screen), if known.
  String? sessionEndMessage;

  void _expireSession([String? message]) {
    if (!isLoggedIn) return;
    sessionEndMessage = message;
    _clearSession().then((_) {
      notifyListeners();
      onSessionExpired?.call();
    });
  }

  // ---- Loading -------------------------------------------------------------
  bool loading = false;

  /// Reloads everything the screens show (classes, students, tests, staff,
  /// dashboard). Called after sign-in and on pull-to-refresh.
  Future<void> loadAll() async {
    loading = true;
    notifyListeners();
    try {
      // Fresh role, fee access and plan (the admin may have changed them).
      _applySession(await api.get('/auth/me'));
      if (!accessAllowed) {
        _denyAccessFromStatus();
        return;
      }
      final res = await api.get('/classes');
      final loaded = [
        for (final c in res['classes'] as List) SchoolClass.fromJson(c),
      ];
      final perClass = await Future.wait(
        loaded.map(
          (c) => Future.wait([
            api.get('/classes/${c.id}/students'),
            api.get('/classes/${c.id}/tests'),
          ]),
        ),
      );
      final usersRes = isOwner ? await api.get('/users') : null;

      classes
        ..clear()
        ..addAll(loaded);
      students.clear();
      tests.clear();
      for (final r in perClass) {
        students.addAll([
          for (final s in r[0]['students'] as List) Student.fromJson(s),
        ]);
        // API sends newest first; screens expect oldest first.
        tests.addAll([
          for (final t in (r[1]['tests'] as List).reversed)
            ClassTest.fromJson(t),
        ]);
      }
      users.clear();
      if (usersRes != null) {
        users.addAll([
          for (final u in usersRes['users'] as List) StaffUser.fromJson(u),
        ]);
      }
      _invalidateAttendance();
      await Future.wait([refreshDashboard(), refreshSmsBatches()]);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Present-today count and trial days from the server.
  Future<void> refreshDashboard() async {
    final d = await api.get('/dashboard', {'date': dateKey(DateTime.now())});
    presentToday = (d['presentToday'] as num).toInt();
    trialDaysRemaining = (d['trialDaysRemaining'] as num).toInt();
    notifyListeners();
  }

  // ---- Classes -----------------------------------------------------------
  final List<SchoolClass> classes = [];

  Future<SchoolClass> addClass(String name) async {
    final res = await api.post('/classes', {'name': name});
    final c = SchoolClass.fromJson(res['class']);
    classes.add(c);
    notifyListeners();
    return c;
  }

  /// Imports a whole class file (see utils/import_csv.dart); returns counts
  /// {students, skipped, payments, attendanceDays, tests}.
  Future<Map<String, dynamic>> importClass(
    String classId,
    Map<String, dynamic> body,
  ) async {
    final res = await api.post('/classes/$classId/import', body);
    return Map<String, dynamic>.from(res['imported'] as Map);
  }

  Future<void> renameClass(SchoolClass c, String name) async {
    await api.patch('/classes/${c.id}', {'name': name});
    c.name = name;
    notifyListeners();
  }

  void sortClassesByName() {
    classes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    notifyListeners();
  }

  Future<void> deleteClass(SchoolClass c) async {
    await api.delete('/classes/${c.id}');
    classes.remove(c);
    students.removeWhere((s) => s.classId == c.id);
    tests.removeWhere((t) => t.classId == c.id);
    _invalidateAttendance();
    notifyListeners();
    refreshDashboard().ignore();
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

  /// Body for creating/updating a student. Fee fields are sent only with fee
  /// access (the server rejects them otherwise).
  Map<String, dynamic> studentBody({
    required String name,
    required String fatherName,
    required String contact,
    required String parentMobile,
    required String rollNo,
    required String email,
    required DateTime? dateOfBirth,
    required double totalFees,
    required DateTime? feesDueDate,
    double monthlyFee = 0,
    String? feeStart,
  }) => {
    'name': name,
    'fatherName': fatherName,
    'contact': contact,
    'parentMobile': parentMobile,
    'rollNo': rollNo,
    'email': email,
    'dateOfBirth': dateOfBirth == null ? null : dateKey(dateOfBirth),
    if (canAccessFees) ...{
      'totalFees': totalFees,
      'feesDueDate': feesDueDate == null ? null : dateKey(feesDueDate),
      if (monthlyFees) ...{
        'monthlyFee': monthlyFee,
        'feeStart': monthlyFee > 0 ? feeStart : null,
      },
    },
  };

  Future<Student> addStudent(String classId, Map<String, dynamic> body) async {
    final res = await api.post('/classes/$classId/students', body);
    final s = Student.fromJson(res['student']);
    students.add(s);
    _invalidateAttendance();
    notifyListeners();
    return s;
  }

  Future<void> updateStudent(Student s, Map<String, dynamic> body) async {
    final res = await api.patch('/students/${s.id}', body);
    _assignStudent(s, res['student']);
    notifyListeners();
  }

  Future<void> toggleStudentDisabled(Student s) async {
    final res = await api.patch('/students/${s.id}', {'disabled': !s.disabled});
    _assignStudent(s, res['student']);
    _invalidateAttendance();
    notifyListeners();
  }

  Future<void> deleteStudent(Student s) async {
    await api.delete('/students/${s.id}');
    students.remove(s);
    for (final t in tests) {
      t.marks.remove(s.id);
    }
    _invalidateAttendance();
    notifyListeners();
  }

  /// Payment that got no reply (network), per student: retrying the same
  /// amount sends the same id, so the server does not save it twice.
  final Map<String, ({String ref, double amount})> _unconfirmedPayments = {};
  var _refSeq = 0;

  /// Records a payment; returns it (with its receipt number) for the receipt.
  Future<FeePayment> collectFee(Student s, double amount) async {
    final last = _unconfirmedPayments[s.id];
    final ref = last != null && last.amount == amount
        ? last.ref
        : 'p${DateTime.now().microsecondsSinceEpoch}-${_refSeq++}';
    _unconfirmedPayments[s.id] = (ref: ref, amount: amount);
    try {
      final res = await api.post('/students/${s.id}/fees/payments', {
        'amount': amount,
        'clientRef': ref,
      });
      _unconfirmedPayments.remove(s.id);
      _assignStudent(s, res['student']);
      notifyListeners();
      final p = res['payment'] as Map<String, dynamic>;
      return FeePayment(
        id: p['id'] as String,
        amount: (p['amount'] as num).toDouble(),
        paidAt: parseDate(p['paidAt']) ?? DateTime.now(),
        note: p['note'] as String? ?? '',
        collectedBy: userName ?? '',
        receiptNo: (p['receiptNo'] as num?)?.toInt(),
      );
    } on ApiException catch (e) {
      // A real answer from the server (e.g. "exceeds due") means it was not saved.
      if (e.status != 0) _unconfirmedPayments.remove(s.id);
      rethrow;
    }
  }

  /// Admin only: deletes a wrong payment and lowers the paid amount.
  Future<void> deletePayment(Student s, FeePayment p) async {
    final res = await api.delete('/students/${s.id}/fees/payments/${p.id}');
    _assignStudent(s, res['student']);
    notifyListeners();
  }

  // ---- Parent SMS queue ------------------------------------------------------
  /// SMS lists of the last 7 days (newest first).
  final List<SmsBatch> smsBatches = [];

  /// Unsent parent SMS any phone can still send.
  int get pendingSms => smsBatches.fold(0, (n, b) => n + b.remaining);

  Future<void> refreshSmsBatches() async {
    final res = await api.get('/sms/batches');
    smsBatches
      ..clear()
      ..addAll([for (final b in res['batches'] as List) SmsBatch.fromJson(b)]);
    notifyListeners();
  }

  /// Saves a "send to all" list; returns the batch id and ALL its messages
  /// (with [key], a list saved earlier is reused and students already in it
  /// are not added again — their messages come back with their status).
  Future<(String, List<SmsMessage>)> createSmsBatch({
    required String kind,
    required String title,
    String? classId,
    String? key,
    required List<Map<String, dynamic>> messages,
  }) async {
    final res = await api.post('/sms/batches', {
      'kind': kind,
      'title': title,
      'classId': ?classId,
      'key': ?key,
      'messages': messages,
    });
    return (
      res['batch'] as String,
      [for (final m in res['messages'] as List) SmsMessage.fromJson(m)],
    );
  }

  /// Reserves unsent messages for this phone (10 minutes).
  Future<List<SmsMessage>> claimSms({
    String? batch,
    List<String>? ids,
    required int limit,
  }) async {
    final res = await api.post('/sms/claim', {
      'batch': ?batch,
      'ids': ?ids,
      'limit': limit,
    });
    return [for (final m in res['messages'] as List) SmsMessage.fromJson(m)];
  }

  /// [channel]: sms (from SIM), whatsapp, sms_app (phone's SMS app).
  /// `stop`: the list was stopped from Pending SMS — send no more of it.
  Future<({bool stop})> reportSms(
    String id, {
    required bool sent,
    String? reason,
    String channel = 'sms',
  }) async {
    final res = await api.post('/sms/$id/report', {
      'status': sent ? 'sent' : 'failed',
      'reason': ?reason,
      'channel': channel,
    });
    return (stop: res is Map && res['stop'] == true);
  }

  Future<void> releaseSms(List<String> ids) async {
    if (ids.isNotEmpty) await api.post('/sms/release', {'ids': ids});
  }

  Future<List<SmsMessage>> loadSmsBatch(String id) async {
    final res = await api.get('/sms/batches/$id');
    return [for (final m in res['messages'] as List) SmsMessage.fromJson(m)];
  }

  Future<void> dismissSmsBatch(String id) async {
    await api.post('/sms/batches/$id/dismiss');
    await refreshSmsBatches();
  }

  // ---- Student photos & payments -------------------------------------------
  /// Photo address (changes when the photo changes), or null without photo.
  String? photoUrl(Student s) => s.photoUpdatedAt == null
      ? null
      : '$apiBaseUrl/students/${s.id}/photo?v=${s.photoUpdatedAt!.millisecondsSinceEpoch}';

  Map<String, String> get authHeaders => {
    if (api.token != null) 'Authorization': 'Bearer ${api.token}',
  };

  /// [jpegBytes]: an already-shrunk photo (the picker resizes it).
  Future<void> uploadStudentPhoto(Student s, List<int> jpegBytes) async {
    final res = await api.put('/students/${s.id}/photo', {
      'image': base64Encode(jpegBytes),
    });
    _assignStudent(s, res['student']);
    notifyListeners();
  }

  Future<void> removeStudentPhoto(Student s) async {
    final res = await api.delete('/students/${s.id}/photo');
    _assignStudent(s, res['student']);
    notifyListeners();
  }

  /// Fee payments of a student, newest first.
  Future<List<FeePayment>> loadPayments(Student s) async {
    final res = await api.get('/students/${s.id}/fees/payments');
    return [for (final p in res['payments'] as List) FeePayment.fromJson(p)];
  }

  /// Active students whose birthday is today.
  List<Student> get birthdaysToday {
    final now = DateTime.now();
    return students
        .where(
          (s) =>
              !s.disabled &&
              s.dateOfBirth != null &&
              s.dateOfBirth!.month == now.month &&
              s.dateOfBirth!.day == now.day,
        )
        .toList();
  }

  /// Copies server values into the existing object so screens holding it
  /// see the change.
  void _assignStudent(Student s, Map<String, dynamic> json) {
    final f = Student.fromJson(json);
    s
      ..name = f.name
      ..fatherName = f.fatherName
      ..contact = f.contact
      ..parentMobile = f.parentMobile
      ..rollNo = f.rollNo
      ..email = f.email
      ..dateOfBirth = f.dateOfBirth
      ..disabled = f.disabled
      ..photoUpdatedAt = f.photoUpdatedAt;
    if (json.containsKey('totalFees')) {
      s
        ..totalFees = f.totalFees
        ..oneTimeFees = f.oneTimeFees
        ..monthlyFee = f.monthlyFee
        ..feeStart = f.feeStart
        ..monthsBilled = f.monthsBilled
        ..feesPaid = f.feesPaid
        ..feesDueDate = f.feesDueDate;
    }
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
  int presentToday = 0;

  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static AttendanceStatus _status(Object? v) => AttendanceStatus.values
      .firstWhere((s) => s.name == v, orElse: () => AttendanceStatus.present);

  /// Saved attendance of a class for [date], or null if not saved yet.
  AttendanceDay _attendanceDay(dynamic res) {
    final records = (res['records'] as List).cast<Map<String, dynamic>>();
    return AttendanceDay(
      saved: res['saved'] == true,
      version: (res['version'] as num?)?.toInt(),
      savedBy: res['savedBy'] as String?,
      savedAt: parseDate(res['savedAt']),
      marks: {
        for (final r in records) r['student'] as String: _status(r['status']),
      },
      savedMarks: {
        for (final r in records)
          if (r['saved'] == true) r['student'] as String,
      },
      sms: {
        for (final r in records)
          if (r['sms'] case final String s) r['student'] as String: s,
      },
      notes: {
        for (final r in records)
          if (r['note'] case final String n when n.isNotEmpty)
            r['student'] as String: n,
      },
      changes: [
        for (final c in (res['changes'] as List? ?? const []))
          AttendanceChange(
            studentName: c['name'] as String,
            from: _status(c['from']),
            to: _status(c['to']),
            by: c['by'] as String? ?? '',
            at: parseDate(c['at']) ?? DateTime.now(),
          ),
      ],
    );
  }

  /// Saved attendance of a class for [date] (with who saved it, its version,
  /// absence-SMS status per student and later changes).
  Future<AttendanceDay> loadAttendance(String classId, DateTime date) async =>
      _attendanceDay(
        await api.get('/classes/$classId/attendance', {'date': dateKey(date)}),
      );

  /// Saves the marks. [version] is the one the screen was loaded with; the
  /// server answers 409 ATTENDANCE_CHANGED if someone saved in between.
  Future<AttendanceDay> saveAttendance(
    String classId,
    DateTime date,
    Map<String, AttendanceStatus> marks, {
    required int? version,
    Map<String, String> notes = const {},
  }) async {
    final res = await api.put('/classes/$classId/attendance', {
      'date': dateKey(date),
      'version': version,
      'records': [
        for (final e in marks.entries)
          {
            'student': e.key,
            'status': e.value.name,
            if (e.value == AttendanceStatus.others) 'note': notes[e.key] ?? '',
          },
      ],
    });
    _invalidateAttendance();
    notifyListeners();
    refreshDashboard().ignore();
    return _attendanceDay(res);
  }

  /// The absence-SMS list of a class and date, built by the server from the
  /// SAVED attendance: one message per absent student per day (asking again
  /// adds only newly absent students).
  Future<
    ({
      String batch,
      String title,
      List<SmsMessage> messages,
      List<String> noNumber,
    })
  >
  absentSmsList(String classId, DateTime date) async {
    final res = await api.post('/classes/$classId/attendance/sms', {
      'date': dateKey(date),
    });
    return (
      batch: res['batch'] as String,
      title: res['title'] as String,
      messages: [
        for (final m in res['messages'] as List) SmsMessage.fromJson(m),
      ],
      noNumber: [for (final n in res['noNumber'] as List) n as String],
    );
  }

  // Report totals and student histories are fetched when first shown and
  // dropped whenever attendance or students change.
  Map<String, Map<AttendanceStatus, int>>? _reportTotals;
  bool _reportsLoading = false;
  final Map<String, List<MapEntry<DateTime, AttendanceStatus>>> _histories = {};
  final Set<String> _historiesLoading = {};

  void _invalidateAttendance() {
    _reportTotals = null;
    _histories.clear();
  }

  /// Aggregated status counts across every saved day for a class.
  Map<AttendanceStatus, int> attendanceTotals(String classId) {
    if (_reportTotals == null) _loadReports();
    return _reportTotals?[classId] ??
        {for (final s in AttendanceStatus.values) s: 0};
  }

  Future<void> _loadReports() async {
    if (_reportsLoading) return;
    _reportsLoading = true;
    try {
      final res = await api.get('/reports');
      _reportTotals = {
        for (final r in res['attendance'] as List)
          r['class'] as String: {
            for (final s in AttendanceStatus.values)
              s: ((r['counts'] as Map?)?[s.name] as num? ?? 0).toInt(),
          },
      };
      notifyListeners();
    } on ApiException {
      // Shown as "no attendance" until the next refresh.
    } finally {
      _reportsLoading = false;
    }
  }

  /// Attendance history of a student, newest first (empty until loaded).
  List<MapEntry<DateTime, AttendanceStatus>> attendanceHistoryOf(Student s) {
    final cached = _histories[s.id];
    if (cached == null) _loadHistory(s.id);
    return cached ?? const [];
  }

  Future<void> _loadHistory(String studentId) async {
    if (!_historiesLoading.add(studentId)) return;
    try {
      final res = await api.get('/students/$studentId/attendance');
      _histories[studentId] = [
        for (final h in res['history'] as List)
          MapEntry(DateTime.parse(h['date'] as String), _status(h['status'])),
      ];
      notifyListeners();
    } on ApiException {
      // Shown as empty until the next refresh.
    } finally {
      _historiesLoading.remove(studentId);
    }
  }

  // ---- Tests -------------------------------------------------------------
  final List<ClassTest> tests = [];

  List<ClassTest> testsOf(String classId) =>
      tests.where((t) => t.classId == classId).toList();

  Future<ClassTest> addTest(
    String classId,
    String subject,
    double maxMarks,
  ) async {
    final res = await api.post('/classes/$classId/tests', {
      'subject': subject,
      'maxMarks': maxMarks,
    });
    final t = ClassTest.fromJson(res['test']);
    tests.add(t);
    notifyListeners();
    return t;
  }

  /// Saves test details and replaces all marks.
  Future<void> saveTest(
    ClassTest t, {
    required String subject,
    required double maxMarks,
    required Map<String, StudentMark> marks,
  }) async {
    final res = await api.put('/tests/${t.id}', {
      'subject': subject,
      'maxMarks': maxMarks,
      'marks': [for (final e in marks.entries) e.value.toJson(e.key)],
    });
    final saved = ClassTest.fromJson(res['test']);
    t
      ..subject = saved.subject
      ..maxMarks = saved.maxMarks
      ..marks.clear()
      ..marks.addAll(saved.marks);
    notifyListeners();
  }

  Future<void> deleteTest(ClassTest t) async {
    await api.delete('/tests/${t.id}');
    tests.remove(t);
    notifyListeners();
  }

  // ---- Staff users -------------------------------------------------------
  final List<StaffUser> users = [];

  int get activeUserCount => users.where((u) => u.active).length;

  /// [body]: name, subject, phone, email, salary, canAccessFees and
  /// (required when adding, optional when editing) password.
  Future<void> addUser(Map<String, dynamic> body) async {
    final res = await api.post('/users', body);
    users.add(StaffUser.fromJson(res['user']));
    notifyListeners();
  }

  Future<void> updateUser(StaffUser u, Map<String, dynamic> body) async {
    final res = await api.patch('/users/${u.id}', body);
    _assignUser(u, res['user']);
    notifyListeners();
  }

  /// Blocks an active staff login or unblocks a blocked one.
  Future<void> toggleUserActive(StaffUser u) async {
    final res = await api.patch('/users/${u.id}', {'active': !u.active});
    _assignUser(u, res['user']);
    notifyListeners();
  }

  Future<void> deleteUser(StaffUser u) async {
    await api.delete('/users/${u.id}');
    users.remove(u);
    notifyListeners();
  }

  void _assignUser(StaffUser u, Map<String, dynamic> json) {
    final f = StaffUser.fromJson(json);
    u
      ..name = f.name
      ..subject = f.subject
      ..phone = f.phone
      ..email = f.email
      ..salary = f.salary
      ..canAccessFees = f.canAccessFees
      ..active = f.active;
  }
}

final appState = AppState.instance;
