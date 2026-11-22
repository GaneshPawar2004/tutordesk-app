import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:teachers_app/data/models.dart';
import 'package:teachers_app/utils/export.dart';
import 'package:teachers_app/utils/format.dart';
import 'package:teachers_app/utils/import_csv.dart';
import 'package:teachers_app/utils/receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  exportTests();

  test('formatMonth', () {
    expect(formatMonth('2026-08'), 'Aug 2026');
    expect(formatMonth('2025-12'), 'Dec 2025');
    expect(formatMonth(null), '');
    expect(formatMonth('bad'), '');
  });

  test('student with monthly fee parses both parts', () {
    final s = Student.fromJson({
      'id': 's1',
      'class': 'c1',
      'name': 'Asha',
      'totalFees': 3500,
      'oneTimeFees': 500,
      'monthlyFee': 1000,
      'feeStart': '2026-09',
      'monthsBilled': 3,
      'feesPaid': 1500,
    });
    expect(s.hasMonthlyFee, isTrue);
    expect(s.oneTimeFees, 500);
    expect(s.totalFees, 3500);
    expect(s.feesDue, 2000);
    expect(s.monthsBilled, 3);
  });

  test('student without monthly fee', () {
    final s = Student.fromJson({
      'id': 's1',
      'class': 'c1',
      'name': 'Asha',
      'totalFees': 3000,
    });
    expect(s.hasMonthlyFee, isFalse);
    expect(s.oneTimeFees, 3000);
  });

  test('receipt PDF builds (with ₹ font)', () async {
    final s = Student.fromJson({
      'id': 's1',
      'class': 'c1',
      'name': 'Asha',
      'rollNo': '4',
      'totalFees': 3500,
      'oneTimeFees': 500,
      'monthlyFee': 1000,
      'feeStart': '2026-09',
      'monthsBilled': 3,
      'feesPaid': 1500,
    });
    final p = FeePayment.fromJson({
      'id': 'p1',
      'amount': 1500,
      'paidAt': '2026-11-20',
      'receiptNo': 7,
      'collectedBy': 'Ganesh',
    });
    final bytes = await buildReceiptPdf(s, p);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });
}

void exportTests() {
  test('class export uses the Teachers App format and imports back', () {
    final ravi = Student.fromJson({
      'id': 'r',
      'class': 'c',
      'name': 'Ravi Kumar',
      'rollNo': '1',
      'contact': '9876500001',
      'parentMobile': '9876500002',
      'fatherName': 'Suresh',
      'totalFees': 12000,
      'feesPaid': 5000,
      'feesDueDate': '2026-11-30',
    });
    final sita = Student.fromJson({
      'id': 's',
      'class': 'c',
      'name': 'Sita, Sharma',
      'rollNo': '2',
      'parentMobile': '9876500003',
      'totalFees': 10000,
    });
    final maths = ClassTest.fromJson({
      'id': 't',
      'class': 'c',
      'subject': 'Maths',
      'maxMarks': 50,
      'marks': [
        {'student': 'r', 'marks': 40},
      ],
    });
    final csv = buildClassCsv(
      students: [ravi, sita],
      tests: [maths],
      attendance: {
        '2026-11-21': {'r': 'present', 's': 'Sick'},
        '2026-11-22': {'r': 'present', 's': 'absent'},
      },
      payments: {
        'r': [(date: '2026-11-22', amount: 5000)],
      },
    );
    final lines = csv.split('\r\n');
    expect(
      lines[0],
      'NAME,MARKS,CONTACT,STATUS,ROLL_NUMBER,FATHER_NAME,EMAIL,FEES_PAID,'
      'TOTAL_FEES,FEES_DUE,IMAGE_PATH,DUE_DATE,21-11-2026,22-11-2026,Maths/50',
    );
    expect(
      lines[1],
      'Ravi Kumar,40,9876500001;9876500002,Present,1,Suresh,,'
      '22/11/2026 5000,12000,7000,,30/11/2026,Present,Present,40',
    );

    final imp = parseClassFile(utf8.encode(csv));
    expect(imp.source, 'Teachers App');
    expect(imp.students, hasLength(2));
    expect(imp.students[0]['payments'], [
      {'amount': 5000.0, 'paidAt': '2026-11-22'},
    ]);
    expect(imp.students[1]['name'], 'Sita, Sharma');
    expect(imp.students[1]['attendance'], {
      '2026-11-21': 'Sick',
      '2026-11-22': 'absent',
    });
  });

  test('fees start date helpers', () {
    expect(parseFeeStart('2026-09-15'), DateTime(2026, 9, 15));
    expect(parseFeeStart('2026-09'), DateTime(2026, 9, 1));
    expect(parseFeeStart(null), isNull);
    expect(formatFeeStart('2026-09-15'), '15-09-2026');
    expect(formatFeeStart('2026-09'), 'Sep 2026');
  });
}
