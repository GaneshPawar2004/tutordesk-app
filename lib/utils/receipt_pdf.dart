import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/app_state.dart';
import '../data/models.dart';
import 'format.dart';

pw.ThemeData? _theme;

/// Noto Sans (bundled) — the built-in PDF fonts have no ₹ sign.
Future<pw.ThemeData> _pdfTheme() async => _theme ??= pw.ThemeData.withFont(
  base: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
  bold: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
);

String _money(num v) => formatMoney(v);

/// A one-page A5 fee receipt for [payment] of [student].
Future<Uint8List> buildReceiptPdf(Student student, FeePayment payment) async {
  final theme = await _pdfTheme();
  final logo = await appState.logoBytes();
  final className = appState.classById(student.classId)?.name ?? '';
  final inst = appState.instituteName;
  const blue = PdfColor.fromInt(0xFF1A73E8);
  const muted = PdfColor.fromInt(0xFF5F6368);

  pw.Widget row(String label, String value, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 3),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(label, style: const pw.TextStyle(color: muted)),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null),
        ),
      ],
    ),
  );

  final doc = pw.Document(theme: theme, title: 'Fee receipt');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 56,
                  height: 56,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(
                    pw.MemoryImage(Uint8List.fromList(logo)),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      inst.isEmpty ? 'Fee receipt' : inst,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: blue,
                      ),
                    ),
                    if (appState.instituteAddress.isNotEmpty)
                      pw.Text(
                        appState.instituteAddress,
                        style: const pw.TextStyle(fontSize: 9, color: muted),
                      ),
                    if (appState.institutePhone.isNotEmpty)
                      pw.Text(
                        'Phone: ${appState.institutePhone}',
                        style: const pw.TextStyle(fontSize: 9, color: muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: blue, thickness: 1.5),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'FEE RECEIPT',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'No. ${payment.receiptNo ?? payment.id.substring(0, 8).toUpperCase()}',
              ),
            ],
          ),
          pw.Text(
            'Date: ${formatDate(payment.paidAt)}',
            style: const pw.TextStyle(color: muted),
          ),
          pw.SizedBox(height: 14),
          row('Student', student.name, bold: true),
          if (className.isNotEmpty) row('Class', className),
          if (student.rollNo.isNotEmpty) row('Roll No', student.rollNo),
          if (student.fatherName.isNotEmpty)
            row("Father's name", student.fatherName),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFE8F0FE),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Amount received',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Text(
                  _money(payment.amount),
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: blue,
                  ),
                ),
              ],
            ),
          ),
          if (payment.note.isNotEmpty) row('Note', payment.note),
          pw.SizedBox(height: 10),
          if (student.hasMonthlyFee)
            row(
              'Monthly fee',
              '${_money(student.monthlyFee)} × ${student.monthsBilled} month(s)',
            ),
          row('Total fees', _money(student.totalFees)),
          row('Paid so far', _money(student.feesPaid)),
          row('Balance due', _money(student.feesDue), bold: true),
          pw.Spacer(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                payment.collectedBy.isEmpty
                    ? ''
                    : 'Received by ${payment.collectedBy}',
                style: const pw.TextStyle(fontSize: 9, color: muted),
              ),
              pw.Text(
                'Generated with Kaksha',
                style: const pw.TextStyle(fontSize: 8, color: muted),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

String _fileName(Student s, FeePayment p) =>
    'Receipt-${p.receiptNo ?? ''}-${s.name.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf';

/// Opens the share sheet with the receipt PDF (WhatsApp, email, save…).
Future<void> shareReceiptPdf(Student s, FeePayment p) async =>
    Printing.sharePdf(
      bytes: await buildReceiptPdf(s, p),
      filename: _fileName(s, p),
    );

/// Opens the phone's print screen (printer or "Save as PDF").
Future<void> printReceiptPdf(Student s, FeePayment p) async =>
    Printing.layoutPdf(
      name: _fileName(s, p),
      format: PdfPageFormat.a5,
      onLayout: (_) => buildReceiptPdf(s, p),
    );
