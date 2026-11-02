import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../classes/class_detail_screen.dart';
import 'student_actions_dialog.dart';
import 'student_form_dialog.dart';

enum _SortBy { roll, name }

class StudentsView extends StatefulWidget {
  const StudentsView({
    super.key,
    required this.schoolClass,
    required this.onOpenTab,
    required this.bottomBar,
  });

  final SchoolClass schoolClass;
  final ValueChanged<ClassTab> onOpenTab;
  final Widget bottomBar;

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  bool _searching = false;
  String _query = '';
  _SortBy _sortBy = _SortBy.roll;

  Future<void> _addStudent() async {
    final added = await showStudentFormDialog(
      context,
      schoolClass: widget.schoolClass,
    );
    if (added == true && mounted) {
      showSuccess(context, 'Student added successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.schoolClass;
    return Scaffold(
      bottomNavigationBar: widget.bottomBar,
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
              Navigator.of(context).pop();
            }
          },
        ),
        title: _searching
            ? SearchTitleField(
                hint: 'Search students…',
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(c.name),
        actions: [
          if (!_searching)
            IconButton(
              icon: const Icon(Icons.search, size: 21),
              onPressed: () => setState(() => _searching = true),
            ),
          PopupMenuButton<_SortBy>(
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _SortBy.roll,
                checked: _sortBy == _SortBy.roll,
                child: const Text('Sort by roll no'),
              ),
              CheckedPopupMenuItem(
                value: _SortBy.name,
                checked: _sortBy == _SortBy.name,
                child: const Text('Sort by name'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addStudent,
        child: const Icon(Icons.add, size: 28),
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final all = appState.studentsOf(c.id);
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.person_outline,
              message: 'No students yet. Click + to add a student.',
            );
          }
          final q = _query.toLowerCase();
          final students =
              all
                  .where(
                    (s) =>
                        s.name.toLowerCase().contains(q) ||
                        s.rollNo.contains(q),
                  )
                  .toList()
                ..sort(
                  (a, b) => _sortBy == _SortBy.roll
                      ? a.rollNumber.compareTo(b.rollNumber)
                      : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                );
          if (students.isEmpty) {
            return const EmptyState(
              icon: Icons.search_off,
              message: 'No matching students.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: students.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, i) => _StudentTile(
              student: students[i],
              onTap: () => showStudentActionsDialog(
                context,
                student: students[i],
                schoolClass: c,
                onOpenTab: widget.onOpenTab,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({required this.student, required this.onTap});

  final Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = student;
    return Opacity(
      opacity: s.disabled ? 0.55 : 1,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                StudentAvatar(radius: 24, disabled: s.disabled),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.rollNo.isEmpty ? 'Roll: —' : 'Roll: ${s.rollNo}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (s.disabled)
                  const StatusBadge(
                    label: 'Disabled',
                    color: Color(0xFFB26A00),
                    background: Color(0xFFFFF0D9),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, this.radius = 32, this.disabled = false});

  final double radius;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: disabled ? Colors.grey : AppColors.primary,
      child: Icon(
        Icons.person_outline,
        color: Colors.white,
        size: radius * 0.95,
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
