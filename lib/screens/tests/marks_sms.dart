import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../utils/phone.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Opens the SMS sheet with each student's marks for [test]. Students with
/// blank marks get an "absent" message; skipped students are left out.
Future<void> showMarksSms(BuildContext context, ClassTest test) {
  final className = appState.classById(test.classId)?.name ?? '';
  final items = <SmsItem>[];
  for (final s in appState.studentsOf(test.classId, includeDisabled: false)) {
    final m = test.marks[s.id];
    if (m?.skip ?? false) continue;
    final marks = m?.marks;
    final remarks = (m?.remarks ?? '').isEmpty ? '' : ' Remarks: ${m!.remarks}';
    items.add(
      SmsItem(
        studentId: s.id,
        name: s.name,
        number: parentNumber(s),
        message: marks == null
            ? 'Dear Parent, ${s.name} ($className) was absent for the '
                  '${test.subject} test.'
            : 'Dear Parent, ${s.name} ($className) scored ${_num(marks)}/'
                  '${_num(test.maxMarks)} in ${test.subject}.$remarks',
      ),
    );
  }
  return showSmsSheet(
    context,
    title: 'SMS marks — ${test.subject}',
    kind: 'marks',
    listTitle: '$className · Marks: ${test.subject}',
    classId: test.classId,
    items: items,
  );
}
