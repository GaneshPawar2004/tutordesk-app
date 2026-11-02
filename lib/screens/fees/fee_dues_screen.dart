import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../widgets/common.dart';
import 'collect_fee_dialog.dart';
import 'fees_view.dart';

/// All pending fees across every class (dashboard "Fee Dues").
class FeeDuesScreen extends StatelessWidget {
  const FeeDuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fee Dues')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final due = appState.students.where((s) => s.feesDue > 0).toList()
            ..sort((a, b) {
              final ad = a.feesDueDate, bd = b.feesDueDate;
              if (ad == null && bd == null) {
                return b.feesDue.compareTo(a.feesDue);
              }
              if (ad == null) return 1;
              if (bd == null) return -1;
              return ad.compareTo(bd);
            });
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FeeSummaryCard(
                collected: appState.collectedFeesOf(null),
                total: appState.totalFeesOf(null),
                due: appState.dueFeesOf(null),
              ),
              const SizedBox(height: 12),
              if (due.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 45),
                  child: EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'No pending fees. 🎉',
                  ),
                ),
              for (final s in due) ...[
                FeeStudentTile(
                  student: s,
                  subtitle: appState.classById(s.classId)?.name,
                  onTap: () => showCollectFeeDialog(context, s),
                ),
                const SizedBox(height: 9),
              ],
            ],
          );
        },
      ),
    );
  }
}
