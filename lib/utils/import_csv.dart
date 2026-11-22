import 'dart:convert';

/// A class file read for import: students (with fees, payments and
/// attendance), tests with marks, and notes about anything left out.
class ClassImport {
  ClassImport({
    required this.source,
    required this.students,
    required this.tests,
    required this.warnings,
  });

  /// "Teachers App" or "Kaksha".
  final String source;

  /// Ready for POST /classes/:id/import (see kaksha-backend routes/import.js).
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> tests;
  final List<String> warnings;

  int get attendanceDays =>
      {for (final s in students) ...(s['attendance'] as Map).keys}.length;

  int get paymentCount =>
      students.fold(0, (n, s) => n + (s['payments'] as List).length);

  double get paidTotal => students.fold(
    0,
    (n, s) =>
        n +
        (s['payments'] as List).fold<double>(
          0,
          (a, p) => a + (p['amount'] as num),
        ),
  );

  Map<String, dynamic> toBody() => {
    'source': source,
    'students': students,
    'tests': tests,
  };
}

/// Thrown when the file is not a class export we understand.
class ImportFormatException implements Exception {
  ImportFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Splits CSV text into rows (handles quotes, "" escapes and CRLF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (ch == '\n') {
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else if (ch != '\r') {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
}

/// Indian mobile as 10 digits, or null if it isn't one.
String? cleanMobile(String v) {
  var d = v.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return RegExp(r'^[6-9]\d{9}$').hasMatch(d) ? d : null;
}

/// "22/11/2026", "22-11-2026" or "2026-11-22" → "2026-11-22" (null if not a date).
String? cleanDate(String v) {
  final t = v.trim();
  var m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$').firstMatch(t);
  if (m != null) {
    final day = int.parse(m[1]!), month = int.parse(m[2]!);
    if (day < 1 || day > 31 || month < 1 || month > 12) return null;
    return '${m[3]}-${m[2]!.padLeft(2, '0')}-${m[1]!.padLeft(2, '0')}';
  }
  m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
  return m == null ? null : '${m[1]}-${m[2]}-${m[3]}';
}

double? _number(String v) =>
    double.tryParse(v.replaceAll(RegExp(r'[₹,\s]'), ''));

final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

String _status(String v) => switch (v.trim().toLowerCase()) {
  'present' || 'p' => 'present',
  'absent' || 'a' => 'absent',
  'leave' || 'l' => 'leave',
  _ => 'others',
};

/// Reads a class file exported by the old Teachers App ("Export Class Data
/// (CSV)") or by Kaksha ("Export to Excel").
ClassImport parseClassFile(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = parseCsv(text);
  if (rows.length < 2) {
    throw ImportFormatException(
      'This file is empty. It needs a header row and at least one student.',
    );
  }
  final header = rows.first.map((h) => h.trim()).toList();
  final upper = header.map((h) => h.toUpperCase()).toList();
  if (upper.contains('NAME') && upper.contains('ROLL_NUMBER')) {
    return _teachersApp(header, upper, rows.skip(1).toList());
  }
  if (header.contains('Name') && header.contains('Roll No')) {
    return _kaksha(header, rows.skip(1).toList());
  }
  throw ImportFormatException(
    'This is not a class file from Teachers App or Kaksha. In Teachers App, '
    'open the class → ⋮ → Export Class Data (CSV).',
  );
}

/// Columns: NAME, MARKS, CONTACT ("contact;parent"), STATUS, ROLL_NUMBER,
/// FATHER_NAME, EMAIL, FEES_PAID ("DD/MM/YYYY amount;…"), TOTAL_FEES,
/// FEES_DUE, IMAGE_PATH, DUE_DATE, then one column per attendance date
/// (DD-MM-YYYY) and one per test ("Subject/MaxMarks").
ClassImport _teachersApp(
  List<String> header,
  List<String> upper,
  List<List<String>> rows,
) {
  int col(String name) => upper.indexOf(name);
  final dateCols = <int, String>{};
  final testCols = <int, ({String subject, double max})>{};
  for (var i = 0; i < header.length; i++) {
    final date = RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(header[i])
        ? cleanDate(header[i])
        : null;
    if (date != null) {
      dateCols[i] = date;
      continue;
    }
    final m = RegExp(r'^(.*)/\s*(\d+(?:\.\d+)?)\s*$').firstMatch(header[i]);
    if (m != null && m[1]!.trim().isNotEmpty) {
      testCols[i] = (subject: m[1]!.trim(), max: double.parse(m[2]!));
    }
  }

  final warnings = <String>{};
  final students = <Map<String, dynamic>>[];
  final marks = {for (final i in testCols.keys) i: <String, double?>{}};
  var photos = 0;
  for (final r in rows) {
    String at(int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    final name = at(col('NAME'));
    if (name.isEmpty) continue;

    // CONTACT is "contact;parent" — with one number, use it as the parent's.
    final numbers = at(
      col('CONTACT'),
    ).split(RegExp(r'[;/]')).map((n) => n.trim()).where((n) => n.isNotEmpty);
    final cleaned = <String>[];
    for (final n in numbers) {
      final c = cleanMobile(n);
      c == null
          ? warnings.add(
              'Some mobile numbers were not valid and were left out.',
            )
          : cleaned.add(c);
    }
    var email = at(col('EMAIL'));
    if (email.isNotEmpty && !_emailRe.hasMatch(email)) {
      warnings.add('Some emails were not valid and were left out.');
      email = '';
    }
    if (at(col('IMAGE_PATH')).isNotEmpty) photos++;

    final total = _number(at(col('TOTAL_FEES'))) ?? 0;
    final due = _number(at(col('FEES_DUE')));
    final payments = <Map<String, dynamic>>[];
    for (final p in at(col('FEES_PAID')).split(';')) {
      final m = RegExp(
        r'^\s*(\d{1,2}[/-]\d{1,2}[/-]\d{4})?\s*([\d.,]+)\s*$',
      ).firstMatch(p);
      final amount = m == null ? null : _number(m[2]!);
      if (amount != null && amount > 0) {
        payments.add({
          'amount': amount,
          'paidAt': m![1] == null ? null : cleanDate(m[1]!),
        });
      }
    }
    // Older files: no payment list, but total − due shows what was paid.
    if (payments.isEmpty && due != null && total - due > 0) {
      payments.add({'amount': total - due, 'paidAt': null});
    }

    final attendance = <String, String>{};
    dateCols.forEach((i, date) {
      final v = at(i);
      if (v.isEmpty) return;
      // Anything else is "Others" with that text as the reason (e.g. Sick).
      final st = _status(v);
      attendance[date] = st == 'others' && v.toLowerCase() != 'others'
          ? (v.length > 100 ? v.substring(0, 100) : v)
          : st;
    });
    final index = students.length;
    testCols.forEach((i, t) {
      final v = _number(at(i));
      if (v != null && v >= 0 && v <= t.max) marks[i]!['$index'] = v;
    });

    students.add({
      'name': name.length > 100 ? name.substring(0, 100) : name,
      'fatherName': at(col('FATHER_NAME')),
      'contact': cleaned.length > 1 ? cleaned.first : '',
      'parentMobile': cleaned.isEmpty ? '' : cleaned.last,
      'rollNo': at(col('ROLL_NUMBER')),
      'email': email,
      'totalFees': total,
      'feesDueDate': cleanDate(at(col('DUE_DATE'))),
      'payments': payments,
      'attendance': attendance,
    });
  }
  if (photos > 0) {
    warnings.add(
      'Photos are not copied ($photos student(s) had one) — add them again in Kaksha.',
    );
  }
  warnings.add(
    'Date of birth is not in Teachers App files — add it in Kaksha for birthday wishes.',
  );
  return ClassImport(
    source: 'Teachers App',
    students: students,
    tests: [
      for (final e in testCols.entries)
        if (marks[e.key]!.isNotEmpty)
          {
            'subject': e.value.subject,
            'maxMarks': e.value.max,
            'marks': marks[e.key],
          },
    ],
    warnings: warnings.toList(),
  );
}

/// Kaksha's own "Export to Excel": Roll No, Name, Father's name, Contact,
/// Parent's mobile, Email, Date of birth, Status, [Total fees, Paid, Due,
/// Fees due date], then one column per test ("Subject (/Max)").
ClassImport _kaksha(List<String> header, List<List<String>> rows) {
  int col(String name) => header.indexOf(name);
  final testCols = <int, ({String subject, double max})>{};
  for (var i = 0; i < header.length; i++) {
    final m = RegExp(r'^(.*)\(/\s*(\d+(?:\.\d+)?)\)\s*$').firstMatch(header[i]);
    if (m != null) {
      testCols[i] = (subject: m[1]!.trim(), max: double.parse(m[2]!));
    }
  }
  final students = <Map<String, dynamic>>[];
  final marks = {for (final i in testCols.keys) i: <String, double?>{}};
  for (final r in rows) {
    String at(int i) => i >= 0 && i < r.length ? r[i].trim() : '';
    final name = at(col('Name'));
    if (name.isEmpty) continue;
    final paid = _number(at(col('Paid'))) ?? 0;
    final index = students.length;
    testCols.forEach((i, t) {
      final v = at(i);
      if (v.toLowerCase() == 'absent') {
        marks[i]!['$index'] = null;
      } else if (_number(v) case final n? when n >= 0 && n <= t.max) {
        marks[i]!['$index'] = n;
      }
    });
    final email = at(col('Email'));
    students.add({
      'name': name,
      'fatherName': at(col("Father's name")),
      'contact': cleanMobile(at(col('Contact'))) ?? '',
      'parentMobile': cleanMobile(at(col("Parent's mobile"))) ?? '',
      'rollNo': at(col('Roll No')),
      'email': _emailRe.hasMatch(email) ? email : '',
      'dateOfBirth': cleanDate(at(col('Date of birth'))),
      'totalFees': _number(at(col('Total fees'))) ?? 0,
      'feesDueDate': cleanDate(at(col('Fees due date'))),
      'payments': [
        if (paid > 0) {'amount': paid, 'paidAt': null},
      ],
      'attendance': <String, String>{},
    });
  }
  return ClassImport(
    source: 'Kaksha',
    students: students,
    tests: [
      for (final e in testCols.entries)
        if (marks[e.key]!.isNotEmpty)
          {
            'subject': e.value.subject,
            'maxMarks': e.value.max,
            'marks': marks[e.key],
          },
    ],
    warnings: [
      'Kaksha files have no attendance history; payments come in as one amount.',
    ],
  );
}
