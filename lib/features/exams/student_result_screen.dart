import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/message_templates.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../messaging/message_widgets.dart';

/// Report card for one student in one exam. All totals are computed from the
/// stored subject marks.
class StudentResultScreen extends StatelessWidget {
  const StudentResultScreen({
    super.key,
    required this.examId,
    required this.studentId,
  });

  final String examId;
  final String studentId;

  void _showShare(
    BuildContext context,
    Exam exam,
    Student student,
    StudentResult result,
  ) {
    final app = context.appRead;
    showAppSheet<void>(
      context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report card preview', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              'Print, PDF and sharing are not available in this demo.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: Gap.md),
            Container(
              padding: const EdgeInsets.all(Gap.page),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: AppColors.textOnCream,
                  fontSize: 13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.tuition.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      app.tuition.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textOnCreamMuted,
                      ),
                    ),
                    const Divider(color: AppColors.creamBorder, height: 24),
                    Text(
                      '${student.fullName} · ${student.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${exam.name} · ${app.academic.classById(exam.classId).name} · ${Fmt.date(exam.date)}',
                    ),
                    const SizedBox(height: 12),
                    for (final s in result.subjects)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(s.subject.name)),
                            Text(
                              s.isAbsent
                                  ? 'AB'
                                  : '${Fmt.marks(s.obtained)} / ${Fmt.marks(s.maxMarks)}',
                              style: const TextStyle(
                                fontFeatures: AppTextStyles.tabular,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(color: AppColors.creamBorder, height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${Fmt.marks(result.obtained)} / ${Fmt.marks(result.maxTotal)}  ·  '
                          '${MessageTemplates.smartPercent(result.percent)}  ·  ${result.grade.label}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFeatures: AppTextStyles.tabular,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.md),
            SecondaryButton(
              label: 'Download PDF · not in demo',
              icon: Icons.picture_as_pdf_outlined,
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final exam = app.exams.byId(examId);
    final student = app.students.byId(studentId);
    final result = app.resultFor(exam, studentId);
    final grade = result.grade;

    return AppScaffold(
      title: 'Result',
      subtitle: student.fullName,
      actions: [
        IconButton(
          tooltip: 'Report card preview',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: () => _showShare(context, exam, student, result),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          CreamCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exam.name.toUpperCase(),
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textOnCreamMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusChip(
                      label: exam.resultsPublished ? 'Published' : 'Draft',
                      color: exam.resultsPublished
                          ? AppColors.success
                          : AppColors.warning,
                      dense: true,
                      onCream: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  student.fullName,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textOnCream,
                  ),
                ),
                Text(
                  '${app.academic.classById(exam.classId).name} · ${Fmt.date(exam.date)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnCreamMuted,
                  ),
                ),
                const SizedBox(height: Gap.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              MessageTemplates.smartPercent(result.percent),
                              style: AppTextStyles.display.copyWith(
                                color: AppColors.textOnCream,
                                fontSize: 44,
                                fontFeatures: AppTextStyles.tabular,
                              ),
                            ),
                          ),
                          Text(
                            '${Fmt.marks(result.obtained)} of ${Fmt.marks(result.maxTotal)} marks',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textOnCream,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.textOnCream,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            grade.label,
                            style: AppTextStyles.headline.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                          Text(
                            'GRADE',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.cream,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  grade.remark,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnCreamMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!result.isComplete) ...[
            const SizedBox(height: 12),
            const DemoNotice(
              icon: Icons.hourglass_bottom_rounded,
              color: AppColors.warning,
              text:
                  'Some subject marks are not entered yet, so this total is incomplete.',
            ),
          ],
          const SectionHeader(
            title: 'Subject-wise marks',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
          ),
          for (final s in result.subjects)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.subject.name,
                            style: AppTextStyles.titleSmall,
                          ),
                        ),
                        if (s.isAbsent)
                          const StatusChip(
                            label: 'Absent',
                            color: AppColors.error,
                            dense: true,
                          )
                        else
                          Text(
                            s.isMissing
                                ? 'Not entered'
                                : '${Fmt.marks(s.obtained)}/${Fmt.marks(s.maxMarks)}',
                            style: AppTextStyles.amount.copyWith(fontSize: 16),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ProgressBar(
                      value: s.ratio,
                      color: s.isAbsent
                          ? AppColors.textTertiary
                          : gradeFromRatio(s.ratio),
                      height: 8,
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: Gap.lg),
          InfoRow(label: 'Total obtained', value: Fmt.marks(result.obtained)),
          InfoRow(label: 'Total maximum', value: Fmt.marks(result.maxTotal)),
          InfoRow(
            label: 'Percentage',
            value: MessageTemplates.smartPercent(result.percent),
          ),
          InfoRow(label: 'Result', value: '${grade.label} · ${grade.remark}'),
          const SectionHeader(
            title: 'Parent message',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 10),
          ),
          MessageBubble(text: app.resultMessage(exam, student)),
        ],
      ),
    );
  }
}

Color gradeFromRatio(double ratio) {
  if (ratio >= 0.75) return AppColors.success;
  if (ratio >= 0.45) return AppColors.accent;
  if (ratio >= 0.35) return AppColors.warning;
  return AppColors.error;
}
