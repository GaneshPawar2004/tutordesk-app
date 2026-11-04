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

/// Shares a CSV (opens in Excel / Google Sheets) of the class: student
/// details, fees (with fee access) and marks of every test.
Future<void> exportClass(BuildContext context, SchoolClass c) async {
  final students = appState.studentsOf(c.id)
    ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  if (students.isEmpty) {
    showInfo(context, 'No students to export.');
    return;
  }
  final fees = appState.canAccessFees;
  final tests = appState.testsOf(c.id);
  final rows = <List<Object?>>[
    [
      'Roll No',
      'Name',
      "Father's name",
      'Contact',
      "Parent's mobile",
      'Email',
      'Date of birth',
      'Status',
      if (fees) ...['Total fees', 'Paid', 'Due', 'Fees due date'],
      for (final t in tests) '${t.subject} (/${_num(t.maxMarks)})',
    ],
    for (final s in students)
      [
        s.rollNo,
        s.name,
        s.fatherName,
        s.contact,
        s.parentMobile,
        s.email,
        formatDate(s.dateOfBirth),
        s.disabled ? 'Disabled' : 'Active',
        if (fees) ...[
          _num(s.totalFees),
          _num(s.feesPaid),
          _num(s.feesDue),
          formatDate(s.feesDueDate),
        ],
        for (final t in tests) _markText(t.marks[s.id]),
      ],
  ];
  final csv = rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
  // BOM so Excel reads ₹ and Indian names correctly.
  final bytes = utf8.encode('﻿$csv');
  final name = '${c.name.replaceAll(RegExp(r'[^\w\- ]'), '')} - Kaksha.csv';
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
      fileNameOverrides: [name],
      subject: '${c.name} – students',
    ),
  );
}

String _markText(StudentMark? m) {
  if (m == null || m.skip) return '';
  return m.marks == null ? 'Absent' : _num(m.marks!);
}

/// Shares a text report of one student (details, attendance, fees, marks),
/// e.g. to a parent on WhatsApp.
Future<void> exportStudent(BuildContext context, Student s) async {
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
    ShareParams(text: lines.join('\n'), subject: '${s.name} – report'),
  );
}
