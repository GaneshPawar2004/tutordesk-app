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
import 'create_exam_screen.dart';
import 'exam_results_screen.dart';
import 'marks_entry_screen.dart';
import 'send_results_screen.dart';

class ExamDetailScreen extends StatelessWidget {
  const ExamDetailScreen({super.key, required this.examId});

  final String examId;

  Future<void> _publish(BuildContext context, Exam exam) async {
    final app = context.appRead;
    final (entered, total) = app.marksProgress(exam);
    if (entered < total) {
      AppToast.show(
        context,
        'Enter all marks (or mark absent) before publishing · $entered/$total done',
        type: ToastType.warning,
      );
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Publish results?',
      message:
          'Results become visible on student profiles and can be sent to parents. '
          'Later corrections need confirmation and are logged.',
      confirmLabel: 'Publish',
      icon: Icons.publish_rounded,
    );
    if (ok && context.mounted) {
      app.publishResults(exam);
      AppToast.show(context, 'Results published');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final exam = app.exams.byId(examId);
    if (!app.canAccessClass(exam.classId)) {
      return const AppScaffold(
        title: 'Exam',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not available',
          message: 'This exam belongs to a class you are not assigned to.',
        ),
      );
    }
    final cls = app.academic.classById(exam.classId);
    final status = exam.statusOn(app.today);
    final roster = app.examRoster(exam);
    final (entered, total) = app.marksProgress(exam);
    final canEnter = app.can(StaffPermission.enterMarks);
    final canView = app.can(StaffPermission.viewExamResults);
    final batch = app.messaging.bySource(app.resultsSourceKey(exam));
    final isUpcoming =
        status == ExamStatus.upcoming || status == ExamStatus.draft;

    return AppScaffold(
      title: exam.name,
      subtitle: '${cls.name} · ${Fmt.date(exam.date)}',
      actions: [
        if (canEnter && !exam.resultsPublished)
          IconButton(
            tooltip: 'Edit exam',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => pushPage(context, CreateExamScreen(exam: exam)),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ExamStatusChip(status: status),
              StatusChip(
                label: exam.resultsPublished
                    ? 'Results published'
                    : 'Results unpublished',
                color: exam.resultsPublished
                    ? AppColors.success
                    : AppColors.textSecondary,
                dense: true,
              ),
            ],
          ),
          if (exam.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(exam.description, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: Gap.md),
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatBlock(
                        label: 'Students',
                        value: '${roster.length}',
                        onCream: true,
                      ),
                    ),
                    Expanded(
                      child: StatBlock(
                        label: 'Subjects',
                        value: '${exam.subjects.length}',
                        onCream: true,
                      ),
                    ),
                    Expanded(
                      child: StatBlock(
                        label: 'Max marks',
                        value: Fmt.marks(exam.totalMax),
                        onCream: true,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    Text(
                      'Marks entry',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textOnCream,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$entered of $total',
                      style: AppTextStyles.amount.copyWith(
                        color: AppColors.textOnCream,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressBar(
                  value: total == 0 ? 0 : entered / total,
                  color: AppColors.accentPressed,
                  trackColor: AppColors.creamTrack,
                  height: 8,
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'Subjects',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
          ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < exam.subjects.length; i++) ...[
                  if (i > 0) const Divider(),
                  Builder(
                    builder: (context) {
                      final s = exam.subjects[i];
                      final (done, all) = app.marksProgress(
                        exam,
                        subjectId: s.subjectId,
                      );
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        title: Text(
                          app.academic.subjectById(s.subjectId).name,
                          style: AppTextStyles.titleSmall,
                        ),
                        subtitle: Text(
                          'Max ${Fmt.marks(s.maxMarks)} · $done/$all entered',
                          style: AppTextStyles.caption,
                        ),
                        trailing: canEnter && !isUpcoming
                            ? TextButton(
                                onPressed: () => pushPage(
                                  context,
                                  MarksEntryScreen(
                                    examId: exam.id,
                                    subjectId: s.subjectId,
                                  ),
                                ),
                                child: Text(done == 0 ? 'Enter' : 'Edit'),
                              )
                            : null,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (isUpcoming)
            DemoNotice(
              icon: Icons.event_outlined,
              text: status == ExamStatus.draft
                  ? 'This exam is a draft and has not been announced. Edit it to schedule it.'
                  : 'Marks entry opens on the exam day (${Fmt.date(exam.date)}).',
            )
          else ...[
            if (canEnter)
              PrimaryButton(
                label: exam.resultsPublished ? 'Correct marks' : 'Enter marks',
                icon: Icons.edit_note_rounded,
                onPressed: () =>
                    pushPage(context, MarksEntryScreen(examId: exam.id)),
              ),
            const SizedBox(height: 12),
            if (canView)
              SecondaryButton(
                label: 'View results',
                icon: Icons.leaderboard_outlined,
                onPressed: () =>
                    pushPage(context, ExamResultsScreen(examId: exam.id)),
              ),
            const SizedBox(height: 12),
            if (!exam.resultsPublished && canEnter)
              SecondaryButton(
                label: 'Publish results',
                icon: Icons.publish_rounded,
                onPressed: () => _publish(context, exam),
              ),
            if (exam.resultsPublished && app.canSendMessages)
              batch == null
                  ? SecondaryButton(
                      label: exam.revision > 0
                          ? 'Send corrected results to parents'
                          : 'Send results to parents',
                      icon: Icons.send_rounded,
                      onPressed: () =>
                          pushPage(context, SendResultsScreen(examId: exam.id)),
                    )
                  : SecondaryButton(
                      label: 'Results sent · view status',
                      icon: Icons.done_all_rounded,
                      onPressed: () => pushPage(
                        context,
                        BatchDetailScreen(batchId: batch.id),
                      ),
                    ),
          ],
          if (exam.correctionLog.isNotEmpty) ...[
            const SectionHeader(
              title: 'Correction log',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
            ),
            for (final note in exam.correctionLog)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: Gap.md),
          Text(
            'Created by ${exam.createdBy}${exam.publishedAt != null ? ' · Published ${Fmt.dateTime(exam.publishedAt!)}' : ''}',
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
