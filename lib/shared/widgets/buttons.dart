import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.onAccent,
            ),
          )
        : _ButtonLabel(label: label, icon: icon);
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  /// Optional foreground colour, e.g. [AppColors.error] for destructive actions.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: color == null
          ? null
          : OutlinedButton.styleFrom(
              foregroundColor: color,
              side: BorderSide(
                color: color!.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
      child: _ButtonLabel(label: label, icon: icon),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (icon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Flexible(child: text),
      ],
    );
  }
}

/// Hero call-to-action: pill with a trailing round arrow badge.
class PillArrowButton extends StatelessWidget {
  const PillArrowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.inverted = false,
    this.icon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onPressed;

  /// Inverted = cream fill with dark badge; default = outlined dark.
  final bool inverted;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fg = inverted ? AppColors.textOnCream : AppColors.textPrimary;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: inverted ? AppColors.cream : Colors.transparent,
        shape: StadiumBorder(
          side: inverted
              ? BorderSide.none
              : const BorderSide(color: AppColors.textPrimary, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 7, 7, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(
                      color: fg,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: inverted ? AppColors.textOnCream : AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: inverted ? AppColors.accent : AppColors.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round outlined icon button used in headers.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badge = false,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool badge;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: filled ? AppColors.accent : AppColors.surface,
          shape: CircleBorder(
            side: BorderSide(
              color: filled ? AppColors.accent : AppColors.border,
            ),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: filled ? AppColors.onAccent : AppColors.textPrimary,
                  ),
                  if (badge)
                    Positioned(
                      top: 11,
                      right: 12,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
