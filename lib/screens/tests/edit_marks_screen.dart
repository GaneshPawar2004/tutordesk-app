import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'marks_sms.dart';

/// Enter marks for every student of a test (screen 23).
class EditMarksScreen extends StatefulWidget {
  const EditMarksScreen({super.key, required this.test});

  final ClassTest test;

  @override
  State<EditMarksScreen> createState() => _EditMarksScreenState();
}

class _EditMarksScreenState extends State<EditMarksScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _subject = TextEditingController(text: widget.test.subject);
  late final _maxMarks = TextEditingController(
    text: _fmt(widget.test.maxMarks),
  );
  final Map<String, TextEditingController> _marks = {};
  final Map<String, TextEditingController> _remarks = {};
  final Map<String, bool> _skip = {};
  String _query = '';

  late final List<Student> _students = appState.studentsOf(
    widget.test.classId,
    includeDisabled: false,
  )..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    for (final s in _students) {
      final m = widget.test.marks[s.id];
      _marks[s.id] = TextEditingController(
        text: m?.marks == null ? '' : _fmt(m!.marks!),
      );
      _remarks[s.id] = TextEditingController(text: m?.remarks ?? '');
      _skip[s.id] = m?.skip ?? false;
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _maxMarks.dispose();
    for (final c in [..._marks.values, ..._remarks.values]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _max => double.tryParse(_maxMarks.text.trim());

  bool _save() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showError(context, 'Please fix the highlighted fields.');
      return false;
    }
    final t = widget.test
      ..subject = _subject.text.trim()
      ..maxMarks = _max!;
    for (final s in _students) {
      t.marks[s.id] = StudentMark(
        marks: double.tryParse(_marks[s.id]!.text.trim()),
        remarks: _remarks[s.id]!.text.trim(),
        skip: _skip[s.id]!,
      );
    }
    appState.updateTest();
    return true;
  }

  void _onSave() {
    if (_save()) {
      showSuccess(context, 'Marks saved successfully!');
      Navigator.of(context).pop();
    }
  }

  void _onSaveAndSend() {
    if (_save()) showMarksSms(context, widget.test);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _students
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Marks')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          children: [
            LabeledField(
              label: 'Subject / Chapter',
              required: true,
              controller: _subject,
            ),
            LabeledField(
              label: 'Maximum marks',
              required: true,
              controller: _maxMarks,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                return (n == null || n <= 0) ? 'Enter valid marks' : null;
              },
            ),
            const SizedBox(height: 9),
            const Text(
              'Student Marks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search student by name…',
                contentPadding: EdgeInsets.fromLTRB(6, 15, 6, 12),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const InfoBanner(
              children: [
                TextSpan(text: "Leave a student's marks "),
                TextSpan(
                  text: 'blank',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ' to mark them absent — their parents get an "absent" SMS when you tap ',
                ),
                TextSpan(
                  text: 'Save & Send SMS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: '.'),
              ],
            ),
            const SizedBox(height: 9),
            if (_students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: Text(
                    'No students in this class yet.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            for (final s in visible) ...[
              _markCard(s),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'SAVE',
                    onPressed: _onSave,
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _ActionButton(
                    label: 'SAVE & SEND SMS',
                    onPressed: _onSaveAndSend,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _markCard(Student s) {
    final skipped = _skip[s.id]!;
    InputDecoration box(String hint) => InputDecoration(
      hintText: hint,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(3)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 10, 15, 15),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Checkbox(
                  value: skipped,
                  onChanged: (v) => setState(() => _skip[s.id] = v ?? false),
                ),
                const Text(
                  'Skip',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _marks[s.id],
                    enabled: !skipped,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: box('Marks'),
                    validator: (v) {
                      if (skipped) return null;
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return null;
                      final n = double.tryParse(value);
                      if (n == null || n < 0) return 'Invalid';
                      final max = _max;
                      if (max != null && n > max) return 'Max ${_fmt(max)}';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 4,
                  child: TextFormField(
                    controller: _remarks[s.id],
                    enabled: !skipped,
                    decoration: box('Remarks (optional)'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 13),
    );
    const padding = EdgeInsets.symmetric(horizontal: 6, vertical: 12);
    return SizedBox(
      height: 48,
      child: outlined
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(padding: padding),
              child: text,
            )
          : ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(padding: padding),
              child: text,
            ),
    );
  }
}
