import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'edit_marks_screen.dart';
import 'marks_sms.dart';

class TestsView extends StatelessWidget {
  const TestsView({
    super.key,
    required this.schoolClass,
    required this.onBack,
    required this.bottomBar,
  });

  final SchoolClass schoolClass;
  final VoidCallback onBack;
  final Widget bottomBar;

  Future<void> _addTest(BuildContext context) async {
    final result = await _showAddTestDialog(context);
    if (result == null || !context.mounted) return;
    final test = appState.addTest(schoolClass.id, result.$1, result.$2);
    _openMarks(context, test);
  }

  void _openMarks(BuildContext context, ClassTest test) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditMarksScreen(test: test)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottomBar,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBack,
        ),
        title: Text('Tests — ${schoolClass.name}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTest(context),
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final tests = appState.testsOf(schoolClass.id).reversed.toList();
          if (tests.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              message: 'No tests for this class yet. Tap + to add a test.',
            );
          }
          final studentCount = appState
              .studentsOf(schoolClass.id, includeDisabled: false)
              .length;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: tests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TestCard(
              test: tests[i],
              studentCount: studentCount,
              onEdit: () => _openMarks(context, tests[i]),
              onSend: () {
                if (tests[i].marks.isEmpty) {
                  showError(context, 'Enter marks before sending SMS.');
                } else {
                  showMarksSms(context, tests[i]);
                }
              },
              onDelete: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete test?',
                  message:
                      '"${tests[i].subject}" and all its marks will be removed.',
                );
                if (ok && context.mounted) {
                  appState.deleteTest(tests[i]);
                  showSuccess(context, 'Test deleted');
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.test,
    required this.studentCount,
    required this.onEdit,
    required this.onSend,
    required this.onDelete,
  });

  final ClassTest test;
  final int studentCount;
  final VoidCallback onEdit;
  final VoidCallback onSend;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final max = test.maxMarks == test.maxMarks.roundToDouble()
        ? test.maxMarks.toInt().toString()
        : test.maxMarks.toString();
    const muted = TextStyle(fontSize: 14, color: AppColors.textMuted);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.subject,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Max Marks: $max', style: muted),
                      const SizedBox(height: 3),
                      Text(
                        'Graded: ${test.gradedCount} / $studentCount students',
                        style: muted,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          test.subject,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 22),
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: onEdit,
                      child: const Text(
                        'EDIT MARKS',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onSend,
                      child: const Text(
                        'SEND MARKS SMS',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
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

/// "Add Test" dialog (screen 22). Returns (subject, maxMarks).
Future<(String, double)?> _showAddTestDialog(BuildContext context) {
  final subject = TextEditingController();
  final maxMarks = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<(String, double)>(
    context: context,
    builder: (ctx) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      title: const Text('Add Test', style: TextStyle(fontSize: 20)),
      content: SizedBox(
        width: 400,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledField(
                label: 'Subject / Chapter',
                required: true,
                hint: 'e.g. Mathematics',
                controller: subject,
                autofocus: true,
              ),
              LabeledField(
                label: 'Maximum marks',
                required: true,
                hint: 'e.g. 50',
                controller: maxMarks,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  return (n == null || n <= 0)
                      ? 'Enter valid maximum marks'
                      : null;
                },
              ),
              const Divider(height: 18),
              DialogButtons(
                primaryLabel: 'ADD',
                onPrimary: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, (
                      subject.text.trim(),
                      double.parse(maxMarks.text.trim()),
                    ));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
