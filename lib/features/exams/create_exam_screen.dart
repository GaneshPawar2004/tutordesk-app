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
import 'exam_detail_screen.dart';

/// Create or edit an exam with one or more subjects.
class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key, this.exam, this.initialClassId});

  final Exam? exam;
  final String? initialClassId;

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _maxControllers = <String, TextEditingController>{};
  final _selected = <String>{};
  String? _classId;
  String? _yearId;
  DateTime _date = DateTime.now();
  var _isDraft = false;
  var _showSubjectError = false;

  bool get _isEdit => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;
    _classId = e?.classId ?? widget.initialClassId;
    if (e != null) {
      _name.text = e.name;
      _description.text = e.description;
      _date = e.date;
      _isDraft = e.isDraft;
      _yearId = e.academicYearId;
      for (final s in e.subjects) {
        _selected.add(s.subjectId);
        _controllerFor(s.subjectId).text = Fmt.marks(s.maxMarks);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _yearId ??= context.appRead.currentYear.id;
    if (!_isEdit && _classId != null && _selected.isEmpty) {
      _selectClassSubjects();
    }
  }

  TextEditingController _controllerFor(String subjectId) => _maxControllers
      .putIfAbsent(subjectId, () => TextEditingController(text: '50'));

  void _selectClassSubjects() {
    final cls = context.appRead.academic.classById(_classId!);
    setState(() {
      _selected
        ..clear()
        ..addAll(cls.subjectIds);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final c in _maxControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final app = context.appRead;
    setState(() => _showSubjectError = _selected.isEmpty);
    final valid = _formKey.currentState!.validate();
    if (!valid || _selected.isEmpty) {
      AppToast.show(
        context,
        'Please complete the highlighted fields.',
        type: ToastType.error,
      );
      return;
    }
    final subjects = [
      for (final s in app.academic.subjects.where(
        (s) => _selected.contains(s.id),
      ))
        ExamSubject(
          subjectId: s.id,
          maxMarks: double.parse(_controllerFor(s.id).text),
        ),
    ];
    if (_isEdit) {
      app.exams.update(
        widget.exam!,
        name: _name.text.trim(),
        classId: _classId!,
        date: _date,
        subjects: subjects,
        description: _description.text.trim(),
        isDraft: _isDraft,
      );
      Navigator.of(context).pop();
      AppToast.show(context, 'Exam updated');
      return;
    }
    final exam = app.createExam(
      name: _name.text.trim(),
      classId: _classId!,
      date: _date,
      subjects: subjects,
      description: _description.text.trim(),
      isDraft: _isDraft,
      yearId: _yearId,
    );
    replacePage(context, ExamDetailScreen(examId: exam.id));
    AppToast.show(context, _isDraft ? 'Exam saved as draft' : 'Exam scheduled');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final total = _selected.fold<double>(
      0,
      (sum, id) => sum + (double.tryParse(_controllerFor(id).text) ?? 0),
    );
    final hasMarks = widget.exam?.marks.isNotEmpty ?? false;

    return AppScaffold(
      title: _isEdit ? 'Edit exam' : 'Create exam',
      subtitle: app.academic.yearById(_yearId!).label,
      bottomBar: PrimaryButton(
        label: _isEdit
            ? 'Save changes'
            : (_isDraft ? 'Save draft' : 'Schedule exam'),
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
            CustomTextField(
              label: 'Exam name',
              controller: _name,
              hint: 'e.g. Sunday Weekly Test',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Enter an exam name' : null,
            ),
            const SizedBox(height: Gap.md),
            SelectField<String>(
              label: 'Academic year',
              value: _yearId,
              enabled: !_isEdit,
              options: [
                for (final y in app.academic.years.where(
                  (y) => y.status != YearStatus.closed,
                ))
                  SelectOption(y.id, y.label, subtitle: y.status.label),
              ],
              onChanged: (v) => setState(() => _yearId = v),
            ),
            const SizedBox(height: Gap.md),
            SelectField<String>(
              label: 'Class',
              value: _classId,
              hint: 'Select class',
              enabled: !hasMarks,
              options: [
                for (final c in app.visibleClasses)
                  SelectOption(
                    c.id,
                    c.name,
                    subtitle: Fmt.plural(
                      app.enrolledCount(c.id, _yearId),
                      'student',
                    ),
                  ),
              ],
              validator: (v) => v == null ? 'Select a class' : null,
              onChanged: (v) {
                setState(() => _classId = v);
                if (!_isEdit) _selectClassSubjects();
              },
            ),
            const SizedBox(height: Gap.md),
            DatePickerField(
              label: 'Exam date',
              value: _date,
              onChanged: (d) => setState(() => _date = d),
            ),
            const SectionHeader(
              title: 'Subjects & maximum marks',
              padding: EdgeInsets.only(top: Gap.lg, bottom: 8),
            ),
            SurfaceCard(
              padding: EdgeInsets.zero,
              borderColor: _showSubjectError && _selected.isEmpty
                  ? AppColors.error
                  : AppColors.border,
              child: Column(
                children: [
                  for (var i = 0; i < app.academic.subjects.length; i++) ...[
                    if (i > 0) const Divider(),
                    _SubjectRow(
                      subject: app.academic.subjects[i],
                      selected: _selected.contains(app.academic.subjects[i].id),
                      controller: _controllerFor(app.academic.subjects[i].id),
                      onToggle: (v) => setState(() {
                        final id = app.academic.subjects[i].id;
                        v ? _selected.add(id) : _selected.remove(id);
                      }),
                      onChanged: () => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_showSubjectError && _selected.isEmpty)
              Text(
                'Select at least one subject',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              )
            else
              Text(
                '${Fmt.plural(_selected.length, 'subject')} · total ${Fmt.marks(total)} marks',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: Gap.lg),
            CustomTextField(
              label: 'Description',
              controller: _description,
              optional: true,
              maxLines: 3,
              hint: 'Syllabus, instructions for students…',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: Gap.lg),
            const FieldLabel('Exam status'),
            SegmentedChoice<bool>(
              options: const [
                SelectOption(false, 'Scheduled'),
                SelectOption(true, 'Draft · not announced'),
              ],
              value: _isDraft,
              onChanged: (v) => setState(() => _isDraft = v),
            ),
            const SizedBox(height: 12),
            const DemoNotice(
              icon: Icons.visibility_off_outlined,
              text:
                  'Result publication: results stay unpublished until marks are entered and you choose Publish results.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.selected,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
  });

  final Subject subject;
  final bool selected;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: (v) => onToggle(v ?? false)),
          Expanded(
            child: GestureDetector(
              onTap: () => onToggle(!selected),
              child: Text(
                subject.name,
                style: AppTextStyles.titleSmall.copyWith(fontSize: 15),
              ),
            ),
          ),
          SizedBox(
            width: 108,
            child: TextFormField(
              controller: controller,
              enabled: selected,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                LengthLimitingTextInputFormatter(5),
              ],
              style: AppTextStyles.amount,
              onChanged: (_) => onChanged(),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (v) {
                if (!selected) return null;
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Required';
                if (n > 1000) return 'Too high';
                return null;
              },
              decoration: const InputDecoration(
                suffixText: 'max',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                errorStyle: TextStyle(fontSize: 11, height: 1),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
