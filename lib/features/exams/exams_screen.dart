import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../dashboard/dashboard_screen.dart' show DateBadge;
import 'create_exam_screen.dart';
import 'exam_detail_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  late String? _classId = widget.initialClassId;
  String? _yearId;
  String? _subjectId;
  ExamStatus? _status;

  bool get _canCreate {
    final app = context.appRead;
    return app.isAdmin || app.can(StaffPermission.enterMarks);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.can(StaffPermission.viewExamResults) &&
        !app.can(StaffPermission.enterMarks)) {
      return const AppScaffold(
        title: 'Exams',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Exams are restricted',
          message: 'Ask the admin for exam access.',
        ),
      );
    }
    final yearId = _yearId ?? app.selectedYear.id;
    final exams = app.visibleExams
        .where((e) => e.academicYearId == yearId)
        .where((e) => _classId == null || e.classId == _classId)
        .where(
          (e) =>
              _subjectId == null ||
              e.subjects.any((s) => s.subjectId == _subjectId),
        )
        .toList();
    List<Exam> withStatus(ExamStatus s) =>
        exams.where((e) => e.statusOn(app.today) == s).toList();

    final sections = <(String, List<Exam>)>[
      if (_status == null || _status == ExamStatus.upcoming)
        (
          'Upcoming',
          withStatus(ExamStatus.upcoming)
            ..sort((a, b) => a.date.compareTo(b.date)),
        ),
      if (_status == null || _status == ExamStatus.completed)
        ('Completed · results pending', withStatus(ExamStatus.completed)),
      if (_status == null || _status == ExamStatus.draft)
        ('Drafts', withStatus(ExamStatus.draft)),
      if (_status == null || _status == ExamStatus.published)
        (
          'Recently published',
          withStatus(ExamStatus.published)..sort(
            (a, b) =>
                (b.publishedAt ?? b.date).compareTo(a.publishedAt ?? a.date),
          ),
        ),
    ];

    return AppScaffold(
      title: 'Exams & marks',
      subtitle: app.academic.yearById(yearId).label,
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () =>
                  pushPage(context, CreateExamScreen(initialClassId: _classId)),
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create exam', style: AppTextStyles.button),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const SizedBox(height: Gap.sm),
          FilterChips(
            children: [
              FilterPill(
                label: 'Class',
                value: _classId == null
                    ? 'All'
                    : app.academic.classById(_classId!).name,
                active: _classId != null,
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    context,
                    title: 'Class',
                    options: [
                      const SelectOption('', 'All classes'),
                      for (final c in app.visibleClasses)
                        SelectOption(c.id, c.name),
                    ],
                    selected: _classId ?? '',
                  );
                  if (picked != null) {
                    setState(
                      () =>
                          _classId = picked.value.isEmpty ? null : picked.value,
                    );
                  }
                },
              ),
              FilterPill(
                label: 'Year',
                value: app.academic.yearById(yearId).label,
                active: yearId != app.currentYear.id,
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    context,
                    title: 'Academic year',
                    options: [
                      for (final y in app.academic.years)
                        SelectOption(y.id, y.label),
                    ],
                    selected: yearId,
                  );
                  if (picked != null) setState(() => _yearId = picked.value);
                },
              ),
              FilterPill(
                label: 'Subject',
                value: _subjectId == null
                    ? 'All'
                    : app.academic.subjectById(_subjectId!).name,
                active: _subjectId != null,
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    context,
                    title: 'Subject',
                    options: [
                      const SelectOption('', 'All subjects'),
                      for (final s in app.academic.subjects)
                        SelectOption(s.id, s.name),
                    ],
                    selected: _subjectId ?? '',
                  );
                  if (picked != null) {
                    setState(
                      () => _subjectId = picked.value.isEmpty
                          ? null
                          : picked.value,
                    );
                  }
                },
              ),
              FilterPill(
                label: 'Status',
                value: _status?.label ?? 'All',
                active: _status != null,
                onTap: () async {
                  final picked = await showSelectSheet<String>(
                    context,
                    title: 'Exam status',
                    options: [
                      const SelectOption('', 'All'),
                      for (final s in ExamStatus.values)
                        SelectOption(s.name, s.label),
                    ],
                    selected: _status?.name ?? '',
                  );
                  if (picked != null) {
                    setState(
                      () => _status = ExamStatus.values
                          .where((s) => s.name == picked.value)
                          .firstOrNull,
                    );
                  }
                },
              ),
            ],
          ),
          if (exams.isEmpty)
            EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No exams',
              message:
                  'No exams match these filters. Create an exam to start tracking marks.',
              actionLabel: _canCreate ? 'Create exam' : null,
              onAction: _canCreate
                  ? () => pushPage(
                      context,
                      CreateExamScreen(initialClassId: _classId),
                    )
                  : null,
            )
          else
            for (final (title, list) in sections)
              if (list.isNotEmpty) ...[
                SectionHeader(title: '$title · ${list.length}'),
                for (final e in list)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Gap.page,
                      0,
                      Gap.page,
                      12,
                    ),
                    child: ExamTile(exam: e),
                  ),
              ],
        ],
      ),
    );
  }
}

class ExamTile extends StatelessWidget {
  const ExamTile({super.key, required this.exam});

  final Exam exam;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final status = exam.statusOn(app.today);
    final (entered, total) = app.marksProgress(exam);
    final subjects = exam.subjects
        .map((s) => app.academic.subjectById(s.subjectId).name)
        .join(', ');
    return SurfaceCard(
      onTap: () => pushPage(context, ExamDetailScreen(examId: exam.id)),
      child: Column(
        children: [
          Row(
            children: [
              DateBadge(date: exam.date),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${app.academic.classById(exam.classId).name} · $subjects',
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Max ${Fmt.marks(exam.totalMax)} marks',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ExamStatusChip(status: status),
            ],
          ),
          if (status == ExamStatus.completed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProgressBar(
                    value: total == 0 ? 0 : entered / total,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$entered/$total marks',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontFeatures: AppTextStyles.tabular,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
