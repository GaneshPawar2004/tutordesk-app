import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../attendance/attendance_view.dart';
import '../fees/fees_view.dart';
import '../students/students_view.dart';
import '../tests/tests_view.dart';

enum ClassTab { attendance, tests, fees }

/// A single class: shows the student list by default and switches to
/// Attendance / Tests / Fees from the bottom bar.
class ClassDetailScreen extends StatefulWidget {
  const ClassDetailScreen({super.key, required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  ClassTab? _tab;

  /// True while the Attendance tab has unsaved marks.
  final _attendanceUnsaved = ValueNotifier(false);

  @override
  void dispose() {
    _attendanceUnsaved.dispose();
    super.dispose();
  }

  /// Switches tab; asks first when leaving unsaved attendance.
  Future<void> _select(ClassTab? tab) async {
    if (tab == _tab) return;
    if (_tab == ClassTab.attendance && _attendanceUnsaved.value) {
      final leave = await confirmDialog(
        context,
        title: 'Discard attendance changes?',
        message: 'Your attendance changes are not saved yet.',
        confirmLabel: 'DISCARD',
      );
      if (!leave || !mounted) return;
      _attendanceUnsaved.value = false;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    void backToStudents() => _select(null);
    final bar = _ClassBottomBar(selected: _tab, onSelect: _select);

    final Widget body = switch (_tab) {
      null => StudentsView(schoolClass: c, onOpenTab: _select, bottomBar: bar),
      ClassTab.attendance => AttendanceView(
        schoolClass: c,
        onBack: backToStudents,
        bottomBar: bar,
        unsaved: _attendanceUnsaved,
      ),
      ClassTab.tests => TestsView(
        schoolClass: c,
        onBack: backToStudents,
        bottomBar: bar,
      ),
      ClassTab.fees => FeesView(
        schoolClass: c,
        onBack: backToStudents,
        bottomBar: bar,
      ),
    };

    return PopScope(
      canPop: _tab == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) backToStudents();
      },
      child: body,
    );
  }
}

class _ClassBottomBar extends StatelessWidget {
  const _ClassBottomBar({required this.selected, required this.onSelect});

  final ClassTab? selected;
  final ValueChanged<ClassTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(ClassTab tab, IconData icon, String label) {
      final active = selected == tab;
      final color = active ? AppColors.primary : AppColors.textMuted;
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(tab),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(color: color, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(ClassTab.attendance, Icons.event_outlined, 'Attendance'),
            item(ClassTab.tests, Icons.assignment_outlined, 'Tests'),
            item(ClassTab.fees, Icons.payments_outlined, 'Fees'),
          ],
        ),
      ),
    );
  }
}
