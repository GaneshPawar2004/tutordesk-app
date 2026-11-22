import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/api.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'format.dart';

String _csvCell(Object? v) {
  final s = '${v ?? ''}';
  return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// "2026-11-22" -> "22-11-2026" (or with another separator).
String _dmy(String ymd, [String sep = '-']) {
  final p = ymd.split('-');
  return p.length == 3 ? '${p[2]}$sep${p[1]}$sep${p[0]}' : ymd;
}

String _label(String status) => switch (status) {
  'present' => 'Present',
  'absent' => 'Absent',
  'leave' => 'Leave',
  'others' => 'Others',
  _ => status, // the reason written for "Others", e.g. Sick
};

/// Teachers App CSV columns (same file as its "Export Class Data (CSV)"),
/// so the file opens in Excel and can be imported back into Kaksha.
const exportColumns = [
  'NAME',
  'MARKS',
  'CONTACT',
  'STATUS',
  'ROLL_NUMBER',
  'FATHER_NAME',
  'EMAIL',
  'FEES_PAID',
  'TOTAL_FEES',
  'FEES_DUE',
  'IMAGE_PATH',
  'DUE_DATE',
];

/// Builds the class CSV in the Teachers App format: fixed columns, then one
/// column per attendance date (DD-MM-YYYY) and one per test ("Maths/50").
/// [attendance]: date (YYYY-MM-DD) -> studentId -> status or reason.
/// [payments]: studentId -> payments; null without fee access.
String buildClassCsv({
  required List<Student> students,
  required List<ClassTest> tests,
  required Map<String, Map<String, String>> attendance,
  Map<String, List<({String date, double amount})>>? payments,
}) {
  final dates = attendance.keys.toList()..sort();
  final fees = payments != null;
  final rows = <List<Object?>>[
    [
      ...exportColumns,
      for (final d in dates) _dmy(d),
      for (final t in tests) '${t.subject}/${_num(t.maxMarks)}',
    ],
    for (final s in students)
      [
        s.name,
        tests.isEmpty ? '' : _markText(tests.last.marks[s.id]),
        [s.contact, s.parentMobile].where((n) => n.isNotEmpty).join(';'),
        dates.isEmpty ? '' : _label(attendance[dates.last]![s.id] ?? ''),
        s.rollNo,
        s.fatherName,
        s.email,
        if (fees) ...[
          [
            for (final p in payments[s.id] ?? const [])
              '${_dmy(p.date, '/')} ${_num(p.amount)}',
          ].join(';'),
          _num(s.totalFees),
          _num(s.feesDue),
        ] else ...[
          '',
          '',
          '',
        ],
        '',
        s.feesDueDate == null || !fees
            ? ''
            : _dmy(AppState.dateKey(s.feesDueDate!), '/'),
        for (final d in dates) _label(attendance[d]![s.id] ?? ''),
        for (final t in tests) _markText(t.marks[s.id]),
      ],
  ];
  return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
}

/// Shares a CSV (opens in Excel / Google Sheets) of the class in the old
/// Teachers App format: details, fees with payments, attendance and marks.
Future<void> exportClass(BuildContext context, SchoolClass c) async {
  final origin = _shareOrigin(context);
  final students = appState.studentsOf(c.id)
    ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  if (students.isEmpty) {
    showInfo(context, 'No students to export.');
    return;
  }
  final history = await runApiValue(
    context,
    () async => await api.get('/classes/${c.id}/export') as Map,
  );
  if (history == null || !context.mounted) return;
  final rawPays = history['payments'] as Map?;
  final csv = buildClassCsv(
    students: students,
    tests: appState.testsOf(c.id),
    attendance: {
      for (final e in (history['attendance'] as Map).entries)
        e.key as String: {
          for (final r in (e.value as Map).entries)
            r.key as String: r.value as String,
        },
    },
    payments: rawPays == null || !appState.canAccessFees
        ? null
        : {
            for (final e in rawPays.entries)
              e.key as String: [
                for (final p in e.value as List)
                  (
                    date: p['date'] as String,
                    amount: (p['amount'] as num).toDouble(),
                  ),
              ],
          },
  );
  // BOM so Excel reads ₹ and Indian names correctly.
  final bytes = utf8.encode('﻿$csv');
  final name = '${c.name.replaceAll(RegExp(r'[^\w.-]+'), '_')}.csv';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
      fileNameOverrides: [name],
      subject: '${c.name} – students',
      sharePositionOrigin: origin,
    ),
  );
}

/// Where the share sheet points from; iPads crash without it.
Rect? _shareOrigin(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null || !box.hasSize
      ? null
      : box.localToGlobal(Offset.zero) & box.size;
}

String _markText(StudentMark? m) {
  if (m == null || m.skip) return '';
  return m.marks == null ? 'Absent' : _num(m.marks!);
}

/// Shares a text report of one student (details, attendance, fees, marks),
/// e.g. to a parent on WhatsApp.
Future<void> exportStudent(BuildContext context, Student s) async {
  final origin = _shareOrigin(context);
  final c = appState.classById(s.classId);
  final summary = await runApiValue(
    context,
    () => api.get('/students/${s.id}/attendance'),
  );
  if (summary == null || !context.mounted) return;
  final att = summary['summary'] as Map<String, dynamic>;
  final lines = <String>[
    '📘 ${s.name} – ${c?.name ?? ''}${s.rollNo.isEmpty ? '' : ' (Roll ${s.rollNo})'}',
    if (appState.instituteName.isNotEmpty) appState.instituteName,
    '',
    '🗓 Attendance: ${att['present']} of ${att['days']} days present'
        '${att['percent'] == null ? '' : ' (${att['percent']}%)'}',
    if (appState.canAccessFees && s.totalFees > 0)
      '💰 Fees: paid ${formatMoney(s.feesPaid)} of ${formatMoney(s.totalFees)}, '
          'due ${formatMoney(s.feesDue)}',
  ];
  final marks = [
    for (final t in appState.testsOf(s.classId))
      if (t.marks[s.id] case final m? when !m.skip)
        '• ${t.subject}: ${m.marks == null ? 'Absent' : '${_num(m.marks!)} / ${_num(t.maxMarks)}'}',
  ];
  if (marks.isNotEmpty) lines.addAll(['', '📝 Test marks:', ...marks]);
  await SharePlus.instance.share(
    ShareParams(
      text: lines.join('\n'),
      subject: '${s.name} – report',
      sharePositionOrigin: origin,
    ),
  );
}
