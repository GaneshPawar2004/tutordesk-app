import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../models/models.dart';

/// Small pill describing a state. Colour is never the only signal — the label
/// always carries the meaning.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
    this.onCream = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;
  final bool onCream;

  @override
  Widget build(BuildContext context) {
    final fg = onCream ? _darken(color) : color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: onCream
            ? color.withValues(alpha: 0.18)
            : AppColors.tint(color, 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: fg),
            const SizedBox(width: 4),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: dense ? 11.5 : 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
  }
}

Color attendanceColor(AttendanceStatus s) => switch (s) {
  AttendanceStatus.present => AppColors.success,
  AttendanceStatus.absent => AppColors.error,
  AttendanceStatus.late => AppColors.warning,
  AttendanceStatus.leave => AppColors.info,
};

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({
    super.key,
    required this.status,
    this.dense = true,
  });

  final AttendanceStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: status.label,
    color: attendanceColor(status),
    dense: dense,
  );
}

Color paymentColor(PaymentStatus s) => switch (s) {
  PaymentStatus.paid => AppColors.success,
  PaymentStatus.partial => AppColors.warning,
  PaymentStatus.unpaid => AppColors.error,
};

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({
    super.key,
    required this.status,
    this.onCream = false,
  });

  final PaymentStatus status;
  final bool onCream;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: status.label,
    color: paymentColor(status),
    dense: true,
    onCream: onCream,
  );
}

Color examColor(ExamStatus s) => switch (s) {
  ExamStatus.draft => AppColors.textSecondary,
  ExamStatus.upcoming => AppColors.info,
  ExamStatus.completed => AppColors.warning,
  ExamStatus.published => AppColors.success,
};

class ExamStatusChip extends StatelessWidget {
  const ExamStatusChip({super.key, required this.status});

  final ExamStatus status;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: status.label, color: examColor(status), dense: true);
}

Color deliveryColor(DeliveryStatus s) => switch (s) {
  DeliveryStatus.queued => AppColors.textSecondary,
  DeliveryStatus.sending => AppColors.info,
  DeliveryStatus.sent => AppColors.accent,
  DeliveryStatus.delivered => AppColors.success,
  DeliveryStatus.failed => AppColors.error,
};

IconData deliveryIcon(DeliveryStatus s) => switch (s) {
  DeliveryStatus.queued => Icons.schedule_rounded,
  DeliveryStatus.sending => Icons.sync_rounded,
  DeliveryStatus.sent => Icons.check_rounded,
  DeliveryStatus.delivered => Icons.done_all_rounded,
  DeliveryStatus.failed => Icons.error_outline_rounded,
};

class MessageStatusChip extends StatelessWidget {
  const MessageStatusChip({super.key, required this.status});

  final DeliveryStatus status;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: status.label,
    color: deliveryColor(status),
    icon: deliveryIcon(status),
    dense: true,
  );
}

class ActiveStatusChip extends StatelessWidget {
  const ActiveStatusChip({
    super.key,
    required this.active,
    this.inactiveLabel = 'Inactive',
  });

  final bool active;
  final String inactiveLabel;

  @override
  Widget build(BuildContext context) => StatusChip(
    label: active ? 'Active' : inactiveLabel,
    color: active ? AppColors.success : AppColors.textSecondary,
    dense: true,
  );
}
