import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../fees/collect_fee_dialog.dart';
import 'student_form_dialog.dart';
import 'students_view.dart';

/// Full student profile: details, fees, attendance and test results.
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.schoolClass,
  });

  final Student student;
  final SchoolClass schoolClass;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showStudentFormDialog(
              context,
              schoolClass: schoolClass,
              student: student,
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final s = student;
          final history = appState.attendanceHistoryOf(s);
          final present = history
              .where((e) => e.value == AttendanceStatus.present)
              .length;
          final tests = appState
              .testsOf(s.classId)
              .where((t) => t.marks[s.id]?.marks != null)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Center(
                child: StudentAvatar(
                  radius: 36,
                  disabled: s.disabled,
                  student: s,
                ),
              ),
              const SizedBox(height: 9),
              Center(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Center(
                child: Text(
                  '${schoolClass.name}${s.rollNo.isEmpty ? '' : ' · Roll ${s.rollNo}'}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              _Section(
                title: 'Details',
                children: [
                  _Row("Father's name", s.fatherName),
                  _Row('Contact', s.contact),
                  _Row("Parent's mobile", s.parentMobile),
                  _Row('Email', s.email),
                  _Row('Date of birth', formatDate(s.dateOfBirth)),
                  _Row('Status', s.disabled ? 'Disabled' : 'Active'),
                ],
              ),
              if (appState.canAccessFees)
                _Section(
                  title: 'Fees',
                  trailing: TextButton(
                    onPressed: () => showCollectFeeDialog(context, s),
                    child: const Text('COLLECT'),
                  ),
                  children: [
                    _Row('Total fees', formatMoney(s.totalFees)),
                    _Row('Paid', formatMoney(s.feesPaid)),
                    _Row(
                      'Due',
                      formatMoney(s.feesDue),
                      valueColor: s.feesDue > 0
                          ? AppColors.danger
                          : AppColors.success,
                    ),
                    _Row('Due date', formatDate(s.feesDueDate)),
                    // Reloads whenever a payment changes feesPaid.
                    _PaymentHistory(key: ValueKey(s.feesPaid), student: s),
                  ],
                ),
              _Section(
                title: 'Attendance',
                children: [
                  _Row('Days recorded', '${history.length}'),
                  _Row(
                    'Present',
                    history.isEmpty
                        ? '—'
                        : '$present (${(present * 100 / history.length).round()}%)',
                  ),
                  for (final e in history.take(10))
                    _Row(
                      formatDate(e.key),
                      e.value.label,
                      valueColor: _statusColor(e.value),
                    ),
                ],
              ),
              _Section(
                title: 'Test Results',
                children: [
                  if (tests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        'No marks recorded yet.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  for (final t in tests)
                    _Row(
                      t.subject,
                      '${_num(t.marks[s.id]!.marks!)} / ${_num(t.maxMarks)}',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static Color _statusColor(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.absent => AppColors.danger,
    AttendanceStatus.leave => AppColors.warning,
    AttendanceStatus.others => AppColors.textMuted,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 9, 15, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Past fee payments of a student, each with a "send receipt" button.
class _PaymentHistory extends StatefulWidget {
  const _PaymentHistory({super.key, required this.student});
  final Student student;

  @override
  State<_PaymentHistory> createState() => _PaymentHistoryState();
}

class _PaymentHistoryState extends State<_PaymentHistory> {
  late final Future<List<FeePayment>> _payments = appState.loadPayments(
    widget.student,
  );

  /// Removes a wrong payment (the list reloads because feesPaid changes).
  Future<void> _delete(FeePayment p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete payment?',
      message:
          '${formatMoney(p.amount)} paid on ${formatDate(p.paidAt)} will be removed '
          'and added back to the due amount.',
    );
    if (!ok || !mounted) return;
    if (await runApi(
          context,
          () => appState.deletePayment(widget.student, p),
        ) &&
        mounted) {
      showSuccess(context, 'Payment deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeePayment>>(
      future: _payments,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final list = snap.data ?? const <FeePayment>[];
        if (snap.hasError || list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              snap.hasError
                  ? 'Could not load payment history.'
                  : 'No payments yet.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 2),
              child: Text(
                'Payment history',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (final p in list)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatDate(p.paidAt)}  ·  ${formatMoney(p.amount)}'
                      '${p.collectedBy.isEmpty ? '' : '  ·  ${p.collectedBy}'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send receipt',
                    icon: const Icon(Icons.receipt_long_outlined, size: 20),
                    onPressed: () => sendReceipt(
                      context,
                      widget.student,
                      amount: p.amount,
                      paidAt: p.paidAt,
                    ),
                  ),
                  if (appState.isOwner)
                    IconButton(
                      tooltip: 'Delete payment',
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.danger,
                      ),
                      onPressed: () => _delete(p),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
