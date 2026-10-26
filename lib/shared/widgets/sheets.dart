import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import 'buttons.dart';

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.subtitle, this.icon});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
}

/// Shows a modal sheet with consistent styling, sized to its content.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: builder(ctx),
      ),
    ),
  );
}

class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.title),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: AppTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

/// Single-choice bottom sheet selector. Returns the picked option.
Future<SelectOption<T>?> showSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  T? selected,
  String? subtitle,
}) {
  return showAppSheet<SelectOption<T>>(
    context,
    builder: (ctx) => BottomSheetSelector<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      selected: selected,
    ),
  );
}

class BottomSheetSelector<T> extends StatelessWidget {
  const BottomSheetSelector({
    super.key,
    required this.title,
    required this.options,
    this.selected,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SelectOption<T>> options;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: title, subtitle: subtitle),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: Gap.md),
            itemCount: options.length,
            itemBuilder: (context, i) {
              final o = options[i];
              final isSelected = o.value == selected;
              return ListTile(
                onTap: () => Navigator.of(context).pop(o),
                leading: o.icon == null
                    ? null
                    : Icon(
                        o.icon,
                        color: isSelected
                            ? AppColors.accent
                            : AppColors.textSecondary,
                      ),
                title: Text(
                  o.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textPrimary,
                  ),
                ),
                subtitle: o.subtitle == null
                    ? null
                    : Text(o.subtitle!, style: AppTextStyles.caption),
                trailing: isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.accent,
                      )
                    : const Icon(
                        Icons.circle_outlined,
                        color: AppColors.border,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Multi-select sheet. Returns the new selection, or null if dismissed.
Future<Set<T>?> showMultiSelectSheet<T>(
  BuildContext context, {
  required String title,
  required List<SelectOption<T>> options,
  required Set<T> selected,
  String confirmLabel = 'Done',
  String? subtitle,
}) {
  return showAppSheet<Set<T>>(
    context,
    builder: (ctx) => _MultiSelectSheet<T>(
      title: title,
      subtitle: subtitle,
      options: options,
      initial: selected,
      confirmLabel: confirmLabel,
    ),
  );
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.title,
    required this.options,
    required this.initial,
    required this.confirmLabel,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SelectOption<T>> options;
  final Set<T> initial;
  final String confirmLabel;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetHeader(title: widget.title, subtitle: widget.subtitle),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in widget.options)
                CheckboxListTile(
                  value: _selected.contains(o.value),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _selected.add(o.value);
                    } else {
                      _selected.remove(o.value);
                    }
                  }),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gap.page,
                  ),
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(o.label, style: AppTextStyles.titleSmall),
                  subtitle: o.subtitle == null
                      ? null
                      : Text(o.subtitle!, style: AppTextStyles.caption),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.sm,
            Gap.page,
            Gap.md,
          ),
          child: PrimaryButton(
            label: widget.confirmLabel,
            onPressed: () => Navigator.of(context).pop(_selected),
          ),
        ),
      ],
    );
  }
}
