import 'package:flutter_test/flutter_test.dart';
import 'package:teachers_app/data/models.dart';
import 'package:teachers_app/utils/format.dart';
import 'package:teachers_app/utils/receipt_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
