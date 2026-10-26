import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

/// Standard page shell for pushed screens: consistent app bar, back button,
/// and an optional sticky action bar that stays above the keyboard.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
    this.bottomBar,
    this.floatingActionButton,
    this.onBack,
    this.bottom,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Widget? bottomBar;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? bottom;

  /// Overrides the back button, e.g. to confirm discarding changes.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: canPop || onBack != null
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            : null,
        titleSpacing: canPop ? 0 : Gap.page,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
          ],
        ),
        actions: [...actions, const SizedBox(width: 8)],
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          Expanded(child: body),
          if (bottomBar != null) StickyActionBar(child: bottomBar!),
        ],
      ),
    );
  }
}

/// A bar pinned to the bottom of a page for primary actions.
class StickyActionBar extends StatelessWidget {
  const StickyActionBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 4),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.page, 12, Gap.page, 12),
          child: child,
        ),
      ),
    );
  }
}

/// Large in-page heading used at the top of tab roots.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, Gap.md, Gap.page, Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: AppTextStyles.label),
                  const SizedBox(height: 6),
                ],
                Text(title, style: AppTextStyles.headline),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}
