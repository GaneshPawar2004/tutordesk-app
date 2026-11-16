import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import 'collect_fee_dialog.dart';

class FeesView extends StatefulWidget {
  const FeesView({
    super.key,
    required this.schoolClass,
    required this.onBack,
    required this.bottomBar,
  });

  final SchoolClass schoolClass;
  final VoidCallback onBack;
  final Widget bottomBar;

  @override
  State<FeesView> createState() => _FeesViewState();
}

class _FeesViewState extends State<FeesView> {
  bool _hideAmounts = false;
  bool _searching = false;
  bool _onlyDue = false;
  String _query = '';

  void _smsFeeReminders() {
    final due = appState
        .studentsOf(widget.schoolClass.id, includeDisabled: false)
        .where((s) => s.feesDue > 0)
        .toList();
    if (due.isEmpty) {
      showInfo(context, 'No pending fees in this class.');
      return;
    }
    showSmsSheet(
      context,
      title: 'SMS fee reminders (${due.length})',
      kind: 'fees',
      // Once per student per day: tapping again does not remind twice.
      dedupeKey:
          'fees:${widget.schoolClass.id}:${AppState.dateKey(DateTime.now())}',
      listTitle:
          '${widget.schoolClass.name} · Fee reminders ${formatDate(DateTime.now())}',
      classId: widget.schoolClass.id,
      items: [
        for (final s in due)
          SmsItem(
            studentId: s.id,
            name: s.name,
            number: parentNumber(s),
            message:
                'Dear Parent, fees of ${formatMoney(s.feesDue)} are pending '
                'for ${s.name} (${widget.schoolClass.name})'
                '${s.feesDueDate == null ? '' : ', due by ${formatDate(s.feesDueDate)}'}'
                '. Please pay at the earliest.',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    if (!appState.canAccessFees) {
      // The server sends no fee amounts to staff without fee access.
      return Scaffold(
        bottomNavigationBar: widget.bottomBar,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBack,
          ),
          title: Text('Fees : ${c.name}'),
        ),
        body: const EmptyState(
          icon: Icons.lock_outline,
          message:
              'You do not have access to fees.\nAsk the admin to turn on "Can access Fees" for your login.',
        ),
      );
    }
    return Scaffold(
      bottomNavigationBar: widget.bottomBar,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_searching) {
              setState(() {
                _searching = false;
                _query = '';
              });
            } else {
              widget.onBack();
            }
          },
        ),
        title: _searching
            ? SearchTitleField(
                hint: 'Search students…',
                onChanged: (v) => setState(() => _query = v),
              )
            : Text('Fees : ${c.name}'),
        actions: [
          IconButton(
            tooltip: _hideAmounts ? 'Show amounts' : 'Hide amounts',
            icon: Icon(
              _hideAmounts
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 21,
            ),
            onPressed: () => setState(() => _hideAmounts = !_hideAmounts),
          ),
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search, size: 21),
              onPressed: () => setState(() => _searching = true),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'due') setState(() => _onlyDue = !_onlyDue);
              if (v == 'remind') _smsFeeReminders();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'due',
                checked: _onlyDue,
                child: const Text('Show only dues'),
              ),
              const PopupMenuItem(
                value: 'remind',
                child: Text('SMS fee reminders'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final all = appState.studentsOf(c.id);
          final students = all
              .where(
                (s) =>
                    s.name.toLowerCase().contains(_query.toLowerCase()) &&
                    (!_onlyDue || s.feesDue > 0),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              FeeSummaryCard(
                collected: appState.collectedFeesOf(c.id),
                total: appState.totalFeesOf(c.id),
                due: appState.dueFeesOf(c.id),
                hidden: _hideAmounts,
              ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 45),
                  child: EmptyState(
                    icon: Icons.payments_outlined,
                    message: 'No students in this class yet.',
                  ),
                ),
              for (final s in students) ...[
                FeeStudentTile(
                  student: s,
                  hidden: _hideAmounts,
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

class FeeSummaryCard extends StatelessWidget {
  const FeeSummaryCard({
    super.key,
    required this.collected,
    required this.total,
    required this.due,
    this.hidden = false,
  });

  final double collected;
  final double total;
  final double due;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    Widget col(String label, double value, Color color) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 3),
          FittedBox(
            child: Text(
              hidden ? '₹ ••••' : formatMoney(value),
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 16),
        child: Row(
          children: [
            col('Collected', collected, AppColors.success),
            col('Total', total, AppColors.textDark),
            col('Due', due, AppColors.danger),
          ],
        ),
      ),
    );
  }
}

class FeeStudentTile extends StatelessWidget {
  const FeeStudentTile({
    super.key,
    required this.student,
    required this.onTap,
    this.subtitle,
    this.hidden = false,
  });

  final Student student;
  final VoidCallback onTap;
  final String? subtitle;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final due = student.feesDue;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                        children: [
                          const TextSpan(text: 'Fees Due: '),
                          TextSpan(
                            text: hidden ? '••••' : formatMoney(due),
                            style: TextStyle(
                              color: due > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (student.feesDueDate != null && due > 0)
                            TextSpan(
                              text:
                                  '  ·  by ${formatDate(student.feesDueDate)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (due <= 0 && student.totalFees > 0)
                const Icon(Icons.check_circle, color: AppColors.success),
            ],
          ),
        ),
      ),
    );
  }
}
