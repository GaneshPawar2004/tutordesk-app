import 'package:flutter/material.dart';

import '../../data/api.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

String _time(DateTime d) {
  final t = TimeOfDay.fromDateTime(d);
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
}

class AttendanceView extends StatefulWidget {
  const AttendanceView({
    super.key,
    required this.schoolClass,
    required this.onBack,
    required this.bottomBar,
    this.unsaved,
  });

  final SchoolClass schoolClass;
  final VoidCallback onBack;
  final Widget bottomBar;

  /// Set to true while marks differ from what is saved (the class screen asks
  /// before leaving).
  final ValueNotifier<bool>? unsaved;

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final Map<String, AttendanceStatus> _marks = {};
  String _query = '';
  bool _sortByRoll = true;

  /// What the server has for [_date]; null while loading or if loading failed.
  AttendanceDay? _day;
  bool _loading = false;
  String? _loadError;

  List<Student> get _students =>
      appState.studentsOf(widget.schoolClass.id, includeDisabled: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    widget.unsaved?.value = false;
    super.dispose();
  }

  /// Marks differ from the saved (or default) ones.
  bool get _dirty {
    final day = _day;
    if (day == null) return false;
    return _students.any(
      (s) =>
          (_marks[s.id] ?? AttendanceStatus.present) !=
              (day.marks[s.id] ?? AttendanceStatus.present) ||
          (_marks[s.id] == AttendanceStatus.others &&
              (_notes[s.id] ?? '') != (day.notes[s.id] ?? '')),
    );
  }

  /// studentId → reason for "Others" (e.g. Sick).
  final Map<String, String> _notes = {};

  void _changed() => widget.unsaved?.value = _dirty;

  Future<void> _setMark(String id, AttendanceStatus v) async {
    if (v == AttendanceStatus.others) {
      // Optional reason, e.g. Sick / Function at home.
      final note = await _askNote(_notes[id] ?? '');
      if (note == null || !mounted) return;
      setState(() {
        _marks[id] = v;
        _notes[id] = note;
      });
    } else {
      setState(() => _marks[id] = v);
    }
    _changed();
  }

