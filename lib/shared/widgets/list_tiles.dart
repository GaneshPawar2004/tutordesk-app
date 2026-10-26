import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../models/models.dart';
import 'cards.dart';
import 'common.dart';
import 'status_chips.dart';

class StudentListTile extends StatelessWidget {
  const StudentListTile({
    super.key,
    required this.student,
    required this.className,
    this.onTap,
    this.trailing,
    this.showParent = true,
    this.active,
  });

  final Student student;
  final String className;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showParent;

  /// Overrides [Student.isActive] (e.g. for a withdrawn enrollment).
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final isActive = active ?? student.isActive;
    return Semantics(
      button: onTap != null,
      label: '${student.fullName}, ${student.id}, $className',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.page,
            vertical: 12,
          ),
          child: Row(
            children: [
              Opacity(
                opacity: isActive ? 1 : 0.55,
                child: AppAvatar(initials: student.initials, seed: student.id),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${student.id} · $className',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontFeatures: AppTextStyles.tabular,
                      ),
                    ),
                    if (showParent)
                      Text(
                        '${student.parentName} · ${Fmt.phoneSuffix(student.parentPhone)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  (isActive
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textTertiary,
                        )
                      : const ActiveStatusChip(active: false)),
            ],
          ),
        ),
      ),
    );
  }
}

class StaffListTile extends StatelessWidget {
  const StaffListTile({
    super.key,
    required this.member,
    required this.classNames,
    this.onTap,
  });

  final StaffMember member;
  final List<String> classNames;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pending = member.accountStatus == AccountStatus.invitationPending;
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(initials: member.initials, seed: member.id, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      member.designation,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!member.isActive)
                const ActiveStatusChip(active: false)
              else if (pending)
                const StatusChip(
                  label: 'Invite pending',
                  color: AppColors.warning,
                  dense: true,
                )
              else
                const ActiveStatusChip(active: true),
            ],
          ),
          const SizedBox(height: 14),
          _MetaLine(icon: Icons.phone_outlined, text: Fmt.phone(member.phone)),
          _MetaLine(icon: Icons.mail_outline_rounded, text: member.email),
          _MetaLine(
            icon: Icons.class_outlined,
            text: classNames.isEmpty
                ? 'No classes assigned'
                : classNames.join(', '),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${member.permissions.length} of ${StaffPermission.values.length} permissions · No fee access',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.schoolClass,
    required this.yearLabel,
    required this.studentCount,
    required this.staffNames,
    this.onTap,
    this.trailing,
  });

  final SchoolClass schoolClass;
  final String yearLabel;
  final int studentCount;
  final List<String> staffNames;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: schoolClass.isActive
                  ? AppColors.cream
                  : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${schoolClass.grade}',
              style: AppTextStyles.title.copyWith(
                color: schoolClass.isActive
                    ? AppColors.textOnCream
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        schoolClass.name,
                        style: AppTextStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ActiveStatusChip(
                      active: schoolClass.isActive,
                      inactiveLabel: 'Not running',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$yearLabel · ${Fmt.plural(studentCount, 'student')} · ${schoolClass.sessionLabel}',
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  staffNames.isEmpty
                      ? 'No staff assigned'
                      : staffNames.join(', '),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    color: staffNames.isEmpty
                        ? AppColors.warning
                        : AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
        ],
      ),
    );
  }
}
