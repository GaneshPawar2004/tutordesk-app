import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Attendance & fee summaries per class (screen 26).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          if (appState.classes.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart,
              message: 'No data yet. Add classes and students to see reports.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _Heading('Attendance Summary'),
              for (final c in appState.classes) ...[
                _AttendanceCard(schoolClass: c),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 9),
              const _Heading('Fee Collection Summary'),
              for (final c in appState.classes) ...[
                _FeeCard(schoolClass: c),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.schoolClass});
  final SchoolClass schoolClass;

  @override
  Widget build(BuildContext context) {
    final totals = appState.attendanceTotals(schoolClass.id);
    final sum = totals.values.fold<int>(0, (a, b) => a + b);
    final count = appState.studentsOf(schoolClass.id).length;

    double pct(AttendanceStatus s) => sum == 0 ? 0 : totals[s]! / sum;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${schoolClass.name} ($count students)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (sum == 0)
              const Text(
                'No attendance recorded yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              )
            else ...[
              _Bar('Present', pct(AttendanceStatus.present), AppColors.success),
              _Bar(
                'Absent',
                pct(AttendanceStatus.absent),
                const Color(0xFFF44336),
              ),
              _Bar('Leave', pct(AttendanceStatus.leave), AppColors.warning),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 10,
                color: color,
                backgroundColor: const Color(0xFFF1F1F1),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeeCard extends StatelessWidget {
  const _FeeCard({required this.schoolClass});
  final SchoolClass schoolClass;

  @override
  Widget build(BuildContext context) {
    final id = schoolClass.id;
    final due = appState.dueFeesOf(id);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schoolClass.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total: ${formatMoney(appState.totalFeesOf(id))} | '
                    'Paid: ${formatMoney(appState.collectedFeesOf(id))}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMoney(due),
              style: TextStyle(
                color: due > 0 ? AppColors.danger : AppColors.success,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
