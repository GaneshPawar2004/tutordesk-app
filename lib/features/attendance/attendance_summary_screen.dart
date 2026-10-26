import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../messaging/batch_detail_screen.dart';
import 'class_attendance_screen.dart';
import 'notify_parents_screen.dart';

/// Locked result of a saved attendance session.
class AttendanceSummaryScreen extends StatefulWidget {
  const AttendanceSummaryScreen({
    super.key,
    required this.sessionId,
    this.justSaved = false,
  });

  final String sessionId;
  final bool justSaved;

  @override
  State<AttendanceSummaryScreen> createState() =>
      _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  AttendanceStatus? _filter;

  @override
  void initState() {
    super.initState();
    if (widget.justSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppToast.show(context, 'Attendance saved and locked');
      });
    }
  }

  Future<void> _correct() async {
    final app = context.appRead;
    final session = app.attendance.byId(widget.sessionId)!;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Correct a locked session?',
      message:
          'Only use this to fix a genuine mistake. You will be asked for a reason, '
          'which is stored with your name in the audit trail.',
      confirmLabel: 'Continue',
      icon: Icons.edit_note_rounded,
    );
    if (ok && mounted) {
      pushPage(
        context,
        ClassAttendanceScreen(
          classId: session.classId,
          correctSessionId: session.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = app.attendance.byId(widget.sessionId)!;
    final cls = app.academic.classById(session.classId);
    final batch = app.messaging.bySource(app.attendanceSourceKey(session));
    final entries =
        session.records.entries
            .map((e) => (app.students.tryById(e.key), e.value))
            .where((e) => e.$1 != null)
            .map((e) => (e.$1!, e.$2))
            .toList()
          ..sort((a, b) => a.$1.fullName.compareTo(b.$1.fullName));
    final shown = _filter == null
        ? entries
        : entries.where((e) => e.$2 == _filter).toList();
    final attended = session.presentCount + session.lateCount;
    final percent = session.total == 0 ? 0.0 : attended * 100 / session.total;

    return AppScaffold(
      title: '${cls.name} attendance',
      subtitle: Fmt.longDate(session.date),
      actions: [
        if (app.isAdmin)
          IconButton(
            tooltip: 'Correct attendance',
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: _correct,
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DemoNotice(
                  icon: Icons.lock_outline_rounded,
                  color: AppColors.success,
                  text:
                      'Locked · marked by ${session.markedBy} at ${Fmt.time(session.markedAt)}. '
                      'Everyone opening this class today sees this saved session.',
                ),
                const SizedBox(height: Gap.md),
                CreamCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ATTENDANCE',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.textOnCreamMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  Fmt.percent(percent),
                                  style: AppTextStyles.display.copyWith(
                                    color: AppColors.textOnCream,
                                    fontFeatures: AppTextStyles.tabular,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$attended / ${session.total}\npresent',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textOnCream,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Gap.md),
                      Row(
                        children: [
                          Expanded(
                            child: StatBlock(
                              label: 'Present',
                              value: '${session.presentCount}',
                              onCream: true,
                            ),
                          ),
                          Expanded(
                            child: StatBlock(
                              label: 'Absent',
                              value: '${session.absentCount}',
                              onCream: true,
                            ),
                          ),
                          Expanded(
                            child: StatBlock(
                              label: 'Late / leave',
                              value:
                                  '${session.lateCount + session.leaveCount}',
                              onCream: true,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Gap.md),
                _NotifyCard(sessionId: session.id, batchId: batch?.id),
                if (session.audit.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Audit trail',
                    padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
                  ),
                  for (final a in session.audit)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.history_edu_rounded,
                              size: 20,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.note,
                                    style: AppTextStyles.body.copyWith(
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${a.by} · ${Fmt.dateTime(a.at)}',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (!app.isAdmin) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Need a correction? Ask the admin — locked sessions can only be changed with an audit note.',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SectionHeader(title: 'Student-wise results'),
          FilterChips(
            children: [
              ChoiceChip(
                label: Text('All ${session.total}'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final s in AttendanceStatus.values)
                ChoiceChip(
                  label: Text('${s.label} ${session.count(s)}'),
                  selected: _filter == s,
                  onSelected: (_) =>
                      setState(() => _filter = _filter == s ? null : s),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.filter_alt_off_outlined,
              title: 'Nobody here',
              message: 'No students have this status.',
            )
          else
            for (final (student, status) in shown)
              StudentListTile(
                student: student,
                className: cls.name,
                showParent: false,
                trailing: AttendanceStatusChip(status: status),
              ),
        ],
      ),
    );
  }
}

class _NotifyCard extends StatelessWidget {
  const _NotifyCard({required this.sessionId, required this.batchId});

  final String sessionId;
  final String? batchId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final batch = batchId == null ? null : app.messaging.byId(batchId!);
    final canSend = app.canSendMessages;

    return SurfaceCard(
      borderColor: batch == null && canSend
          ? AppColors.accent
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(
                icon: batch == null
                    ? Icons.campaign_outlined
                    : Icons.mark_chat_read_outlined,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch == null ? 'Notify parents' : 'Parents notified',
                      style: AppTextStyles.titleSmall,
                    ),
                    Text(
                      batch == null
                          ? 'Preview and queue attendance messages for this session.'
                          : '${batch.sent} sent · ${batch.failed} failed · ${batch.pending} pending',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (batch != null)
            SecondaryButton(
              label: 'View message status',
              icon: Icons.track_changes_rounded,
              onPressed: () =>
                  pushPage(context, BatchDetailScreen(batchId: batch.id)),
            )
          else if (canSend)
            PrimaryButton(
              label: 'Notify parents',
              icon: Icons.send_rounded,
              onPressed: () =>
                  pushPage(context, NotifyParentsScreen(sessionId: sessionId)),
            )
          else
            Text(
              'Sending messages is not enabled for your account.',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            ),
        ],
      ),
    );
  }
}
