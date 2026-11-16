import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'class_detail_screen.dart';

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  bool _searching = false;
  String _query = '';

  Future<void> _addOrRename({SchoolClass? existing}) async {
    final name = await showClassNameDialog(context, initial: existing?.name);
    if (name == null || !mounted) return;
    if (existing == null) {
      if (await runApi(context, () => appState.addClass(name)) && mounted) {
        showSuccess(context, 'Class added successfully!');
      }
    } else {
      if (await runApi(context, () => appState.renameClass(existing, name)) &&
          mounted) {
        showSuccess(context, 'Class renamed successfully!');
      }
    }
  }

  Future<void> _showOptions(SchoolClass c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename class'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            // Only the admin can delete classes.
            if (appState.isOwner)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Delete class',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') _addOrRename(existing: c);
    if (action == 'delete') {
      final ok = await confirmDialog(
        context,
        title: 'Delete ${c.name}?',
        message:
            'All students, attendance and tests of this class will be removed.',
      );
      if (ok && mounted) {
        if (await runApi(context, () => appState.deleteClass(c)) && mounted) {
          showSuccess(context, 'Class deleted');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_searching) {
              setState(() {
                _searching = false;
                _query = '';
              });
            } else {
              widget.onBack();
            }
          },
        ),
        title: _searching
            ? SearchTitleField(
                hint: 'Search classes…',
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Classes'),
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search, size: 21),
              onPressed: () => setState(() => _searching = true),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'sort') appState.sortClassesByName();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sort', child: Text('Sort by name')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrRename(),
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final classes = appState.classes
              .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();
          if (appState.classes.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              message: 'No classes yet. Click + to add a class.',
            );
          }
          if (classes.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              message: 'No matching classes.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: classes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final c = classes[i];
              final count = appState.studentsOf(c.id).length;
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClassDetailScreen(schoolClass: c),
                    ),
                  ),
                  onLongPress: () => _showOptions(c),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Class: ${c.name}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$count Students',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// "Add Class" dialog (screens 7-8). Returns the trimmed name or null.
Future<String?> showClassNameDialog(BuildContext context, {String? initial}) {
  final ctrl = TextEditingController(text: initial);
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (formKey.currentState!.validate()) {
          Navigator.pop(ctx, ctrl.text.trim());
        }
      }

      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14),
        contentPadding: const EdgeInsets.fromLTRB(18, 15, 18, 18),
        title: Text(
          initial == null ? 'Add Class' : 'Rename Class',
          style: const TextStyle(fontSize: 20),
        ),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: 'Class name',
                  hint: 'Enter class name',
                  controller: ctrl,
                  autofocus: true,
                  validator: (v) {
                    final name = v?.trim() ?? '';
                    if (name.isEmpty) return 'Please enter a class name';
                    final duplicate = appState.classes.any(
                      (c) =>
                          c.name.toLowerCase() == name.toLowerCase() &&
                          c.name != initial,
                    );
                    return duplicate ? 'This class already exists' : null;
                  },
                ),
                const Divider(height: 18),
                DialogButtons(
                  primaryLabel: initial == null ? 'ADD' : 'SAVE',
                  onPrimary: submit,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
