import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/message_templates.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../messaging/batch_detail_screen.dart';
import '../messaging/message_widgets.dart';

enum _Audience {
  absent('Absent & leave', {AttendanceStatus.absent, AttendanceStatus.leave}),
  exceptions('Absent, late & leave', {
    AttendanceStatus.absent,
    AttendanceStatus.late,
    AttendanceStatus.leave,
  }),
  everyone('All parents', {...AttendanceStatus.values});

  const _Audience(this.label, this.statuses);
  final String label;
  final Set<AttendanceStatus> statuses;
}

/// Message preview for an attendance session. Only one batch can ever be
/// created per session; afterwards the send button is disabled.
class NotifyParentsScreen extends StatefulWidget {
  const NotifyParentsScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<NotifyParentsScreen> createState() => _NotifyParentsScreenState();
}

class _NotifyParentsScreenState extends State<NotifyParentsScreen> {
  var _audience = _Audience.absent;
  final _excluded = <String>{};
  var _sending = false;

  Future<void> _send(int count) async {
    if (_sending) return;
    final app = context.appRead;
    final session = app.attendance.byId(widget.sessionId)!;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Send to ${Fmt.plural(count, 'parent')}?',
      message:
          'Messages are queued on the sending device. This is a demo — no SMS is actually sent.',
      confirmLabel: 'Send messages',
      icon: Icons.send_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final result = app.notifyAttendance(
      session,
      _audience.statuses,
      excludeStudentIds: _excluded,
    );
    if (!result.created) {
      AppToast.show(
        context,
        'A batch already exists for this session — nothing was resent.',
        type: ToastType.warning,
      );
    }
    replacePage(context, BatchDetailScreen(batchId: result.batch.id));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = app.attendance.byId(widget.sessionId)!;
    final cls = app.academic.classById(session.classId);
    final existing = app.messaging.bySource(app.attendanceSourceKey(session));
    final candidates =
        session.records.entries
            .where((e) => _audience.statuses.contains(e.value))
            .map((e) => (app.students.tryById(e.key), e.value))
            .where((e) => e.$1 != null)
            .map((e) => (e.$1!, e.$2))
            .toList()
          ..sort((a, b) => a.$1.fullName.compareTo(b.$1.fullName));
    final selected = candidates
        .where((c) => !_excluded.contains(c.$1.id))
        .toList();
    final statusesInSelection = selected.map((s) => s.$2).toSet();
    final canSend =
        app.canSendMessages && existing == null && selected.isNotEmpty;

    return AppScaffold(
      title: 'Notify parents',
      subtitle: '${cls.name} · ${Fmt.shortDate(session.date)}',
      bottomBar: existing != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Already sent for this session. Duplicate sending is blocked.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'View message status',
                  onPressed: () => replacePage(
                    context,
                    BatchDetailScreen(batchId: existing.id),
                  ),
                ),
              ],
            )
          : PrimaryButton(
              label: 'Send to ${Fmt.plural(selected.length, 'parent')}',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: canSend ? () => _send(selected.length) : null,
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          const SmsDemoBanner(),
          const SizedBox(height: Gap.md),
          const FieldLabel('Message type'),
          SegmentedChoice<_Audience>(
            options: [
              for (final a in _Audience.values) SelectOption(a, a.label),
            ],
            value: _audience,
            onChanged: (a) => setState(() {
              _audience = a;
              _excluded.clear();
            }),
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              Expanded(
                child: StatBlock(
                  label: 'Recipients',
                  value: '${candidates.length}',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Selected',
                  value: '${selected.length}',
                ),
              ),
              Expanded(
                child: StatBlock(
                  label: 'Est. SMS',
                  value: '${selected.length}',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SectionHeader(
            title: 'Message preview',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
          ),
          if (statusesInSelection.isEmpty)
            Text(
              'Select at least one recipient to preview the message.',
              style: AppTextStyles.caption,
            )
          else
            for (final status in AttendanceStatus.values.where(
              statusesInSelection.contains,
            )) ...[
              Text(
                '${status.label.toUpperCase()} TEMPLATE',
                style: AppTextStyles.label.copyWith(
                  color: attendanceColor(status),
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(height: 6),
              MessageBubble(
                text: MessageTemplates.attendance(
                  status,
                  '[Student Name]',
                  app.tuition.name,
                ),
              ),
              const SizedBox(height: 12),
            ],
          SectionHeader(
            title: 'Recipients',
            padding: const EdgeInsets.only(top: Gap.md, bottom: 4),
            actionLabel: _excluded.isEmpty ? 'Deselect all' : 'Select all',
            onAction: () => setState(() {
              if (_excluded.isEmpty) {
                _excluded.addAll(candidates.map((c) => c.$1.id));
              } else {
                _excluded.clear();
              }
            }),
          ),
          if (candidates.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.celebration_outlined,
              title: 'Nobody to notify',
              message:
                  'No students match this message type. Try "All parents".',
            )
          else
            for (final (student, status) in candidates)
              CheckboxListTile(
                value: !_excluded.contains(student.id),
                onChanged: existing != null
                    ? null
                    : (v) => setState(() {
                        if (v ?? false) {
                          _excluded.remove(student.id);
                        } else {
                          _excluded.add(student.id);
                        }
                      }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  student.fullName,
                  style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                ),
                subtitle: Text(
                  '${student.parentName} · ${Fmt.phoneSuffix(student.parentPhone)}',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
                secondary: AttendanceStatusChip(status: status),
              ),
        ],
      ),
    );
  }
}
