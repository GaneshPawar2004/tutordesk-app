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
import '../messaging/message_widgets.dart';

/// Sends published results to parents. Each message is generated from the
/// student's actual marks. One batch per published revision.
class SendResultsScreen extends StatefulWidget {
  const SendResultsScreen({super.key, required this.examId});

  final String examId;

  @override
  State<SendResultsScreen> createState() => _SendResultsScreenState();
}

class _SendResultsScreenState extends State<SendResultsScreen> {
  var _allParents = true;
  final _selected = <String>{};
  var _sending = false;

  Future<void> _send(Exam exam, List<Student> recipients) async {
    if (_sending) return;
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Send results to ${Fmt.plural(recipients.length, 'parent')}?',
      message:
          'Each parent receives their child\'s subject marks, total and percentage. '
          'Demo only — no SMS is actually sent.',
      confirmLabel: 'Confirm & send',
      icon: Icons.send_rounded,
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    final result = context.appRead.sendResults(exam, recipients);
    if (!result.created) {
      AppToast.show(
        context,
        'These results were already sent — nothing was resent.',
        type: ToastType.warning,
      );
    }
    replacePage(context, BatchDetailScreen(batchId: result.batch.id));
  }

  void _preview(Exam exam, Student s) {
    final app = context.appRead;
    showAppSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.fullName, style: AppTextStyles.title),
            Text(
              'To ${s.parentName} · ${Fmt.phone(s.parentPhone)}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: Gap.md),
            MessageBubble(text: app.resultMessage(exam, s)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final exam = app.exams.byId(widget.examId);
    if (!app.canSendMessages || !exam.resultsPublished) {
      return AppScaffold(
        title: 'Send results',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: exam.resultsPublished
              ? 'Sending disabled'
              : 'Publish results first',
          message: exam.resultsPublished
              ? 'SMS sending is not enabled for your account.'
              : 'Results must be published before they can be sent to parents.',
        ),
      );
    }
    final roster = app.examRoster(exam);
    final existing = app.messaging.bySource(app.resultsSourceKey(exam));
    final recipients = _allParents
        ? roster
        : roster.where((s) => _selected.contains(s.id)).toList();
    final sample = recipients.isEmpty
        ? (roster.isEmpty ? null : roster.first)
        : recipients.first;

    return AppScaffold(
      title: 'Send results',
      subtitle: '${exam.name} · ${app.academic.classById(exam.classId).name}',
      bottomBar: existing != null
          ? SecondaryButton(
              label: 'Already sent · view status',
              icon: Icons.done_all_rounded,
              onPressed: () =>
                  replacePage(context, BatchDetailScreen(batchId: existing.id)),
            )
          : PrimaryButton(
              label: 'Send to ${Fmt.plural(recipients.length, 'parent')}',
              icon: Icons.send_rounded,
              loading: _sending,
              onPressed: recipients.isEmpty
                  ? null
                  : () => _send(exam, recipients),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          const SmsDemoBanner(),
          if (existing != null) ...[
            const SizedBox(height: 12),
            const DemoNotice(
              icon: Icons.block_rounded,
              color: AppColors.warning,
              text:
                  'A notification batch already exists for these published results, so sending again is blocked. '
                  'Failed messages can be retried from the batch.',
            ),
          ],
          if (exam.revision > 0) ...[
            const SizedBox(height: 12),
            DemoNotice(
              icon: Icons.history_edu_rounded,
              color: AppColors.info,
              text:
                  'Results were corrected ${Fmt.plural(exam.revision, 'time')}. Corrected results can be sent once per correction.',
            ),
          ],
          const SizedBox(height: Gap.lg),
          const FieldLabel('Send to'),
          SegmentedChoice<bool>(
            options: const [
              SelectOption(true, 'All parents in class'),
              SelectOption(false, 'Selected students'),
            ],
            value: _allParents,
            onChanged: (v) => setState(() => _allParents = v),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                size: 18,
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                'Recipients: ${recipients.length} of ${roster.length}',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (sample != null) ...[
            SectionHeader(
              title: 'Preview · ${sample.firstName}',
              padding: const EdgeInsets.only(top: Gap.lg, bottom: 10),
            ),
            MessageBubble(text: app.resultMessage(exam, sample)),
          ],
          SectionHeader(
            title: 'Students',
            padding: const EdgeInsets.only(top: Gap.lg, bottom: 4),
            actionLabel: _allParents
                ? null
                : (_selected.length == roster.length ? 'Clear' : 'Select all'),
            onAction: () => setState(() {
              if (_selected.length == roster.length) {
                _selected.clear();
              } else {
                _selected.addAll(roster.map((s) => s.id));
              }
            }),
          ),
          for (final s in roster)
            Builder(
              builder: (context) {
                final r = app.resultFor(exam, s.id);
                return Row(
                  children: [
                    if (!_allParents)
                      Checkbox(
                        value: _selected.contains(s.id),
                        onChanged: existing != null
                            ? null
                            : (v) => setState(
                                () => (v ?? false)
                                    ? _selected.add(s.id)
                                    : _selected.remove(s.id),
                              ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: _allParents ? 0 : 4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.fullName,
                              style: AppTextStyles.titleSmall.copyWith(
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${Fmt.marks(r.obtained)}/${Fmt.marks(r.maxTotal)} · ${Fmt.percent(r.percent, decimals: 1)} · ${Fmt.phoneSuffix(s.parentPhone)}',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                fontFeatures: AppTextStyles.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _preview(exam, s),
                      child: const Text('Preview'),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
