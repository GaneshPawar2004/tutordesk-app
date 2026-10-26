import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'exam_results_screen.dart';

/// Whole-class marks entry, one subject at a time. Edits for every subject are
/// kept locally until Save draft / Publish.
class MarksEntryScreen extends StatefulWidget {
  const MarksEntryScreen({super.key, required this.examId, this.subjectId});

  final String examId;
  final String? subjectId;

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  late final Exam _exam;
  late String _subjectId;
  late final List<Student> _roster;

  /// subjectId -> studentId -> controller / absent flag
  final _controllers = <String, Map<String, TextEditingController>>{};
  final _absent = <String, Set<String>>{};
  var _dirty = false;
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final app = context.appRead;
    _exam = app.exams.byId(widget.examId);
    _subjectId = widget.subjectId ?? _exam.subjects.first.subjectId;
    _roster = app.examRoster(_exam);
    for (final s in _exam.subjects) {
      final map = <String, TextEditingController>{};
      final absent = <String>{};
      for (final st in _roster) {
        final entry = _exam.markFor(s.subjectId, st.id);
        if (entry?.absent ?? false) absent.add(st.id);
        map[st.id] = TextEditingController(
          text: entry?.marks == null ? '' : Fmt.marks(entry!.marks!),
        )..addListener(_onEdit);
      }
      _controllers[s.subjectId] = map;
      _absent[s.subjectId] = absent;
    }
  }

  void _onEdit() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    for (final m in _controllers.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  double _max(String subjectId) =>
      _exam.subjects.firstWhere((s) => s.subjectId == subjectId).maxMarks;

  String? _error(String subjectId, String studentId) {
    if (_absent[subjectId]!.contains(studentId)) return null;
    final text = _controllers[subjectId]![studentId]!.text.trim();
    if (text.isEmpty) return null;
    final value = double.tryParse(text);
    if (value == null) return 'Invalid';
    if (value < 0) return 'Below 0';
    if (value > _max(subjectId)) return 'Max ${Fmt.marks(_max(subjectId))}';
    return null;
  }

  bool _entered(String subjectId, String studentId) =>
      _absent[subjectId]!.contains(studentId) ||
      _controllers[subjectId]![studentId]!.text.trim().isNotEmpty;

  int _errorCount() {
    var n = 0;
    for (final s in _exam.subjects) {
      for (final st in _roster) {
        if (_error(s.subjectId, st.id) != null) n++;
      }
    }
    return n;
  }

  Map<String, MarkEntry> _entriesFor(String subjectId) {
    final result = <String, MarkEntry>{};
    for (final st in _roster) {
      if (_absent[subjectId]!.contains(st.id)) {
        result[st.id] = MarkEntry.absentEntry;
        continue;
      }
      final value = double.tryParse(
        _controllers[subjectId]![st.id]!.text.trim(),
      );
      if (value != null) result[st.id] = MarkEntry(marks: value);
    }
    return result;
  }

  /// Saves all subjects. Returns false if blocked by validation or cancelled.
  Future<bool> _saveAll({bool quiet = false}) async {
    if (_errorCount() > 0) {
      AppToast.show(
        context,
        'Fix ${Fmt.plural(_errorCount(), 'invalid mark')} first.',
        type: ToastType.error,
      );
      return false;
    }
    final app = context.appRead;
    String? note;
    if (_exam.resultsPublished) {
      note = await ConfirmationDialog.showWithNote(
        context,
        title: 'Correct published results?',
        message:
            'Parents may already have these results. The change is logged with your name and the reason, '
            'and corrected results can be sent once more.',
        confirmLabel: 'Save correction',
        noteHint: 'e.g. Re-totalled Science paper',
      );
      if (note == null || !mounted) return false;
    }
    for (final s in _exam.subjects) {
      app.saveMarks(
        _exam,
        s.subjectId,
        _entriesFor(s.subjectId),
        correctionNote: s.subjectId == _subjectId ? note : null,
      );
    }
    setState(() => _dirty = false);
    if (!quiet && mounted) {
      AppToast.show(
        context,
        _exam.resultsPublished ? 'Correction saved and logged' : 'Draft saved',
      );
    }
    return true;
  }

  Future<void> _preview() async {
    if (_dirty && !await _saveAll(quiet: true)) return;
    if (mounted) pushPage(context, ExamResultsScreen(examId: _exam.id));
  }

  Future<void> _publish() async {
    final app = context.appRead;
    var missing = 0;
    for (final s in _exam.subjects) {
      for (final st in _roster) {
        if (!_entered(s.subjectId, st.id)) missing++;
      }
    }
    if (missing > 0) {
      AppToast.show(
        context,
        '$missing marks still empty. Enter them or mark the student absent.',
        type: ToastType.warning,
      );
      return;
    }
    if (_errorCount() > 0) {
      AppToast.show(
        context,
        'Fix invalid marks before publishing.',
        type: ToastType.error,
      );
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Publish results?',
      message:
          '${_exam.name} results for ${Fmt.plural(_roster.length, 'student')} will be published. '
          'Corrections after publishing need confirmation.',
      confirmLabel: 'Publish',
      icon: Icons.publish_rounded,
    );
    if (!ok || !mounted) return;
    for (final s in _exam.subjects) {
      app.saveMarks(_exam, s.subjectId, _entriesFor(s.subjectId));
    }
    app.publishResults(_exam);
    setState(() => _dirty = false);
    Navigator.of(context).pop();
    AppToast.show(context, 'Results published');
  }

  Future<void> _leave() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Discard unsaved marks?',
      message: 'Marks entered since your last save will be lost.',
      confirmLabel: 'Discard',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.can(StaffPermission.enterMarks) ||
        !app.canAccessClass(_exam.classId)) {
      return const AppScaffold(
        title: 'Enter marks',
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Not allowed',
          message: 'You do not have permission to enter marks.',
        ),
      );
    }
    final subject = app.academic.subjectById(_subjectId);
    final max = _max(_subjectId);
    final enteredCount = _roster
        .where((s) => _entered(_subjectId, s.id))
        .length;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AppScaffold(
        title: 'Enter marks',
        subtitle:
            '${_exam.name} · ${app.academic.classById(_exam.classId).name}',
        onBack: _leave,
        bottomBar: Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: _exam.resultsPublished ? 'Save' : 'Save draft',
                onPressed: _dirty ? () => _saveAll() : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(label: 'Preview', onPressed: _preview),
            ),
            if (!_exam.resultsPublished) ...[
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(label: 'Publish', onPressed: _publish),
              ),
            ],
          ],
        ),
        body: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    if (_exam.resultsPublished) ...[
                      const DemoNotice(
                        icon: Icons.lock_outline_rounded,
                        color: AppColors.warning,
                        text:
                            'Results are published. Saving changes asks for confirmation and a reason, which is logged.',
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_exam.subjects.length > 1) ...[
                      SegmentedChoice<String>(
                        options: [
                          for (final s in _exam.subjects)
                            SelectOption(
                              s.subjectId,
                              app.academic.subjectById(s.subjectId).name,
                            ),
                        ],
                        value: _subjectId,
                        onChanged: (id) => setState(() => _subjectId = id),
                      ),
                      const SizedBox(height: 12),
                    ],
                    CreamCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.name,
                                  style: AppTextStyles.title.copyWith(
                                    color: AppColors.textOnCream,
                                  ),
                                ),
                                Text(
                                  '${Fmt.date(_exam.date)} · Max ${Fmt.marks(max)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textOnCreamMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$enteredCount/${_roster.length}',
                                style: AppTextStyles.metric.copyWith(
                                  color: AppColors.textOnCream,
                                  fontSize: 22,
                                ),
                              ),
                              Text(
                                '${_roster.length - enteredCount} remaining',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textOnCreamMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (_roster.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'No marks entered',
                  message:
                      'There are no students enrolled in this class for the exam\'s academic year.',
                ),
              )
            else
              SliverList.separated(
                itemCount: _roster.length,
                separatorBuilder: (_, _) => const InsetDivider(),
                itemBuilder: (context, i) {
                  final st = _roster[i];
                  final absent = _absent[_subjectId]!.contains(st.id);
                  return _MarkRow(
                    key: ValueKey('$_subjectId-${st.id}'),
                    student: st,
                    controller: _controllers[_subjectId]![st.id]!,
                    max: max,
                    absent: absent,
                    error: _error(_subjectId, st.id),
                    isLast: i == _roster.length - 1,
                    onChanged: () => setState(() {}),
                    onAbsent: (v) => setState(() {
                      _dirty = true;
                      if (v) {
                        _absent[_subjectId]!.add(st.id);
                        _controllers[_subjectId]![st.id]!.clear();
                      } else {
                        _absent[_subjectId]!.remove(st.id);
                      }
                    }),
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

class _MarkRow extends StatelessWidget {
  const _MarkRow({
    super.key,
    required this.student,
    required this.controller,
    required this.max,
    required this.absent,
    required this.error,
    required this.isLast,
    required this.onChanged,
    required this.onAbsent,
  });

  final Student student;
  final TextEditingController controller;
  final double max;
  final bool absent;
  final String? error;
  final bool isLast;
  final VoidCallback onChanged;
  final ValueChanged<bool> onAbsent;

  @override
  Widget build(BuildContext context) {
    final filled = absent || controller.text.trim().isNotEmpty;
    final borderColor = error != null
        ? AppColors.error
        : filled
        ? AppColors.accent.withValues(alpha: 0.6)
        : AppColors.border;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 10),
      child: Row(
        children: [
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
                  error ?? student.id,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: error != null ? AppColors.error : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              controller: controller,
              enabled: !absent,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: isLast
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) => onChanged(),
              style: AppTextStyles.amount.copyWith(fontSize: 16),
              decoration: InputDecoration(
                isDense: true,
                hintText: absent ? 'AB' : '—',
                suffixText: '/${Fmt.marks(max)}',
                suffixStyle: AppTextStyles.caption.copyWith(fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: error != null ? AppColors.error : AppColors.accent,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Mark ${student.fullName} absent',
            toggled: absent,
            child: FilterChip(
              label: const Text('Absent'),
              selected: absent,
              onSelected: onAbsent,
              selectedColor: AppColors.error,
              labelStyle: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: absent ? AppColors.background : AppColors.textSecondary,
              ),
              side: BorderSide(
                color: absent ? AppColors.error : AppColors.border,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
