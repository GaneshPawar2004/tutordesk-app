import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Bordered dark surface. Use sparingly — not everything needs a card.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.md),
    this.onTap,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.radius = AppRadius.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Warm cream card for featured summaries and key financial figures.
class CreamCard extends StatelessWidget {
  const CreamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Gap.page),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.textOnCream.withValues(alpha: 0.05),
        highlightColor: AppColors.textOnCream.withValues(alpha: 0.03),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.textOnCream),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Compact metric tile: icon, big tabular value, label.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.accent,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: '$label: $value',
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconWell(icon: icon, color: color, size: 34),
                const Spacer(),
                if (onTap != null)
                  const Icon(
                    Icons.north_east_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.metric),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded square holding a line icon on a tinted background.
class IconWell extends StatelessWidget {
  const IconWell({
    super.key,
    required this.icon,
    this.color = AppColors.accent,
    this.size = 40,
    this.onCream = false,
  });

  final IconData icon;
  final Color color;
  final double size;
  final bool onCream;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: onCream ? AppColors.textOnCream : AppColors.tint(color),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.52,
        color: onCream ? AppColors.accent : color,
      ),
    );
  }
}

/// Two-tone stat used inside summary cards.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.onCream = false,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool onCream;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.label.copyWith(
            fontSize: 10.5,
            color: onCream
                ? AppColors.textOnCreamMuted
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTextStyles.amount.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color:
                  valueColor ??
                  (onCream ? AppColors.textOnCream : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }
}