  Future<String?> _askNote(String initial) async {
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason (optional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final r in const [
                  'Sick',
                  'Function',
                  'Out of town',
                  'Late',
                ])
                  ActionChip(
                    label: Text(r),
                    onPressed: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
            TextField(
              controller: ctrl,
              maxLength: 100,
              decoration: const InputDecoration(hintText: 'Type a reason…'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  /// Loads saved attendance for [_date]. While loading, or if it failed,
  /// saving is not possible — it would overwrite real marks with defaults.
  Future<void> _load() async {
    final date = _date;
    setState(() {
      _loading = true;
      _loadError = null;
      _day = null;
      _marks
        ..clear()
        ..addEntries(
          _students.map((s) => MapEntry(s.id, AttendanceStatus.present)),
        );
    });
    _changed();
    try {
      final day = await appState.loadAttendance(widget.schoolClass.id, date);
      if (!mounted || date != _date) return;
      setState(() {
        _day = day;
        for (final s in _students) {
          _marks[s.id] = day.marks[s.id] ?? AttendanceStatus.present;
          _notes[s.id] = day.notes[s.id] ?? '';
        }
      });
    } catch (e) {
      if (mounted && date == _date) setState(() => _loadError = '$e');
    } finally {
      if (mounted && date == _date) setState(() => _loading = false);
    }
    _changed();
  }

  int _count(AttendanceStatus s) => _marks.values.where((v) => v == s).length;

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your attendance changes are not saved yet.',
      confirmLabel: 'DISCARD',
    );
  }

  Future<void> _pickDate() async {
    if (!await _confirmDiscard() || !mounted) return;
    final picked = await showAppDatePicker(
      context,
      initial: _date,
      lastDate: DateTime.now(),
    );
    if (picked?.date == null) return;
    _date = DateUtils.dateOnly(picked!.date!);
    _load();
  }

  /// Saves; returns true when saved. [quiet]: no "saved" notice.
  Future<bool> _save({bool quiet = false}) async {
    final day = _day;
    if (_loading || day == null) return false;
    try {
      final saved = await runApiValue(
        context,
        () => appState.saveAttendance(
          widget.schoolClass.id,
          _date,
          Map.of(_marks),
          version: day.version,
          notes: {
            for (final e in _notes.entries)
              if (_marks[e.key] == AttendanceStatus.others &&
                  e.value.isNotEmpty)
                e.key: e.value,
          },
        ),
        rethrowIf: (e) => e is ApiException && e.code == 'ATTENDANCE_CHANGED',
      );
      if (saved == null || !mounted) return false;
      setState(() => _day = saved);
      _changed();
      if (!quiet) {
        final summary =
            '✅ Attendance saved for ${formatDate(_date)}.\n'
            'Present: ${_count(AttendanceStatus.present)} · '
            'Absent: ${_count(AttendanceStatus.absent)} · '
            'Leave: ${_count(AttendanceStatus.leave)}'
            '${_count(AttendanceStatus.others) == 0 ? '' : ' · Others: ${_count(AttendanceStatus.others)}'}';
        // Absentees whose parents have not got today's SMS yet.
        final toNotify = _students
            .where(
              (s) =>
                  saved.marks[s.id] == AttendanceStatus.absent &&
                  saved.sms[s.id] != 'sent' &&
                  saved.sms[s.id] != 'dismissed',
            )
            .length;
        if (toNotify == 0) {
          showNotice(context, summary);
        } else {
          final send = await confirmDialog(
            context,
            title: 'Attendance saved',
            message:
                '$summary\n\nSend SMS to the parents of $toNotify absent '
                'student(s) now?',
            confirmLabel: 'SEND SMS',
            confirmColor: AppColors.primary,
          );
          if (send && mounted) await _smsAbsentParents();
        }
      }
      return true;
    } on ApiException catch (e) {
      // Someone saved this day from another phone after it was opened here.
      if (!mounted) return false;
      await showNotice(
        context,
        '${e.message}\n\nThe latest saved attendance will now be shown. '
        'Make your changes again if they are still needed.',
        title: 'Attendance was updated',
      );
      await _load();
      return false;
    }
  }

  /// SMS to parents of students SAVED as absent, once per student per day.
  Future<void> _smsAbsentParents() async {
    final day = _day;
    if (day == null) return;
    if (_dirty) {
      final save = await confirmDialog(
        context,
        title: 'Save first?',
        message:
            'SMS go only to students saved as absent. Save the attendance now?',
        confirmLabel: 'SAVE',
        confirmColor: AppColors.primary,
      );
      if (!save || !mounted || !await _save(quiet: true) || !mounted) return;
    } else if (!day.saved) {
      showInfo(context, 'Save the attendance first.');
      return;
    }
    final list = await runApiValue(
      context,
      () => appState.absentSmsList(widget.schoolClass.id, _date),
    );
    if (list == null || !mounted) return;
    if (list.messages.isEmpty) {
      showInfo(
        context,
        list.noNumber.isEmpty
            ? 'No students are saved as absent on ${formatDate(_date)}.'
            : 'No mobile number saved for: ${list.noNumber.join(', ')}.',
      );
      return;
    }
    final unsent = list.messages.where((m) => m.unsent).length;
    if (unsent == 0) {
      showInfo(
        context,
        'All ${list.messages.length} absent parents already got the SMS for ${formatDate(_date)}.',
      );
      return;
    }
    if (list.noNumber.isNotEmpty) {
      showInfo(
        context,
        'No mobile number saved for: ${list.noNumber.join(', ')}.',
      );
    }
    await showSmsSheet(
      context,
      title: 'SMS absent parents ($unsent to send)',
      kind: 'absent',
      batchId: list.batch,
      items: [
        for (final m in list.messages)
          SmsItem(
            studentId: m.studentId,
            name: m.name,
            number: m.phone,
            message: m.body,
            messageId: m.id,
            status: m.status,
            sentBy: m.sentBy,
          ),
      ],
    );
    if (mounted) _load(); // refresh the SMS ticks
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final id in _marks.keys) {
        _marks[id] = status;
      }
    });
    _changed();
  }

  void _showChanges(AttendanceDay day) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changes after saving'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final c in day.changes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note),
                  title: Text(
                    '${c.studentName}: ${c.from.label} → ${c.to.label}',
                  ),
                  subtitle: Text(
                    'by ${c.by.isEmpty ? '—' : c.by} · ${formatDate(c.at)} ${_time(c.at)}',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    if (_loadError != null) {
      return Card(
        color: const Color(0xFFFFEBEE),
        child: ListTile(
          leading: const Icon(Icons.cloud_off, color: AppColors.danger),
          title: const Text('Could not load the saved attendance'),
          subtitle: Text(
            '$_loadError\nSaving is off until it loads, so saved marks are not overwritten.',
          ),
          trailing: TextButton(onPressed: _load, child: const Text('RETRY')),
        ),
      );
    }
    final day = _day;
    if (day == null) return const SizedBox.shrink();
    final dirty = _dirty;
    final text = !day.saved
        ? 'Not saved yet for this date'
        : 'Saved by ${day.savedBy ?? '—'}'
              '${day.savedAt == null ? '' : ' at ${_time(day.savedAt!)}, ${formatDate(day.savedAt)}'}';
    return Card(
      color: dirty
          ? const Color(0xFFFFF8E1)
          : day.saved
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFF4F4F4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              dirty
                  ? Icons.edit_outlined
                  : day.saved
                  ? Icons.check_circle
                  : Icons.info_outline,
              color: dirty
                  ? AppColors.warning
                  : day.saved
                  ? AppColors.success
                  : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dirty ? 'You have unsaved changes · $text' : text,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (day.changes.isNotEmpty)
              TextButton(
                onPressed: () => _showChanges(day),
                child: Text('EDITED ${day.changes.length}× · VIEW'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final students =
        _students
            .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
            .toList()
          ..sort(
            (a, b) => _sortByRoll
                ? a.rollNumber.compareTo(b.rollNumber)
                : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    // Students added after the screen was opened.
    for (final s in _students) {
      _marks.putIfAbsent(s.id, () => AttendanceStatus.present);
    }
    final canSave = !_loading && _day != null;

    return Scaffold(
      bottomNavigationBar: widget.bottomBar,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Attendance'),
        actions: [
          PopupMenuButton<AttendanceStatus>(
            onSelected: _markAll,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: AttendanceStatus.present,
                child: Text('Mark all present'),
              ),
              PopupMenuItem(
                value: AttendanceStatus.absent,
                child: Text('Mark all absent'),
              ),
            ],
          ),
        ],
      ),
      body: _students.isEmpty
          ? const EmptyState(
              icon: Icons.event_busy_outlined,
              message: 'No students in this class yet.\nAdd students first.',
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 22,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_outlined, size: 22),
                          const SizedBox(width: 15),
                          Text(
                            formatDate(_date),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 6),
                _statusBanner(),
                const SizedBox(height: 6),
                const InfoBanner(
                  children: [
                    TextSpan(text: 'Everyone is '),
                    TextSpan(
                      text: 'Present',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' by default — just mark the absentees, then Save.',
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children:
                      [
                          _Counter(
                            'Present',
                            _count(AttendanceStatus.present),
                            AppColors.success,
                            const Color(0xFFE8F5E9),
                          ),
                          _Counter(
                            'Absent',
                            _count(AttendanceStatus.absent),
                            AppColors.danger,
                            const Color(0xFFFFEBEE),
                          ),
                          _Counter(
                            'Leave',
                            _count(AttendanceStatus.leave),
                            AppColors.warning,
                            const Color(0xFFFFF8E1),
                          ),
                          _Counter(
                            'Total',
                            _marks.length,
                            AppColors.primary,
                            const Color(0xFFF4F4F4),
                          ),
                        ].expand((w) => [w, const SizedBox(width: 9)]).toList()
                        ..removeLast(),
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: 'Search a student to mark…',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFDDDDDD),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _sortByRoll = !_sortByRoll),
                      icon: const Icon(Icons.swap_vert),
                      label: Text(
                        _sortByRoll ? 'Roll No' : 'Name',
                        style: const TextStyle(fontSize: 14),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: canSave ? _save : null,
                    icon: const Icon(Icons.check_circle_outline, size: 21),
                    label: const Text(
                      'SAVE ATTENDANCE',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                for (final s in students) ...[
                  _StudentAttendanceCard(
                    student: s,
                    status: _marks[s.id]!,
                    sms: _day?.sms[s.id],
                    note: _marks[s.id] == AttendanceStatus.others
                        ? _notes[s.id]
                        : null,
                    onChanged: (v) => _setMark(s.id, v),
                  ),
                  const SizedBox(height: 12),
                ],
                if (students.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: Text(
                        'No matching students.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: canSave ? _smsAbsentParents : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text(
                        'SMS ABSENT PARENTS',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter(this.label, this.value, this.color, this.background);

  final String label;
  final int value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentAttendanceCard extends StatelessWidget {
  const _StudentAttendanceCard({
    required this.student,
    required this.status,
    required this.onChanged,
    this.sms,
    this.note,
  });

  final Student student;
  final AttendanceStatus status;

  /// Reason when marked "Others".
  final String? note;

  /// Absence SMS for this day: sent / pending / failed / dismissed / null.
  final String? sms;
  final ValueChanged<AttendanceStatus> onChanged;

  static Color _activeColor(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => AppColors.primary,
    AttendanceStatus.absent => const Color(0xFFF44336),
    AttendanceStatus.leave => AppColors.warning,
    AttendanceStatus.others => const Color(0xFF607D8B),
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (student.rollNo.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '#${student.rollNo}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  child: Text(
                    student.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (sms == 'sent')
                  const _SmsChip('SMS sent', Icons.done_all, AppColors.success)
                else if (sms == 'pending' || sms == 'failed')
                  const _SmsChip(
                    'SMS waiting',
                    Icons.schedule,
                    AppColors.warning,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children:
                  AttendanceStatus.values
                      .map((s) {
                        final active = s == status;
                        return Expanded(
                          child: Material(
                            color: active
                                ? _activeColor(s)
                                : const Color(0xFFF1F1F1),
                            borderRadius: BorderRadius.circular(4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: () => onChanged(s),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Center(
                                  child: FittedBox(
                                    child: Text(
                                      s.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: active
                                            ? Colors.white
                                            : AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .expand((w) => [w, const SizedBox(width: 9)])
                      .toList()
                    ..removeLast(),
            ),
            if (note != null && note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => onChanged(AttendanceStatus.others),
                child: Text(
                  'Reason: $note  ✎',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmsChip extends StatelessWidget {
  const _SmsChip(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
