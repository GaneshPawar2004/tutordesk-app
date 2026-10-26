import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'attendance_summary_screen.dart';
import 'class_attendance_screen.dart';

class AttendanceOverviewScreen extends StatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  State<AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends State<AttendanceOverviewScreen> {
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final allClasses = app.visibleClasses;
    final classes = _classId == null
        ? allClasses
        : allClasses.where((c) => c.id == _classId).toList();
    final stats = app.todayAttendance(classes: classes);
    final canMark = app.can(StaffPermission.markAttendance);

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        AppHeader(
          eyebrow: Fmt.longDate(app.today),
          title: 'Attendance',
          subtitle:
              '${app.currentYear.label} · ${stats.classesMarked} of ${stats.classesTotal} classes marked',
        ),
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
                    for (final c in allClasses)
                      SelectOption(c.id, c.name, subtitle: c.sessionLabel),
                  ],
                  selected: _classId ?? '',
                );
                if (picked != null) {
                  setState(
                    () => _classId = picked.value.isEmpty ? null : picked.value,
                  );
                }
              },
            ),
            FilterPill(
              label: 'Year',
              value: app.currentYear.label,
              onTap: () => AppToast.show(
                context,
                'Attendance is always taken in the current academic year.',
                type: ToastType.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.page),
          child: SurfaceCard(
            child: Column(
              children: [
                Row(
                  children: [
                    _Stat(
                      label: 'Present',
                      value: stats.present,
                      color: AppColors.success,
                    ),
                    _Stat(
                      label: 'Absent',
                      value: stats.absent,
                      color: AppColors.error,
                    ),
                    _Stat(
                      label: 'Not marked',
                      value: stats.notMarked,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                ProgressBar(
                  value: stats.classesTotal == 0
                      ? 0
                      : stats.classesMarked / stats.classesTotal,
                  height: 8,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Completion', style: AppTextStyles.caption),
                    ),
                    Text(
                      '${stats.classesMarked}/${stats.classesTotal} sessions',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SectionHeader(title: 'Today\'s sessions'),
        if (classes.isEmpty)
          const EmptyState(
            icon: Icons.class_outlined,
            title: 'No classes assigned',
            message:
                'Ask the admin to assign you to a class to take attendance.',
          )
        else
          for (final c in classes)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 12),
              child: _SessionCard(schoolClass: c, canMark: canMark),
            ),
        if (!canMark) ...[
          const SizedBox(height: Gap.sm),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.page),
            child: DemoNotice(
              icon: Icons.lock_outline_rounded,
              color: AppColors.textSecondary,
              text: 'Your account can view attendance but not mark it.',
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$value', style: AppTextStyles.metric.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.schoolClass, required this.canMark});

  final SchoolClass schoolClass;
  final bool canMark;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final session = app.todaySession(schoolClass.id);
    final count = app.rosterFor(schoolClass.id).length;
    final marked = session != null;

    void open() {
      if (marked) {
        pushPage(context, AttendanceSummaryScreen(sessionId: session.id));
      } else if (canMark) {
        pushPage(context, ClassAttendanceScreen(classId: schoolClass.id));
      }
    }

    return SurfaceCard(
      onTap: marked || canMark ? open : null,
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
                      schoolClass.name,
                      style: AppTextStyles.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${schoolClass.sessionLabel} · ${Fmt.plural(count, 'student')}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (marked)
                const StatusChip(
                  label: 'Locked',
                  color: AppColors.success,
                  icon: Icons.lock_outline_rounded,
                  dense: true,
                )
              else
                const StatusChip(
                  label: 'Not marked',
                  color: AppColors.warning,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (marked) ...[
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _MiniCount(
                        label: 'Present',
                        value: session.presentCount + session.lateCount,
                        color: AppColors.success,
                      ),
                      _MiniCount(
                        label: 'Absent',
                        value: session.absentCount,
                        color: AppColors.error,
                      ),
                      _MiniCount(
                        label: 'Leave',
                        value: session.leaveCount,
                        color: AppColors.info,
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: open, child: const Text('View')),
              ],
            ),
            Text(
              'Marked by ${session.markedBy} · ${Fmt.time(session.markedAt)}',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ] else if (canMark)
            PrimaryButton(
              label: 'Start attendance',
              icon: Icons.play_arrow_rounded,
              onPressed: open,
            )
          else
            Text(
              'Waiting for the class teacher to mark attendance.',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}

class _MiniCount extends StatelessWidget {
  const _MiniCount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$value', style: AppTextStyles.amount),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
      ],
    );
  }
}
