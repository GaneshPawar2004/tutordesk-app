import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'attendance_summary_screen.dart';

/// Marks today's attendance for one class, or corrects an existing session
/// when [correctSessionId] is given (admin only, with an audit note).
class ClassAttendanceScreen extends StatefulWidget {
  const ClassAttendanceScreen({
    super.key,
    required this.classId,
    this.correctSessionId,
  });

  final String classId;
  final String? correctSessionId;

  bool get isCorrection => correctSessionId != null;

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  final _search = TextEditingController();
  final _marks = <String, AttendanceStatus>{};
  var _query = '';
  var _saving = false;
  var _initialised = false;

  /// True once this screen has submitted, so a session appearing afterwards is
  /// ours rather than a conflict.
  var _submitted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final app = context.appRead;
    if (widget.isCorrection) {
      _marks.addAll(app.attendance.byId(widget.correctSessionId!)!.records);
    } else if (app.todaySessionFor(widget.classId) != null) {
      // Already marked (possibly by someone else): show the locked summary.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        replacePage(
          context,
          AttendanceSummaryScreen(
            sessionId: app.todaySessionFor(widget.classId)!.id,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(String studentId, AttendanceStatus status) {
    if (context.appRead.appPrefs['Haptic feedback when marking attendance'] ??
        false) {
      HapticFeedback.selectionClick();
    }
    setState(() => _marks[studentId] = status);
  }

  void _markAllPresent(List<Student> roster) {
    setState(() {
      for (final s in roster) {
        _marks[s.id] = AttendanceStatus.present;
      }
    });
  }

  bool get _dirty {
    if (!widget.isCorrection) return _marks.isNotEmpty && !_submitted;
    final original = context.appRead.attendance
        .byId(widget.correctSessionId!)!
        .records;
    return _marks.entries.any((e) => original[e.key] != e.value);
  }

  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Leave without saving?',
      message: 'Attendance you have marked on this screen will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _save(List<Student> roster) async {
    if (_saving) return;
    final app = context.appRead;
    final cls = app.academic.classById(widget.classId);
    final unmarked = roster.where((s) => !_marks.containsKey(s.id)).toList();

    if (widget.isCorrection) {
      final note = await ConfirmationDialog.showWithNote(
        context,
        title: 'Save correction?',
        message:
            'This changes a locked session. Your name, the time and this note are added to the audit trail.',
        confirmLabel: 'Save correction',
      );
      if (note == null || !mounted) return;
      setState(() => _saving = true);
      try {
        await app.correctAttendance(
          app.attendance.byId(widget.correctSessionId!)!,
          Map.of(_marks),
          note,
        );
      } on ApiException catch (e) {
        if (mounted) {
          setState(() => _saving = false);
          AppToast.show(context, e.message, type: ToastType.error);
        }
        return;
      }
      if (!mounted) return;
      _submitted = true;
      Navigator.of(context).pop();
      AppToast.show(context, 'Correction saved with audit note');
      return;
    }

    if (unmarked.isNotEmpty) {
      final markRest = await ConfirmationDialog.show(
        context,
        title: '${Fmt.plural(unmarked.length, 'student')} not marked',
        message: 'Mark the remaining students as present and save?',
        confirmLabel: 'Mark present & continue',
        icon: Icons.how_to_reg_outlined,
      );
      if (!markRest || !mounted) return;
      setState(() {
        for (final s in unmarked) {
          _marks[s.id] = AttendanceStatus.present;
        }
      });
    }

    final present = _marks.values.where((s) => s.attended).length;
    final confirmed = await ConfirmationDialog.show(
      context,
      title: 'Save attendance for ${cls.name}?',
      message:
          '$present present · ${_marks.length - present} absent or on leave.\n'
          'The session is locked after saving. Corrections need an admin and an audit note.',
      confirmLabel: 'Save & lock',
      icon: Icons.lock_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    _submitted = true;
    final AttendanceSaveResult result;
    try {
      result = await app.saveAttendance(widget.classId, Map.of(_marks));
    } on ApiException catch (e) {
      _submitted = false;
      if (mounted) {
        setState(() => _saving = false);
        AppToast.show(context, e.message, type: ToastType.error);
      }
      return;
    }
    if (!mounted) return;
    if (!result.created) {
      setState(() => _saving = false);
      await ConfirmationDialog.show(
        context,
        title: 'Already marked',
        message:
            '${result.session.markedBy} saved attendance for ${cls.name} at '
            '${Fmt.time(result.session.markedAt)}. Your copy was not submitted, so there is no duplicate.',
        confirmLabel: 'View saved attendance',
        cancelLabel: 'Close',
        icon: Icons.lock_clock_outlined,
      );
    }
    if (!mounted) return;
    replacePage(
      context,
      AttendanceSummaryScreen(
        sessionId: result.session.id,
        justSaved: result.created,
      ),
    );
  }

  /// Demo helper: simulates a colleague saving this class from another phone.
  void _simulateOtherDevice(List<Student> roster) {
    final app = context.appRead;
    final other = app.staff
        .forClass(widget.classId)
        .where(
          (s) =>
              s.name != app.userName && s.accountStatus == AccountStatus.active,
        )
        .firstOrNull;
    app.attendance.save(
      classId: widget.classId,
      yearId: app.currentYear.id,
      date: app.today,
      records: {for (final s in roster) s.id: AttendanceStatus.present},
      markedBy: other?.name ?? app.admin.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final cls = app.academic.classById(widget.classId);
    final roster = app.rosterFor(widget.classId);
    final q = _query.toLowerCase();
    final visible = q.isEmpty
        ? roster
        : roster
              .where(
                (s) =>
                    s.fullName.toLowerCase().contains(q) ||
                    s.id.toLowerCase().contains(q),
              )
              .toList();
    final conflict = !widget.isCorrection && !_submitted
        ? app.todaySessionFor(widget.classId)
        : null;
    int count(AttendanceStatus s) => _marks.values.where((v) => v == s).length;
    final unmarked = roster.length - _marks.length;

    if (!app.can(StaffPermission.markAttendance) ||
        !app.canAccessClass(widget.classId)) {
      return const AppScaffold(
        title: 'Attendance',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not allowed',
          message:
              'You do not have permission to mark attendance for this class.',
        ),
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AppScaffold(
        title: widget.isCorrection ? 'Correct ${cls.name}' : cls.name,
        subtitle: '${Fmt.weekdayDate(app.today)} · ${cls.sessionLabel}',
        onBack: _leave,
        actions: [
          if (!app.isRemote && !widget.isCorrection && conflict == null)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(Icons.more_vert_rounded),
              color: AppColors.surfaceElevated,
              onSelected: (_) => _simulateOtherDevice(roster),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'sim',
                  child: Text('Demo: colleague saves first'),
                ),
              ],
            ),
        ],
        bottomBar: conflict != null
            ? PrimaryButton(
                label: 'View saved attendance',
                icon: Icons.lock_outline_rounded,
                onPressed: () => replacePage(
                  context,
                  AttendanceSummaryScreen(sessionId: conflict.id),
                ),
              )
            : PrimaryButton(
                label: widget.isCorrection
                    ? 'Save correction'
                    : unmarked == 0
                    ? 'Save attendance'
                    : 'Save · $unmarked unmarked',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: roster.isEmpty ? null : () => _save(roster),
              ),
        body: roster.isEmpty
            ? const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No students in this class',
                message:
                    'Add or promote students into this class to take attendance.',
              )
            : CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.page,
                        Gap.sm,
                        Gap.page,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (conflict != null) ...[
                            DemoNotice(
                              icon: Icons.lock_clock_outlined,
                              color: AppColors.warning,
                              text:
                                  '${conflict.markedBy} just saved attendance for ${cls.name}. '
                                  'This session is now locked — your copy will not be submitted.',
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (widget.isCorrection) ...[
                            const DemoNotice(
                              icon: Icons.edit_note_rounded,
                              color: AppColors.warning,
                              text:
                                  'Correction mode. Changes are saved with your name and a required note.',
                            ),
                            const SizedBox(height: 12),
                          ],
                          _CountsBar(
                            present: count(AttendanceStatus.present),
                            absent: count(AttendanceStatus.absent),
                            late: count(AttendanceStatus.late),
                            leave: count(AttendanceStatus.leave),
                            unmarked: unmarked,
                            total: roster.length,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppSearchBar(
                                  controller: _search,
                                  hint: 'Find student',
                                  onChanged: (v) =>
                                      setState(() => _query = v.trim()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: conflict != null
                                    ? null
                                    : () => _markAllPresent(roster),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.cream,
                                  foregroundColor: AppColors.textOnCream,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.done_all_rounded,
                                  size: 18,
                                ),
                                label: const Text('All present'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        compact: true,
                        icon: Icons.search_off_rounded,
                        title: 'No matching students',
                        message: 'Check the spelling or clear the search.',
                      ),
                    )
                  else
                    SliverList.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const InsetDivider(),
                      itemBuilder: (context, i) {
                        final s = visible[i];
                        return _MarkRow(
                          student: s,
                          value: _marks[s.id],
                          enabled: conflict == null,
                          onChanged: (v) => _set(s.id, v),
                        );
                      },
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: Gap.lg)),
                ],
              ),
      ),
    );
  }
}

