import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
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
    if (await runApi(context, () => appState.collectFee(s, amount)) &&
        context.mounted) {
      showSuccess(context, '${formatMoney(amount)} collected from ${s.name}');
    }
  }
}
