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
import 'send_results_screen.dart';
import 'student_result_screen.dart';

/// Class-wide results for an exam, ranked by percentage.
class ExamResultsScreen extends StatelessWidget {
  const ExamResultsScreen({super.key, required this.examId});

  final String examId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final exam = app.exams.byId(examId);
    final roster = app.examRoster(exam);
    final results = roster.map((s) => (s, app.resultFor(exam, s.id))).toList()
      ..sort((a, b) => b.$2.percent.compareTo(a.$2.percent));
    final scored = results
        .where((r) => !r.$2.absentInAll && r.$2.isComplete)
        .toList();
    final average = app.classAverage(exam);
    final highest = scored.isEmpty ? null : scored.first.$2.percent;
    final passed = scored.where((r) => r.$2.percent >= 35).length;
    final batch = app.messaging.bySource(app.resultsSourceKey(exam));
    final anyEntered = exam.marks.values.any((m) => m.isNotEmpty);

    return AppScaffold(
      title: 'Results',
      subtitle: '${exam.name} · ${app.academic.classById(exam.classId).name}',
      bottomBar: exam.resultsPublished && app.canSendMessages
          ? (batch == null
                ? PrimaryButton(
                    label: 'Send results to parents',
                    icon: Icons.send_rounded,
                    onPressed: () =>
                        pushPage(context, SendResultsScreen(examId: exam.id)),
                  )
                : SecondaryButton(
                    label: 'Results sent · view status',
                    icon: Icons.done_all_rounded,
                    onPressed: () =>
                        pushPage(context, BatchDetailScreen(batchId: batch.id)),
                  ))
          : null,
      body: !anyEntered
          ? const EmptyState(
              icon: Icons.edit_note_rounded,
              title: 'No marks entered',
              message:
                  'Enter marks for at least one subject to see results here.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Gap.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StatusChip(
                        label: exam.resultsPublished
                            ? 'Published'
                            : 'Draft · not visible to parents',
                        color: exam.resultsPublished
                            ? AppColors.success
                            : AppColors.warning,
                        icon: exam.resultsPublished
                            ? Icons.public_rounded
                            : Icons.visibility_off_outlined,
                      ),
                      const SizedBox(height: Gap.md),
                      CreamCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: StatBlock(
                                label: 'Class average',
                                value: average == null
                                    ? '—'
                                    : Fmt.percent(average, decimals: 1),
                                onCream: true,
                              ),
                            ),
                            Expanded(
                              child: StatBlock(
                                label: 'Highest',
                                value: highest == null
                                    ? '—'
                                    : Fmt.percent(highest, decimals: 1),
                                onCream: true,
                              ),
                            ),
                            Expanded(
                              child: StatBlock(
                                label: 'Passed',
                                value: '$passed/${scored.length}',
                                onCream: true,
                                alignEnd: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(title: 'Students'),
                for (var i = 0; i < results.length; i++)
                  _ResultRow(
                    rank: i + 1,
                    student: results[i].$1,
                    result: results[i].$2,
                    onTap: () => pushPage(
                      context,
                      StudentResultScreen(
                        examId: exam.id,
                        studentId: results[i].$1.id,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.rank,
    required this.student,
    required this.result,
    required this.onTap,
  });

  final int rank;
  final Student student;
  final StudentResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final incomplete = !result.isComplete;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? AppColors.accent : AppColors.textTertiary,
                  fontFeatures: AppTextStyles.tabular,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    result.absentInAll
                        ? 'Absent'
                        : '${Fmt.marks(result.obtained)}/${Fmt.marks(result.maxTotal)}${incomplete ? ' · incomplete' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontFeatures: AppTextStyles.tabular,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                result.absentInAll
                    ? '—'
                    : Fmt.percent(result.percent, decimals: 1),
                textAlign: TextAlign.right,
                style: AppTextStyles.amount,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: result.absentInAll
                  ? const SizedBox()
                  : StatusChip(
                      label: result.grade.label,
                      color: result.grade.color,
                      dense: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
