import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'buttons.dart';
import 'cards.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, 12),
    this.trailing,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title.toUpperCase(), style: AppTextStyles.label),
            ),
          ),
          ?trailing,
          if (actionLabel != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: compact ? Gap.lg : 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                icon,
                size: compact ? 26 : 32,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Gap.md),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// Grey placeholder blocks shown while content "loads".
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.rows = 5});

  final int rows;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_controller),
      child: Column(
        children: [
          for (var i = 0; i < widget.rows; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, 12),
              child: Row(
                children: [
                  const _Bone(width: 44, height: 44, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(width: 120.0 + (i % 3) * 30, height: 14),
                        const SizedBox(height: 8),
                        const _Bone(width: 90, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.radius = 6});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: AppColors.surfaceElevated,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Shows [SkeletonList] briefly on first build, then the child — mimics the
/// short load the real API will have.
class SimulatedLoad extends StatefulWidget {
  const SimulatedLoad({super.key, required this.child, this.rows = 5});

  final Widget child;
  final int rows;

  @override
  State<SimulatedLoad> createState() => _SimulatedLoadState();
}

class _SimulatedLoadState extends State<SimulatedLoad> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _ready
          ? KeyedSubtree(key: const ValueKey('ready'), child: widget.child)
          : Padding(
              key: const ValueKey('loading'),
              padding: const EdgeInsets.only(top: Gap.md),
              child: SkeletonList(rows: widget.rows),
            ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 44,
    this.accent = false,
  });

  final String initials;

  /// Stable value (e.g. an ID) that picks the avatar colour.
  final String seed;
  final double size;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.avatarPalette;
    final bg = accent
        ? AppColors.accent
        : palette[seed.hashCode.abs() % palette.length];
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: accent ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            color: accent ? AppColors.onAccent : AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onCream = false,
    this.valueStyle,
  });

  final String label;
  final String value;
  final IconData? icon;
  final bool onCream;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final muted = onCream
        ? AppColors.textOnCreamMuted
        : AppColors.textSecondary;
    final strong = onCream ? AppColors.textOnCream : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: muted),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: strong,
                    fontFeatures: AppTextStyles.tabular,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.accent,
    this.trackColor = AppColors.surfaceHighlight,
    this.height = 6,
  });

  final double value;
  final Color color;
  final Color trackColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: color,
          backgroundColor: trackColor,
        ),
      ),
    );
  }
}

/// Labelled notice used to make demo limitations explicit.
class DemoNotice extends StatelessWidget {
  const DemoNotice({
    super.key,
    required this.text,
    this.icon = Icons.science_outlined,
    this.color = AppColors.info,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(color, 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A navigational list row with icon well, title, subtitle and chevron.
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color = AppColors.accent,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.page, vertical: 12),
        child: Row(
          children: [
            IconWell(icon: icon, color: color, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
          ],
        ),
      ),
    );
  }
}

/// Subtle inline divider indented to align with list content.
class InsetDivider extends StatelessWidget {
  const InsetDivider({super.key, this.indent = Gap.page});

  final double indent;

  @override
  Widget build(BuildContext context) =>
      Divider(indent: indent, endIndent: Gap.page);
}