class _CountsBar extends StatelessWidget {
  const _CountsBar({
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.unmarked,
    required this.total,
  });

  final int present;
  final int absent;
  final int late;
  final int leave;
  final int unmarked;
  final int total;

  @override
  Widget build(BuildContext context) {
    Widget cell(String label, int v, Color c) => Expanded(
      child: Column(
        children: [
          Text(
            '$v',
            style: AppTextStyles.amount.copyWith(fontSize: 18, color: c),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 11.5),
            maxLines: 1,
          ),
        ],
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [
              cell('Present', present, AppColors.success),
              cell('Absent', absent, AppColors.error),
              cell('Late', late, AppColors.warning),
              cell('Leave', leave, AppColors.info),
              cell('Unmarked', unmarked, AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ProgressBar(
              value: total == 0 ? 0 : (total - unmarked) / total,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    required this.student,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final Student student;
  final AttendanceStatus? value;
  final ValueChanged<AttendanceStatus> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 10),
      child: Row(
        children: [
          AppAvatar(initials: student.initials, seed: student.id, size: 38),
          const SizedBox(width: 12),
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
                  student.id,
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          for (final status in AttendanceStatus.values) ...[
            const SizedBox(width: 6),
            _StatusToggle(
              status: status,
              selected: value == status,
              onTap: enabled ? () => onChanged(status) : null,
              studentName: student.fullName,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.status,
    required this.selected,
    required this.onTap,
    required this.studentName,
  });

  final AttendanceStatus status;
  final bool selected;
  final VoidCallback? onTap;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final color = attendanceColor(status);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Mark $studentName ${status.label}',
      child: Material(
        color: selected ? color : AppColors.surface,
        shape: CircleBorder(
          side: BorderSide(color: selected ? color : AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  status.short,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: status == AttendanceStatus.leave ? 11 : 13,
                    color: selected
                        ? AppColors.background
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
