import '../../shared/models/models.dart';
import '../mock_data.dart';

/// Who is signed in, as reported by GET /api/sync.
class SnapshotUser {
  const SnapshotUser({required this.id, required this.role});

  final String id;
  final UserRole role;
}

DateTime _date(Object? v) => DateTime.parse(v as String);
DateTime _time(Object? v) => DateTime.parse(v as String).toLocal();
DateTime? _timeOrNull(Object? v) => v == null ? null : _time(v);
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
List<String> _strings(Object? v) =>
    (v as List? ?? const []).map((e) => e.toString()).toList();
T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((e) => e.name == name).firstOrNull ?? fallback;

/// Converts the server snapshot into the same data container the app's
/// repositories are built from (shared with the offline sample data).
(MockSeed, SnapshotUser) parseSnapshot(Map<String, dynamic> j) {
  final me = j['me'] as Map<String, dynamic>;
  final t = j['tuition'] as Map<String, dynamic>;
  final a = j['admin'] as Map<String, dynamic>? ?? me;
  final sms = j['sms'] as Map<String, dynamic>? ?? const {};

  final seed = MockSeed(
    tuition: Tuition(
      id: t['id'] as String,
      name: t['name'] as String,
      city: t['city'] as String? ?? '',
      address: t['address'] as String? ?? '',
      phone: t['phone'] as String? ?? '',
      email: t['email'] as String? ?? '',
    ),
    admin: AdminUser(
      id: a['id'] as String,
      name: a['name'] as String,
      email: a['email'] as String? ?? '',
      phone: a['phone'] as String? ?? '',
    ),
    staff: [
      for (final s in (j['staff'] as List).cast<Map<String, dynamic>>())
        StaffMember(
          id: s['id'] as String,
          name: s['name'] as String,
          phone: s['phone'] as String,
          email: s['email'] as String? ?? '',
          designation: s['designation'] as String? ?? '',
          assignedClassIds: _strings(s['assignedClassIds']),
          permissions: {
            for (final p in _strings(s['permissions']))
              if (StaffPermission.values.any((x) => x.name == p))
                StaffPermission.values.byName(p),
          },
          joinedOn: _date(s['joinedOn']),
          isActive: s['isActive'] as bool? ?? true,
          accountStatus: _enum(
            AccountStatus.values,
            s['accountStatus'],
            AccountStatus.active,
          ),
          inviteCode: _str(s['inviteCode']),
        ),
    ],
    years: [
      for (final y in (j['years'] as List).cast<Map<String, dynamic>>())
        AcademicYear(
          id: y['id'] as String,
          label: y['label'] as String,
          startDate: _date(y['startDate']),
          endDate: _date(y['endDate']),
          status: _enum(YearStatus.values, y['status'], YearStatus.closed),
        ),
    ],
    classes: [
      for (final c in (j['classes'] as List).cast<Map<String, dynamic>>())
        SchoolClass(
          id: c['id'] as String,
          name: c['name'] as String,
          grade: (c['grade'] as num).toInt(),
          sessionLabel: c['sessionLabel'] as String? ?? '',
          room: c['room'] as String? ?? '',
          subjectIds: _strings(c['subjectIds']),
          isActive: c['isActive'] as bool? ?? true,
        ),
    ],
    subjects: [
      for (final s in (j['subjects'] as List).cast<Map<String, dynamic>>())
        Subject(
          id: s['id'] as String,
          name: s['name'] as String,
          code: s['code'] as String? ?? '',
        ),
    ],
    students: [
      for (final s in (j['students'] as List).cast<Map<String, dynamic>>())
        Student(
          id: s['id'] as String,
          firstName: s['firstName'] as String,
          lastName: s['lastName'] as String,
          dateOfBirth: _date(s['dateOfBirth']),
          gender: s['gender'] == null
              ? null
              : _enum(Gender.values, s['gender'], Gender.other),
          parentName: s['parentName'] as String,
          parentPhone: s['parentPhone'] as String,
          altPhone: _str(s['altPhone']),
          address: _str(s['address']),
          admittedOn: _date(s['admittedOn']),
          isActive: s['isActive'] as bool? ?? true,
        ),
    ],
    enrollments: [
      for (final e in (j['enrollments'] as List).cast<Map<String, dynamic>>())
        Enrollment(
          id: e['id'] as String,
          studentId: e['studentId'] as String,
          academicYearId: e['academicYearId'] as String,
          classId: e['classId'] as String,
          enrolledOn: _date(e['enrolledOn']),
          status: _enum(
            EnrollmentStatus.values,
            e['status'],
            EnrollmentStatus.active,
          ),
          promotedFromId: _str(e['promotedFromId']),
        ),
    ],
    feePlans: [
      for (final p
          in (j['feePlans'] as List? ?? const []).cast<Map<String, dynamic>>())
        FeePlan(
          id: p['id'] as String,
          enrollmentId: p['enrollmentId'] as String,
          annualFee: (p['annualFee'] as num).toInt(),
          installmentCount: (p['installmentCount'] as num).toInt(),
          frequency: _enum(
            FeeFrequency.values,
            p['frequency'],
            FeeFrequency.custom,
          ),
          firstDueDate: _date(p['firstDueDate']),
          note: _str(p['note']),
        ),
    ],
    payments: [
      for (final p
          in (j['payments'] as List? ?? const []).cast<Map<String, dynamic>>())
        Payment(
          id: p['id'] as String,
          enrollmentId: p['enrollmentId'] as String,
          amount: (p['amount'] as num).toInt(),
          date: _date(p['date']),
          method: _enum(PaymentMethod.values, p['method'], PaymentMethod.cash),
          recordedBy: p['recordedBy'] as String? ?? '',
          reference: _str(p['reference']),
          note: _str(p['note']),
        ),
    ],
    sessions: [
      for (final s in (j['sessions'] as List).cast<Map<String, dynamic>>())
        AttendanceSession(
          id: s['id'] as String,
          classId: s['classId'] as String,
          academicYearId: s['academicYearId'] as String,
          date: _date(s['date']),
          records: {
            for (final e in (s['records'] as Map<String, dynamic>).entries)
              e.key: _enum(
                AttendanceStatus.values,
                e.value,
                AttendanceStatus.present,
              ),
          },
          markedBy: s['markedBy'] as String? ?? '',
          markedAt: _time(s['markedAt']),
          audit: [
            for (final n
                in (s['audit'] as List? ?? const [])
                    .cast<Map<String, dynamic>>())
              AuditNote(
                at: _time(n['at']),
                by: n['by'] as String? ?? '',
                note: n['note'] as String? ?? '',
              ),
          ],
        ),
    ],
    exams: [
      for (final e in (j['exams'] as List).cast<Map<String, dynamic>>())
        Exam(
          id: e['id'] as String,
          name: e['name'] as String,
          academicYearId: e['academicYearId'] as String,
          classId: e['classId'] as String,
          date: _date(e['date']),
          subjects: [
            for (final s
                in (e['subjects'] as List).cast<Map<String, dynamic>>())
              ExamSubject(
                subjectId: s['subjectId'] as String,
                maxMarks: (s['maxMarks'] as num).toDouble(),
              ),
          ],
          createdBy: e['createdBy'] as String? ?? '',
          description: e['description'] as String? ?? '',
          isDraft: e['isDraft'] as bool? ?? false,
          resultsPublished: e['resultsPublished'] as bool? ?? false,
          publishedAt: _timeOrNull(e['publishedAt']),
          revision: (e['revision'] as num?)?.toInt() ?? 0,
          correctionLog: _strings(e['correctionLog']),
          marks: {
            for (final subj
                in (e['marks'] as Map<String, dynamic>? ?? const {}).entries)
              subj.key: {
                for (final m in (subj.value as Map<String, dynamic>).entries)
                  m.key: MarkEntry(
                    marks: ((m.value as Map)['marks'] as num?)?.toDouble(),
                    absent: (m.value as Map)['absent'] == true,
                  ),
              },
          },
        ),
    ],
    batches: [
      for (final b in (j['batches'] as List).cast<Map<String, dynamic>>())
        MessageBatch(
          id: b['id'] as String,
          sourceKey: b['sourceKey'] as String,
          title: b['title'] as String,
          category: _enum(
            MessageCategory.values,
            b['category'],
            MessageCategory.announcement,
          ),
          classIds: _strings(b['classIds']),
          createdBy: b['createdBy'] as String? ?? '',
          createdAt: _time(b['createdAt']),
          previewBody: b['previewBody'] as String? ?? '',
          recipients: [
            for (final r
                in (b['recipients'] as List).cast<Map<String, dynamic>>())
              MessageRecipient(
                id: r['id'] as String,
                studentId: _str(r['studentId']),
                studentName: r['studentName'] as String,
                parentName: r['parentName'] as String,
                phone: r['phone'] as String,
                body: r['body'] as String,
                status: _enum(
                  DeliveryStatus.values,
                  r['status'],
                  DeliveryStatus.queued,
                ),
                attempts: (r['attempts'] as num?)?.toInt() ?? 0,
                failureReason: _str(r['failureReason']),
                updatedAt: _time(r['updatedAt']),
              ),
          ],
        ),
    ],
    notifications: [
      for (final n in (j['notifications'] as List).cast<Map<String, dynamic>>())
        AppNotification(
          id: n['id'] as String,
          type: _enum(
            NotificationType.values,
            n['type'],
            NotificationType.student,
          ),
          title: n['title'] as String,
          body: n['body'] as String? ?? '',
          createdAt: _time(n['createdAt']),
          isRead: n['isRead'] as bool? ?? false,
          adminOnly: n['adminOnly'] as bool? ?? false,
        ),
    ],
    activity: [
      for (final x in (j['activity'] as List).cast<Map<String, dynamic>>())
        ActivityEvent(
          type: _enum(ActivityType.values, x['type'], ActivityType.student),
          title: x['title'] as String,
          subtitle: x['subtitle'] as String? ?? '',
          at: _time(x['at']),
          adminOnly: x['adminOnly'] as bool? ?? false,
        ),
    ],
    sms: SmsSettings(
      mode: sms['mode'] == 'device'
          ? SendingMode.androidDevice
          : SendingMode.simulated,
      deviceName: _str(sms['deviceName']) ?? 'Not connected',
      lastSync: _timeOrNull(sms['lastSeenAt']) ?? DateTime(2000),
      monthlyAllowance: (sms['monthlyAllowance'] as num?)?.toInt() ?? 0,
      usedThisMonth: (sms['usedThisMonth'] as num?)?.toInt() ?? 0,
      senderSignature: t['name'] as String,
    ),
    events: const [],
  );
  final role = me['role'] == 'admin' ? UserRole.admin : UserRole.staff;
  return (seed, SnapshotUser(id: me['id'] as String, role: role));
}

/// Placeholder used before the first sync so getters never see empty lists.
MockSeed emptySeed() {
  final now = DateTime.now();
  final start = now.month >= 6 ? now.year : now.year - 1;
  return MockSeed(
    tuition: Tuition(
      id: '',
      name: '',
      city: '',
      address: '',
      phone: '',
      email: '',
    ),
    admin: AdminUser(id: '', name: '', email: '', phone: ''),
    staff: [],
    years: [
      AcademicYear(
        id: 'placeholder',
        label: '$start–${(start + 1) % 100}',
        startDate: DateTime(start, 6),
        endDate: DateTime(start + 1, 4, 30),
        status: YearStatus.active,
      ),
    ],
    classes: [],
    subjects: [],
    students: [],
    enrollments: [],
    feePlans: [],
    payments: [],
    sessions: [],
    exams: [],
    batches: [],
    notifications: [],
    activity: [],
    sms: SmsSettings(
      mode: SendingMode.notConfigured,
      deviceName: '',
      lastSync: now,
      monthlyAllowance: 0,
      usedThisMonth: 0,
      senderSignature: '',
    ),
    events: const [],
  );
}
