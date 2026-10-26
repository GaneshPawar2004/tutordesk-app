import '../../core/utils/formatters.dart';
import '../../shared/models/models.dart';
import 'mock_repository.dart';

class AttendanceSaveResult {
  const AttendanceSaveResult(this.session, {required this.created});

  final AttendanceSession session;

  /// False when the session had already been saved (by anyone). The existing
  /// session is returned unchanged — no duplicate submission is created.
  final bool created;
}

class AttendanceRepository extends MockRepository {
  AttendanceRepository(super.onChanged, {required this._sessions});

  final List<AttendanceSession> _sessions;

  static String sessionId(String classId, DateTime d) =>
      'att-$classId-${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

  AttendanceSession? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  AttendanceSession? sessionFor(String classId, DateTime date) =>
      byId(sessionId(classId, date));

  /// Newest first.
  List<AttendanceSession> forClass(String classId, {String? yearId}) =>
      _sessions
          .where(
            (s) =>
                s.classId == classId &&
                (yearId == null || s.academicYearId == yearId),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  List<AttendanceSession> between(
    DateTime from,
    DateTime to, {
    String? yearId,
  }) => _sessions
      .where(
        (s) =>
            !s.date.isBefore(from) &&
            !s.date.isAfter(to) &&
            (yearId == null || s.academicYearId == yearId),
      )
      .toList();

  /// Newest first.
  List<(DateTime, AttendanceStatus)> historyFor(
    String studentId,
    String yearId,
  ) {
    final list = <(DateTime, AttendanceStatus)>[];
    for (final s in _sessions) {
      if (s.academicYearId != yearId) continue;
      final status = s.records[studentId];
      if (status != null) list.add((s.date, status));
    }
    list.sort((a, b) => b.$1.compareTo(a.$1));
    return list;
  }

  AttendanceSummary summaryFor(String studentId, String yearId) {
    var p = 0, a = 0, l = 0, lv = 0;
    for (final (_, status) in historyFor(studentId, yearId)) {
      switch (status) {
        case AttendanceStatus.present:
          p++;
        case AttendanceStatus.absent:
          a++;
        case AttendanceStatus.late:
          l++;
        case AttendanceStatus.leave:
          lv++;
      }
    }
    return AttendanceSummary(present: p, absent: a, late: l, leave: lv);
  }

  AttendanceSaveResult save({
    required String classId,
    required String yearId,
    required DateTime date,
    required Map<String, AttendanceStatus> records,
    required String markedBy,
  }) {
    final existing = sessionFor(classId, date);
    if (existing != null) return AttendanceSaveResult(existing, created: false);
    final session = AttendanceSession(
      id: sessionId(classId, date),
      classId: classId,
      academicYearId: yearId,
      date: Fmt.dateOnly(date),
      records: Map.of(records),
      markedBy: markedBy,
      markedAt: DateTime.now(),
    );
    _sessions.add(session);
    changed();
    return AttendanceSaveResult(session, created: true);
  }

  /// Authorised correction: replaces records and appends an audit note.
  void correct(
    AttendanceSession session, {
    required Map<String, AttendanceStatus> records,
    required String by,
    required String note,
  }) {
    final changes = <String>[];
    records.forEach((id, status) {
      if (session.records[id] != status) changes.add(id);
    });
    session.records = Map.of(records);
    session.audit.add(
      AuditNote(
        at: DateTime.now(),
        by: by,
        note: '$note (${Fmt.plural(changes.length, 'record')} changed)',
      ),
    );
    changed();
  }
}
