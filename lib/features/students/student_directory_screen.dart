import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'student_form_screen.dart';
import 'student_profile_screen.dart';

enum _StatusFilter {
  active('Active'),
  inactive('Inactive'),
  all('All');

  const _StatusFilter(this.label);
  final String label;
}

/// Searchable, filterable student list. Used as the Students tab and as a
/// standalone page (e.g. "View students" from a class).
class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({
    super.key,
    this.initialClassId,
    this.standalone = false,
  });

  final String? initialClassId;
  final bool standalone;

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  final _search = TextEditingController();
  late String? _classId = widget.initialClassId;
  String? _yearId;
  var _status = _StatusFilter.active;
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(StudentEnrollment row) {
    final s = row.student;
    final isActive =
        s.isActive && row.enrollment.status != EnrollmentStatus.withdrawn;
    if (_status == _StatusFilter.active && !isActive) return false;
    if (_status == _StatusFilter.inactive && isActive) return false;
    if (_classId != null && row.enrollment.classId != _classId) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    return s.fullName.toLowerCase().contains(q) ||
        s.id.toLowerCase().contains(q) ||
        s.parentName.toLowerCase().contains(q) ||
        (digits.length >= 3 && s.parentPhone.contains(digits));
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _classId = widget.initialClassId;
      _status = _StatusFilter.active;
    });
  }

  Future<void> _pickClass() async {
    final app = context.appRead;
    final picked = await showSelectSheet<String>(
      context,
      title: 'Filter by class',
      options: [
        const SelectOption(
          '',
          'All classes',
          icon: Icons.all_inclusive_rounded,
        ),
        for (final c in app.isAdmin ? app.academic.classes : app.visibleClasses)
          SelectOption(
            c.id,
            c.name,
            subtitle: c.isActive ? c.sessionLabel : 'Not running this year',
          ),
      ],
      selected: _classId ?? '',
    );
    if (picked != null) {
      setState(() => _classId = picked.value.isEmpty ? null : picked.value);
    }
  }

  Future<void> _pickYear() async {
    final app = context.appRead;
    final picked = await showSelectSheet<String>(
      context,
      title: 'Academic year',
      options: [
        for (final y in app.academic.years)
          SelectOption(y.id, y.label, subtitle: y.status.label),
      ],
      selected: _yearId ?? app.selectedYear.id,
    );
    if (picked != null) setState(() => _yearId = picked.value);
  }

  Future<void> _pickStatus() async {
    final picked = await showSelectSheet<_StatusFilter>(
      context,
      title: 'Status',
      options: [for (final s in _StatusFilter.values) SelectOption(s, s.label)],
      selected: _status,
    );
    if (picked != null) setState(() => _status = picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final body = app.can(StaffPermission.viewStudents)
        ? _buildList(app)
        : _restricted();
    if (!widget.standalone) return body;
    return AppScaffold(title: 'Students', body: body);
  }

  Widget _restricted() => const EmptyState(
    icon: Icons.lock_outline_rounded,
    title: 'Student profiles are restricted',
    message:
        'Your account does not have permission to view student profiles. Ask the admin to enable it.',
  );

  Widget _buildList(AppState app) {
    final yearId = _yearId ?? app.selectedYear.id;
    final year = app.academic.yearById(yearId);
    final all = app.directory(yearId: yearId);
    final rows = all.where(_matches).toList();
    final activeTotal = all
        .where(
          (r) =>
              r.student.isActive &&
              r.enrollment.status != EnrollmentStatus.withdrawn,
        )
        .length;
    final filtersActive =
        _classId != widget.initialClassId ||
        _status != _StatusFilter.active ||
        _query.isNotEmpty;

    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.standalone)
                AppHeader(
                  eyebrow: year.label,
                  title: 'Students',
                  subtitle:
                      '${Fmt.plural(activeTotal, 'active student')}'
                      '${app.isStaff ? ' in your classes' : ''}',
                  trailing: app.isAdmin
                      ? CircleIconButton(
                          icon: Icons.person_add_alt_1_rounded,
                          tooltip: 'Add student',
                          filled: true,
                          onPressed: () =>
                              pushPage(context, const StudentFormScreen()),
                        )
                      : null,
                )
              else
                const SizedBox(height: Gap.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.page),
                child: AppSearchBar(
                  controller: _search,
                  hint: 'Search name, ID, parent or phone',
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 12),
              FilterChips(
                children: [
                  FilterPill(
                    label: 'Class',
                    value: _classId == null
                        ? 'All'
                        : app.academic.classById(_classId!).name,
                    active: _classId != null,
                    onTap: _pickClass,
                  ),
                  FilterPill(
                    label: 'Year',
                    value: year.label,
                    active: yearId != app.currentYear.id,
                    onTap: _pickYear,
                  ),
                  FilterPill(
                    label: 'Status',
                    value: _status.label,
                    active: _status != _StatusFilter.active,
                    onTap: _pickStatus,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  Gap.md,
                  Gap.page,
                  4,
                ),
                child: Row(
                  children: [
                    Text(
                      'SHOWING ${rows.length} OF ${all.length}',
                      style: AppTextStyles.label,
                    ),
                    const Spacer(),
                    if (filtersActive)
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (all.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: 'No students in ${year.label}',
              message: app.isAdmin
                  ? 'Add your first student or promote students into this academic year.'
                  : 'No students are enrolled in your classes for this year.',
              actionLabel: app.isAdmin ? 'Add student' : null,
              onAction: app.isAdmin
                  ? () => pushPage(context, const StudentFormScreen())
                  : null,
            ),
          )
        else if (rows.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching students',
              message:
                  'Try a different name, student ID or phone number, or clear the filters.',
              actionLabel: 'Clear filters',
              onAction: _clearFilters,
            ),
          )
        else
          SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const InsetDivider(indent: 78),
            itemBuilder: (context, i) {
              final row = rows[i];
              return StudentListTile(
                student: row.student,
                className: app.academic.classById(row.enrollment.classId).name,
                active:
                    row.student.isActive &&
                    row.enrollment.status != EnrollmentStatus.withdrawn,
                showParent:
                    app.appPrefs['Show parent phone numbers in lists'] ?? true,
                onTap: () => pushPage(
                  context,
                  StudentProfileScreen(studentId: row.student.id),
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
      ],
    );
  }
}

/// Small helper reused by pickers elsewhere.
String studentSubtitle(AppState app, Student s) =>
    '${s.id} · ${app.classNameOf(s.id)} · ${Fmt.phoneSuffix(s.parentPhone)}';
