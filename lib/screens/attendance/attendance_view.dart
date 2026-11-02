import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({
    super.key,
    required this.schoolClass,
    required this.onBack,
    required this.bottomBar,
  });

  final SchoolClass schoolClass;
  final VoidCallback onBack;
  final Widget bottomBar;

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final Map<String, AttendanceStatus> _marks = {};
  String _query = '';
  bool _sortByRoll = true;

  List<Student> get _students =>
      appState.studentsOf(widget.schoolClass.id, includeDisabled: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _loading = false;

  /// Loads saved attendance for [_date], defaulting everyone to Present.
  Future<void> _load() async {
    final date = _date;
    setState(() {
      _loading = true;
      _marks
        ..clear()
        ..addEntries(
          _students.map((s) => MapEntry(s.id, AttendanceStatus.present)),
        );
    });
    try {
      final saved = await appState.loadAttendance(widget.schoolClass.id, date);
      if (!mounted || date != _date) return;
      setState(() {
        for (final s in _students) {
          _marks[s.id] = saved?[s.id] ?? AttendanceStatus.present;
        }
      });
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted && date == _date) setState(() => _loading = false);
    }
  }

  int _count(AttendanceStatus s) => _marks.values.where((v) => v == s).length;

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context,
      initial: _date,
      lastDate: DateTime.now(),
    );
    if (picked?.date == null) return;
    _date = DateUtils.dateOnly(picked!.date!);
    _load();
  }

  Future<void> _save() async {
    if (_loading) return;
    final ok = await runApi(
      context,
      () => appState.saveAttendance(widget.schoolClass.id, _date, _marks),
    );
    if (!ok || !mounted) return;
    showNotice(
      context,
      '✅ Attendance saved for ${formatDate(_date)}.\n'
      'Present: ${_count(AttendanceStatus.present)} · '
      'Absent: ${_count(AttendanceStatus.absent)} · '
      'Leave: ${_count(AttendanceStatus.leave)}',
    );
  }

  void _smsAbsentParents() {
    final absent = _students
        .where((s) => _marks[s.id] == AttendanceStatus.absent)
        .toList();
    if (absent.isEmpty) {
      showInfo(context, 'No absentees to notify.');
      return;
    }
    showSmsSheet(
      context,
      title: 'SMS absent parents (${absent.length})',
      items: [
        for (final s in absent)
          SmsItem(
            name: s.name,
            number: parentNumber(s),
            message:
                'Dear Parent, ${s.name} (${widget.schoolClass.name}) was '
                'absent on ${formatDate(_date)}.',
          ),
      ],
    );
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final id in _marks.keys) {
        _marks[id] = status;
      }
    });
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
                const SizedBox(height: 12),
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
                    onPressed: _save,
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
                    onChanged: (v) => setState(() => _marks[s.id] = v),
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
                      onPressed: _smsAbsentParents,
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
  });

  final Student student;
  final AttendanceStatus status;
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
          ],
        ),
      ),
    );
  }
}
