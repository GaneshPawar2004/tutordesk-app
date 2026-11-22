import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';

/// Ready-made texts for "Send message to class" ({name} = student's name).
const _templates = [
  (
    'Holiday',
    'Dear Parent, the tuition will remain closed tomorrow on account of the holiday. Classes resume as usual after that.',
  ),
  (
    'Exam / test',
    'Dear Parent, there is a test for {name} this week. Please make sure {name} revises at home.',
  ),
  (
    'Parent meeting',
    'Dear Parent, a parent–teacher meeting is planned this Sunday at 11 AM. Please attend to discuss {name}\'s progress.',
  ),
  (
    'Fees',
    'Dear Parent, this is a reminder to clear the pending tuition fees of {name}. Thank you.',
  ),
];

/// Compose a custom message and send it to every active student's parent of
/// [c] by SMS (from this phone's SIM) or WhatsApp. {name} becomes the
/// student's name. Sending the same text again the same day does not repeat
/// it for parents already messaged.
Future<void> showClassMessage(BuildContext context, SchoolClass c) async {
  final students = appState.studentsOf(c.id, includeDisabled: false)
    ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  if (students.isEmpty) {
    showInfo(context, 'No students in this class yet.');
    return;
  }
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _ComposeDialog(count: students.length, className: c.name),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final inst = appState.instituteName;
  final sign = inst.isEmpty ? '' : ' - $inst';
  await showSmsSheet(
    context,
    title: 'Message to ${c.name} (${students.length})',
    kind: 'other',
    listTitle:
        '${c.name} · ${text.length > 30 ? '${text.substring(0, 30)}…' : text}',
    classId: c.id,
    // Same text, same class, same day → one list (no repeats).
    dedupeKey:
        'msg:${c.id}:${AppState.dateKey(DateTime.now())}:${_stableHash(text)}',
    items: [
      for (final s in students)
        SmsItem(
          studentId: s.id,
          name: s.name,
          number: parentNumber(s),
          message: '${text.replaceAll('{name}', s.name).trim()}$sign',
        ),
    ],
  );
}

/// FNV-1a hash: the same on every phone (String.hashCode is not guaranteed).
String _stableHash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16);
}

class _ComposeDialog extends StatefulWidget {
  const _ComposeDialog({required this.count, required this.className});
  final int count;
  final String className;

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Message to ${widget.className}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goes to the parents of ${widget.count} active student(s). '
              'Write {name} to put each student\'s name.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (label, body) in _templates)
                  ActionChip(
                    label: Text(label),
                    onPressed: () => setState(() => _ctrl.text = body),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              minLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                hintText: 'Type your message…',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: _ctrl.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _ctrl.text.trim()),
          child: const Text('NEXT'),
        ),
      ],
    );
  }
}

/// Copy students of [from] into another class (details only — fees,
/// attendance and marks start fresh), e.g. for the next academic year.
Future<void> showCopyStudents(BuildContext context, SchoolClass from) async {
  final others = appState.classes.where((c) => c.id != from.id).toList();
  if (others.isEmpty) {
    showInfo(context, 'Add another class first, then copy students into it.');
    return;
  }
  final students = appState.studentsOf(from.id)
    ..sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
  if (students.isEmpty) {
    showInfo(context, 'No students in this class to copy.');
    return;
  }
  final picked = await showDialog<({String to, List<String> ids})>(
    context: context,
    builder: (_) => _CopyDialog(others: others, students: students),
  );
  if (picked == null || !context.mounted) return;
  final result = await runApiValue(
    context,
    () => appState.copyStudents(from.id, picked.to, picked.ids),
  );
  if (result == null || !context.mounted) return;
  final target = appState.classById(picked.to)?.name ?? '';
  await showNotice(
    context,
    '✅ ${result.copied} student(s) copied to $target.'
    '${result.skipped.isEmpty ? '' : '\n\nSkipped (roll number already used there): ${result.skipped.join(', ')}.'}'
    '\n\nFees, attendance and marks start fresh in the new class.',
    title: 'Students copied',
  );
}

class _CopyDialog extends StatefulWidget {
  const _CopyDialog({required this.others, required this.students});
  final List<SchoolClass> others;
  final List<Student> students;

  @override
  State<_CopyDialog> createState() => _CopyDialogState();
}

class _CopyDialogState extends State<_CopyDialog> {
  late String _to = widget.others.first.id;

  // Active students are ticked; disabled ones are not.
  late final Set<String> _ids = {
    for (final s in widget.students)
      if (!s.disabled) s.id,
  };

  @override
  Widget build(BuildContext context) {
    final all = _ids.length == widget.students.length;
    return AlertDialog(
      title: const Text('Copy students'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Copy to class'),
              items: [
                for (final c in widget.others)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _to = v ?? _to),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: all,
              title: Text('All students (${_ids.length} selected)'),
              onChanged: (v) => setState(() {
                _ids.clear();
                if (v == true) _ids.addAll(widget.students.map((s) => s.id));
              }),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in widget.students)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: _ids.contains(s.id),
                      title: Text(
                        '${s.rollNo.isEmpty ? '' : '#${s.rollNo}  '}${s.name}',
                      ),
                      subtitle: s.disabled ? const Text('Disabled') : null,
                      onChanged: (v) => setState(
                        () => v == true ? _ids.add(s.id) : _ids.remove(s.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: _ids.isEmpty
              ? null
              : () => Navigator.pop(context, (to: _to, ids: _ids.toList())),
          child: Text('COPY ${_ids.length}'),
        ),
      ],
    );
  }
}
