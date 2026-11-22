import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teachers_app/utils/import_csv.dart';

/// Exactly what Teachers App's "Export Class Data (CSV)" writes (BOM, CRLF,
/// columns from its export code), for the sample Class 8.
const teachersAppCsv =
    '﻿NAME,MARKS,CONTACT,STATUS,ROLL_NUMBER,FATHER_NAME,EMAIL,FEES_PAID,TOTAL_FEES,FEES_DUE,IMAGE_PATH,DUE_DATE,21-11-2026,22-11-2026,Maths/50\r\n'
    'Ravi Kumar,40,9876500001;9876500002,Present,1,Suresh Kumar,ravi@example.com,22/11/2026 5000,12000,7000,,30/11/2026,Present,Present,40\r\n'
    'Sita Sharma,35,9876500003,Absent,2,,,,10000,10000,https://web.teachersapp.in/p/1.jpg,,Present,Absent,35\r\n'
    '"Das, Mohan",,+91 98765 00004,Leave,3,,not-an-email,,0,0,,,,Leave,';

void main() {
  test('reads a Teachers App class export', () {
    final imp = parseClassFile(utf8.encode(teachersAppCsv));
    expect(imp.source, 'Teachers App');
    expect(imp.students, hasLength(3));

    final ravi = imp.students[0];
    expect(ravi['name'], 'Ravi Kumar');
    expect(ravi['contact'], '9876500001');
    expect(ravi['parentMobile'], '9876500002');
    expect(ravi['rollNo'], '1');
    expect(ravi['fatherName'], 'Suresh Kumar');
    expect(ravi['totalFees'], 12000);
    expect(ravi['feesDueDate'], '2026-11-30');
    expect(ravi['payments'], [
      {'amount': 5000.0, 'paidAt': '2026-11-22'},
    ]);
    expect(ravi['attendance'], {
      '2026-11-21': 'present',
      '2026-11-22': 'present',
    });

    // One number → it is the parent's; +91 and spaces are cleaned.
    expect(imp.students[1]['parentMobile'], '9876500003');
    expect(imp.students[1]['contact'], '');
    final mohan = imp.students[2];
    expect(mohan['name'], 'Das, Mohan');
    expect(mohan['parentMobile'], '9876500004');
    expect(mohan['email'], '');
    expect(mohan['attendance'], {'2026-11-22': 'leave'});

    expect(imp.tests, [
      {
        'subject': 'Maths',
        'maxMarks': 50.0,
        'marks': {'0': 40.0, '1': 35.0},
      },
    ]);
    expect(imp.attendanceDays, 2);
    expect(imp.paymentCount, 1);
    expect(imp.warnings.join(' '), contains('Photos are not copied (1'));
    expect(imp.warnings.join(' '), contains('emails were not valid'));
  });

  test('reads a Kaksha export', () {
    const csv =
        '﻿Roll No,Name,Father\'s name,Contact,Parent\'s mobile,Email,Date of birth,Status,Total fees,Paid,Due,Fees due date,Maths (/50)\r\n'
        '1,Asha,Ramesh,,9822222222,,05-06-2015,Active,15000,5000,10000,30-11-2026,42\r\n'
        '2,Ravi,,,,,,Active,0,0,0,,Absent';
    final imp = parseClassFile(utf8.encode(csv));
    expect(imp.source, 'Kaksha');
    expect(imp.students[0]['dateOfBirth'], '2015-06-05');
    expect(imp.students[0]['payments'], [
      {'amount': 5000.0, 'paidAt': null},
    ]);
    expect(imp.tests.single['marks'], {'0': 42.0, '1': null});
  });

  test('reads a real export from Teachers App (Class_8.csv)', () {
    final imp = parseClassFile(
      File('test/fixtures/teachers_app_class_8.csv').readAsBytesSync(),
    );
    expect(imp.students.map((s) => s['name']), [
      'Ravi Kumar',
      'Sita Sharma',
      'Mohan Das',
    ]);
    expect(imp.students[0]['payments'], [
      {'amount': 5000.0, 'paidAt': '2026-11-22'},
    ]);
    expect(imp.students[0]['parentMobile'], '9876500002');
    expect(imp.students[1]['attendance'], {'2026-11-22': 'absent'});
    expect(imp.students[2]['attendance'], {'2026-11-22': 'leave'});
    expect(imp.tests.single['marks'], {'0': 40.0, '1': 35.0});
  });

  test('rejects other files', () {
    expect(
      () => parseClassFile(utf8.encode('a,b\n1,2')),
      throwsA(isA<ImportFormatException>()),
    );
  });
}
