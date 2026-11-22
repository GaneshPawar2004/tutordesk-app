import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/import_csv.dart';
import '../../widgets/common.dart';

/// "Import class": pick a class file exported from Teachers App (or Kaksha),
/// check the preview and bring its students, fees, attendance and marks in.
/// Without [into], the class is created (or an existing one with the same
/// name is used).
Future<void> importClassFile(BuildContext context, {SchoolClass? into}) async {
  final file = await FilePicker.pickFile(type: FileType.any);
  if (file == null || !context.mounted) return;
  final List<int> bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    if (context.mounted) {
      showError(context, 'Could not read the file. Please try again.');
    }
    return;
  }
  if (!context.mounted) return;

  final ClassImport data;
  try {
    data = parseClassFile(bytes);
  } on ImportFormatException catch (e) {
    await showNotice(context, e.message, title: 'Cannot import this file');
    return;
  }
  if (data.students.isEmpty) {
    if (context.mounted) showInfo(context, 'No students found in this file.');
    return;
  }
  if (!context.mounted) return;

  var target = into;
  var className = into?.name ?? _nameFromFile(file.name);
  if (target == null) {
    final name = await _askClassName(context, className);
    if (name == null || !context.mounted) return;
    className = name;
    target = appState.classes
        .where((c) => c.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
  }
  if (!context.mounted) return;
  final ok = await _confirm(context, data, className, existing: target != null);
  if (!ok || !context.mounted) return;

  final existingTarget = target;
  final result = await runApiValue(context, () async {
    final c = existingTarget ?? await appState.addClass(className);
    final imported = await appState.importClass(c.id, data.toBody());
    await appState.loadAll();
    return imported;
  });
  if (result == null || !context.mounted) return;
  final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
  await showNotice(
    context,
    '✅ ${result['students']} student(s) imported into $className.\n'
    '${result['attendanceDays']} attendance day(s) · ${result['tests']} test(s) · '
    '${result['payments']} fee payment(s).'
    '${skipped > 0 ? '\n\n$skipped student(s) were already in the class and were skipped.' : ''}',
    title: 'Import complete',
  );
}

/// "Class_8.csv" / "Class 8 - Kaksha.csv" → "Class 8".
String _nameFromFile(String file) {
  var n = file.replaceAll(RegExp(r'\.csv$', caseSensitive: false), '');
  n = n.replaceAll(RegExp(r'\s*-\s*Kaksha$'), '').replaceAll('_', ' ').trim();
  return n.isEmpty ? 'Imported class' : n;
}

Future<String?> _askClassName(BuildContext context, String initial) {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Import into class'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Class name in Kaksha (an existing class with this name is used).',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter a class name' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, ctrl.text.trim());
            }
          },
          child: const Text('NEXT'),
        ),
      ],
    ),
  );
}

Future<bool> _confirm(
  BuildContext context,
  ClassImport data,
  String className, {
  required bool existing,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Import from ${data.source}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing
                  ? 'Into the existing class "$className":'
                  : 'Into a new class "$className":',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _line(Icons.people_outline, '${data.students.length} students'),
            _line(
              Icons.event_available_outlined,
              '${data.attendanceDays} attendance day(s)',
            ),
            _line(Icons.assignment_outlined, '${data.tests.length} test(s)'),
            _line(
              Icons.payments_outlined,
              '${data.paymentCount} fee payment(s) · ${formatMoney(data.paidTotal)}',
            ),
            if (data.warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final w in data.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• $w',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
            ],
            if (existing) ...[
              const SizedBox(height: 10),
              const Text(
                'Students already in the class (same roll number, or same name) are skipped.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('IMPORT'),
        ),
      ],
    ),
  );
  return ok == true;
}

Widget _line(IconData icon, String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(text),
    ],
  ),
);
