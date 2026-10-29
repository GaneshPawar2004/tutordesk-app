import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../attendance/attendance_summary_screen.dart';
import '../attendance/class_attendance_screen.dart';
import '../exams/exams_screen.dart';
import '../fees/fee_widgets.dart';
import '../students/student_directory_screen.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final classes = app.academic.classes;
    final year = app.selectedYear;

    return AppScaffold(
      title: 'Classes',
      subtitle: '${year.label} · ${app.academic.runningClasses.length} running',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => pushPage(context, const ClassFormScreen()),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add class', style: AppTextStyles.button),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, 96),
        itemCount: classes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = classes[i];
          return ClassCard(
            schoolClass: c,
            yearLabel: year.label,
            studentCount: app.enrolledCount(c.id, year.id),
            staffNames: app.staff.forClass(c.id).map((s) => s.name).toList(),
            onTap: () => pushPage(context, ClassDetailScreen(classId: c.id)),
          );
        },
      ),
    );
  }
}

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  Future<void> _assignStaff(BuildContext context) async {
    final app = context.appRead;
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Assign staff',
      options: [
        for (final s in app.staff.all.where((s) => s.isActive))
          SelectOption(s.id, s.name, subtitle: s.designation),
      ],
      selected: app.staff.forClass(classId).map((s) => s.id).toSet(),
    );
    if (picked != null && context.mounted) {
      await runAction(
        context,
        () => app.assignStaffToClass(classId, picked),
        success: 'Staff assignment updated',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final cls = app.academic.classById(classId);
    final year = app.selectedYear;
    final staff = app.staff.forClass(classId);
    final session = app.todaySessionFor(classId);

    return AppScaffold(
      title: cls.name,
      subtitle: year.label,
      actions: [
        IconButton(
          tooltip: 'Edit class',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => pushPage(context, ClassFormScreen(schoolClass: cls)),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xl),
        children: [
          CreamCard(
            child: Row(
              children: [
                Expanded(
                  child: StatBlock(
                    label: 'Enrolled',
                    value: '${app.enrolledCount(classId, year.id)}',
                    onCream: true,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Staff',
                    value: '${staff.length}',
                    onCream: true,
                  ),
                ),
                Expanded(
                  child: StatBlock(
                    label: 'Status',
                    value: cls.isActive ? 'Running' : 'Paused',
                    onCream: true,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.md),
          InfoRow(
            icon: Icons.schedule_rounded,
            label: 'Batch timing',
            value: cls.sessionLabel,
          ),
          InfoRow(
            icon: Icons.meeting_room_outlined,
            label: 'Room',
            value: cls.room.isEmpty ? '—' : cls.room,
          ),
          InfoRow(
            icon: Icons.menu_book_outlined,
            label: 'Subjects',
            value: cls.subjectIds
                .map((id) => app.academic.subjectById(id).name)
                .join(', '),
          ),
          SectionHeader(
            title: 'Assigned staff',
            padding: const EdgeInsets.only(top: Gap.lg, bottom: 8),
            actionLabel: 'Assign',
            onAction: () => _assignStaff(context),
          ),
          if (staff.isEmpty)
            Text(
              'No staff assigned yet.',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning),
            )
          else
            for (final s in staff)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    AppAvatar(initials: s.initials, seed: s.id, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.name,
                        style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
                      ),
                    ),
                    Text(
                      s.designation,
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
          const SectionHeader(
            title: 'Actions',
            padding: EdgeInsets.only(top: Gap.lg, bottom: 4),
          ),
          NavRow(
            icon: Icons.people_outline_rounded,
            title: 'View students',
            subtitle: Fmt.plural(
              app.enrolledCount(classId, year.id),
              'student',
            ),
            onTap: () => pushPage(
              context,
              StudentDirectoryScreen(initialClassId: classId, standalone: true),
            ),
          ),
          if (cls.isActive)
            NavRow(
              icon: Icons.fact_check_outlined,
              color: AppColors.success,
              title: 'Open attendance',
              subtitle: session == null
                  ? 'Not marked today'
                  : 'Marked today · locked',
              onTap: () => pushPage(
                context,
                session == null
                    ? ClassAttendanceScreen(classId: classId)
                    : AttendanceSummaryScreen(sessionId: session.id),
              ),
            ),
          NavRow(
            icon: Icons.assignment_outlined,
            color: AppColors.info,
            title: 'View exams',
            subtitle: Fmt.plural(
              app.exams.all.where((e) => e.classId == classId).length,
              'exam',
            ),
            onTap: () =>
                pushPage(context, ExamsScreen(initialClassId: classId)),
          ),
        ],
      ),
    );
  }
}

class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.schoolClass});

  final SchoolClass? schoolClass;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _grade = TextEditingController();
  final _timing = TextEditingController();
  final _room = TextEditingController();
  var _subjects = <String>{'sub-math', 'sub-sci', 'sub-eng'};
  var _active = true;

  @override
  void initState() {
    super.initState();
    final c = widget.schoolClass;
    if (c != null) {
      _name.text = c.name;
      _grade.text = '${c.grade}';
      _timing.text = c.sessionLabel;
      _room.text = c.room;
      _subjects = c.subjectIds.toSet();
      _active = c.isActive;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _grade.dispose();
    _timing.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjects.isEmpty) {
      AppToast.show(
        context,
        'Choose at least one subject.',
        type: ToastType.error,
      );
      return;
    }
    final app = context.appRead;
    final subjectIds = app.academic.subjects
        .where((s) => _subjects.contains(s.id))
        .map((s) => s.id)
        .toList();
    final c = widget.schoolClass;
    final ok = await runAction(
      context,
      () => c == null
          ? app.addClass(
              name: _name.text.trim(),
              grade: int.parse(_grade.text),
              sessionLabel: _timing.text.trim(),
              room: _room.text.trim(),
              subjectIds: subjectIds,
            )
          : app.updateClass(
              c,
              name: _name.text.trim(),
              grade: int.parse(_grade.text),
              sessionLabel: _timing.text.trim(),
              room: _room.text.trim(),
              subjectIds: subjectIds,
              isActive: _active,
            ),
      success: c == null ? 'Class added' : 'Class updated',
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final isEdit = widget.schoolClass != null;
    return AppScaffold(
      title: isEdit ? 'Edit class' : 'Add class',
      bottomBar: PrimaryButton(
        label: isEdit ? 'Save changes' : 'Add class',
        icon: Icons.check_rounded,
        onPressed: _save,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.xl,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    label: 'Class name',
                    controller: _name,
                    hint: 'Class 11 · Science',
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Grade',
                    controller: _grade,
                    hint: '11',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 1 || n > 12 ? '1–12' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Batch timing',
              controller: _timing,
              hint: '5:00 – 6:00 PM',
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter the batch timing' : null,
            ),
            const SizedBox(height: Gap.md),
            CustomTextField(
              label: 'Room',
              controller: _room,
              optional: true,
              hint: 'Room 2',
            ),
            const SizedBox(height: Gap.md),
            const FieldLabel('Subjects'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in app.academic.subjects)
                  FilterChip(
                    label: Text(s.name),
                    selected: _subjects.contains(s.id),
                    onSelected: (v) => setState(
                      () => v ? _subjects.add(s.id) : _subjects.remove(s.id),
                    ),
                    labelStyle: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _subjects.contains(s.id)
                          ? AppColors.onAccent
                          : AppColors.textPrimary,
                    ),
                  ),
              ],
            ),
            if (isEdit) ...[
              const SizedBox(height: Gap.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: Text(
                  'Running this year',
                  style: AppTextStyles.titleSmall,
                ),
                subtitle: Text(
                  'Paused classes are hidden from attendance.',
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
