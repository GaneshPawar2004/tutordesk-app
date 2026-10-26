import 'package:flutter/material.dart';

import '../../core/navigation/nav.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_scope.dart';
import '../../data/app_state.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import 'fee_widgets.dart';
import 'student_fee_detail_screen.dart';

class StudentFeesScreen extends StatefulWidget {
  const StudentFeesScreen({
    super.key,
    this.initialStatus,
    this.initialYearId,
    this.onlyWithoutPlan = false,
    this.onlyOverdue = false,
  });

  final PaymentStatus? initialStatus;
  final String? initialYearId;
  final bool onlyWithoutPlan;
  final bool onlyOverdue;

  @override
  State<StudentFeesScreen> createState() => _StudentFeesScreenState();
}

class _StudentFeesScreenState extends State<StudentFeesScreen> {
  final _search = TextEditingController();
  late PaymentStatus? _status = widget.initialStatus;
  late String? _yearId = widget.initialYearId;
  late bool _onlyWithoutPlan = widget.onlyWithoutPlan;
  late bool _onlyOverdue = widget.onlyOverdue;
  String? _classId;
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(FeeRow r) {
    if (_onlyWithoutPlan) return r.plan == null;
    if (_onlyOverdue && r.summary.overdue <= 0) return false;
    if (_status != null && (r.plan == null || r.summary.status != _status)) {
      return false;
    }
    if (_classId != null && r.enrollment.classId != _classId) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return r.student.fullName.toLowerCase().contains(q) ||
        r.student.id.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    if (!app.isAdmin) return const AdminOnlyNotice();
    final yearId = _yearId ?? app.selectedYear.id;
    final year = app.academic.yearById(yearId);
    final rows = app.feeDirectory(yearId: yearId).where(_matches).toList();
    final total = rows.fold<int>(0, (s, r) => s + r.summary.outstanding);

    return AppScaffold(
      title: 'Student fees',
      subtitle:
          '${year.label} · ${Fmt.plural(rows.length, 'student')} · ${Fmt.currency(total)} due',
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    12,
                  ),
                  child: AppSearchBar(
                    controller: _search,
                    hint: 'Search student name or ID',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                FilterChips(
                  children: [
                    FilterPill(
                      label: 'Class',
                      value: _classId == null
                          ? 'All'
                          : app.academic.classById(_classId!).name,
                      active: _classId != null,
                      onTap: () async {
                        final picked = await showSelectSheet<String>(
                          context,
                          title: 'Class',
                          options: [
                            const SelectOption('', 'All classes'),
                            for (final c in app.academic.classes)
                              SelectOption(c.id, c.name),
                          ],
                          selected: _classId ?? '',
                        );
                        if (picked != null) {
                          setState(
                            () => _classId = picked.value.isEmpty
                                ? null
                                : picked.value,
                          );
                        }
                      },
                    ),
                    FilterPill(
                      label: 'Year',
                      value: year.label,
                      active: yearId != app.currentYear.id,
                      onTap: () async {
                        final picked = await showSelectSheet<String>(
                          context,
                          title: 'Academic year',
                          options: [
                            for (final y in app.academic.years)
                              SelectOption(y.id, y.label),
                          ],
                          selected: yearId,
                        );
                        if (picked != null) {
                          setState(() => _yearId = picked.value);
                        }
                      },
                    ),
                    FilterPill(
                      label: 'Status',
                      value: _onlyWithoutPlan
                          ? 'Fee not set'
                          : _onlyOverdue
                          ? 'Overdue'
                          : (_status?.label ?? 'All'),
                      active:
                          _status != null || _onlyWithoutPlan || _onlyOverdue,
                      onTap: () async {
                        final picked = await showSelectSheet<String>(
                          context,
                          title: 'Payment status',
                          options: [
                            const SelectOption('', 'All'),
                            for (final s in PaymentStatus.values)
                              SelectOption(s.name, s.label),
                            const SelectOption('overdue', 'Overdue'),
                            const SelectOption('none', 'Fee not set'),
                          ],
                          selected: _onlyWithoutPlan
                              ? 'none'
                              : _onlyOverdue
                              ? 'overdue'
                              : (_status?.name ?? ''),
                        );
                        if (picked == null) return;
                        setState(() {
                          _onlyWithoutPlan = picked.value == 'none';
                          _onlyOverdue = picked.value == 'overdue';
                          _status = PaymentStatus.values
                              .where((s) => s.name == picked.value)
                              .firstOrNull;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
              ],
            ),
          ),
          if (rows.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.search_off_rounded,
                title: 'No matching students',
                message: 'Change the filters or search to see fee records.',
              ),
            )
          else
            SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const InsetDivider(indent: 78),
              itemBuilder: (context, i) => _FeeRowTile(row: rows[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: Gap.xl)),
        ],
      ),
    );
  }
}

class _FeeRowTile extends StatelessWidget {
  const _FeeRowTile({required this.row});

  final FeeRow row;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = row.student;
    final summary = row.summary;
    return InkWell(
      onTap: () => pushPage(
        context,
        StudentFeeDetailScreen(enrollmentId: row.enrollment.id),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 12),
        child: Row(
          children: [
            AppAvatar(initials: s.initials, seed: s.id),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.fullName,
                    style: AppTextStyles.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${app.academic.classById(row.enrollment.classId).name} · ${app.academic.yearById(row.enrollment.academicYearId).label}',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (row.plan != null)
                    Text(
                      'Paid ${Fmt.currency(summary.paid)} of ${Fmt.currency(summary.agreed)}',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  row.plan == null ? '—' : Fmt.currency(summary.outstanding),
                  style: AppTextStyles.amount.copyWith(
                    color: summary.outstanding > 0
                        ? AppColors.textPrimary
                        : AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                if (row.plan == null)
                  const StatusChip(
                    label: 'Fee not set',
                    color: AppColors.textSecondary,
                    dense: true,
                  )
                else
                  PaymentStatusChip(status: summary.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
