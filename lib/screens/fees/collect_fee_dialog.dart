import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../utils/receipt_pdf.dart';
import '../../widgets/common.dart';

/// Records a fee payment for a student.
Future<void> showCollectFeeDialog(BuildContext context, Student s) async {
  if (!appState.canAccessFees) {
    showInfo(context, 'You do not have access to fees.');
    return;
  }
  if (s.totalFees <= 0) {
    showError(context, 'Set total fees for ${s.name} first (Edit student).');
    return;
  }
  if (s.feesDue <= 0) {
    showSuccess(context, '${s.name} has no pending fees.');
    return;
  }

  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final amount = await showDialog<double>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (formKey.currentState!.validate()) {
          Navigator.pop(ctx, double.parse(ctrl.text.trim()));
        }
      }

      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14),
        title: const Text('Collect Fees', style: TextStyle(fontSize: 20)),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Total ${formatMoney(s.totalFees)} · Paid ${formatMoney(s.feesPaid)} · Due ',
                      ),
                      TextSpan(
                        text: formatMoney(s.feesDue),
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                LabeledField(
                  label: 'Amount received (₹)',
                  hint: 'Enter amount',
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    if (n > s.feesDue) {
                      return 'Amount exceeds due (${formatMoney(s.feesDue)})';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => ctrl.text = s.feesDue.toStringAsFixed(
                      s.feesDue % 1 == 0 ? 0 : 2,
                    ),
                    child: const Text('Pay full due'),
                  ),
                ),
                const Divider(height: 18),
                DialogButtons(primaryLabel: 'COLLECT', onPrimary: submit),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (amount != null && context.mounted) {
    final payment = await runApiValue(
      context,
      () => appState.collectFee(s, amount),
    );
    if (payment != null && context.mounted) {
      showSuccess(context, '${formatMoney(amount)} collected from ${s.name}');
      await showReceiptOptions(
        context,
        s,
        payment,
        title: 'Send receipt for ${formatMoney(amount)}?',
      );
    }
  }
}

/// Receipt choices for a payment: PDF (share / print) or SMS/WhatsApp text.
Future<void> showReceiptOptions(
  BuildContext context,
  Student s,
  FeePayment p, {
  String? title,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Text(
              title ??
                  'Receipt ${p.receiptNo == null ? '' : 'No. ${p.receiptNo} '}· ${formatMoney(p.amount)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: AppColors.danger),
            title: const Text('Share PDF receipt'),
            subtitle: const Text('WhatsApp, email or save — with your logo'),
            onTap: () => Navigator.pop(ctx, 'pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Print receipt'),
            onTap: () => Navigator.pop(ctx, 'print'),
          ),
          ListTile(
            leading: const Icon(Icons.sms_outlined, color: AppColors.primary),
            title: const Text('Send as text (SMS / WhatsApp)'),
            onTap: () => Navigator.pop(ctx, 'text'),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Not now'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (choice == 'text') {
    sendReceipt(context, s, amount: p.amount, paidAt: p.paidAt);
    return;
  }
  await runApi(
    context,
    () => choice == 'pdf' ? shareReceiptPdf(s, p) : printReceiptPdf(s, p),
  );
}

/// Text of a fee receipt for a payment of [amount] by [s].
String receiptText(
  Student s, {
  required double amount,
  required DateTime paidAt,
}) {
  final c = appState.classById(s.classId)?.name ?? '';
  final inst = appState.instituteName;
  return 'Fee receipt: received ${formatMoney(amount)} for ${s.name}'
      '${c.isEmpty ? '' : ' ($c)'} on ${formatDate(paidAt)}. '
      'Total paid ${formatMoney(s.feesPaid)} of ${formatMoney(s.totalFees)}, '
      'balance ${formatMoney(s.feesDue)}. Thank you. - ${inst.isEmpty ? 'Kaksha' : inst}';
}

/// Opens the SMS/WhatsApp sheet with the receipt for the parent.
void sendReceipt(
  BuildContext context,
  Student s, {
  required double amount,
  required DateTime paidAt,
}) {
  showSmsSheet(
    context,
    title: 'Fee receipt',
    kind: 'receipt',
    dedupeKey: 'receipt:${s.id}:${paidAt.millisecondsSinceEpoch}',
    listTitle: 'Fee receipt · ${s.name} · ${formatMoney(amount)}',
    classId: s.classId,
    items: [
      SmsItem(
        studentId: s.id,
        name: s.name,
        number: parentNumber(s),
        message: receiptText(s, amount: amount, paidAt: paidAt),
      ),
    ],
  );
}
