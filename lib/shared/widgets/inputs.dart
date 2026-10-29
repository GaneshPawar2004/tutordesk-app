import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import 'sheets.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (optional) ...[
            const SizedBox(width: 6),
            Text(
              'Optional',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.prefixText,
    this.prefixIcon,
    this.suffix,
    this.optional = false,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onChanged,
    this.enabled = true,
    this.helper,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.autofocus = false,
    this.obscureText = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final String? prefixText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool optional;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String? helper;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final bool autofocus;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label, optional: optional),
        TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          minLines: 1,
          maxLength: maxLength,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          textInputAction: maxLines > 1
              ? TextInputAction.newline
              : textInputAction,
          textCapitalization: textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: AppTextStyles.caption.copyWith(fontSize: 12),
            counterText: '',
            prefixText: prefixText,
            prefixStyle: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Indian mobile number field with +91 prefix and 10-digit validation.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.label,
    required this.controller,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final bool optional;

  static String? validate(String? v, {bool optional = false}) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return optional ? null : 'Enter a mobile number';
    if (digits.length != 10) return 'Enter a 10-digit mobile number';
    if (!RegExp(r'^[6-9]').hasMatch(digits)) {
      return 'Indian mobile numbers start with 6–9';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      controller: controller,
      optional: optional,
      hint: '98765 43210',
      prefixText: '+91  ',
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: (v) => validate(v, optional: optional),
    );
  }
}

/// Rupee amount field (whole rupees).
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.onChanged,
    this.helper,
    this.optional = false,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final String? helper;
  final bool optional;

  static int parse(String text) =>
      int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      label: label,
      controller: controller,
      hint: '0',
      helper: helper,
      optional: optional,
      prefixText: '₹ ',
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(8),
      ],
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// Tappable field shell matching text inputs, used by date and select fields.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.text,
    required this.onTap,
    required this.icon,
    this.placeholder = false,
    this.errorText,
    this.enabled = true,
  });

  final String text;
  final VoidCallback onTap;
  final IconData icon;
  final bool placeholder;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = errorText != null ? AppColors.error : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: enabled ? AppColors.surface : AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: enabled ? border : AppColors.borderSubtle),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          color: placeholder || !enabled
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, size: 20, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(
              errorText!,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.optional = false,
    this.validator,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool optional;
  final String? Function(DateTime? value)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      validator: (_) => validator?.call(value),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, optional: optional),
          _FieldShell(
            text: value == null ? 'Select date' : Fmt.longDate(value!),
            placeholder: value == null,
            icon: Icons.calendar_today_outlined,
            errorText: state.errorText,
            enabled: enabled,
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: firstDate ?? DateTime(now.year - 20),
                lastDate: lastDate ?? DateTime(now.year + 3),
              );
              if (picked != null) {
                onChanged(picked);
                state.didChange(picked);
              }
            },
          ),
        ],
      ),
    );
  }
}

class SelectField<T> extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hint = 'Select',
    this.sheetTitle,
    this.validator,
    this.optional = false,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String hint;
  final String? sheetTitle;
  final String? Function(T? value)? validator;
  final bool optional;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    SelectOption<T>? selected;
    for (final o in options) {
      if (o.value == value) selected = o;
    }
    return FormField<T>(
      validator: (_) => validator?.call(value),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, optional: optional),
          _FieldShell(
            text: selected?.label ?? hint,
            placeholder: selected == null,
            icon: Icons.expand_more_rounded,
            errorText: state.errorText,
            enabled: enabled,
            onTap: () async {
              final picked = await showSelectSheet<T>(
                context,
                title: sheetTitle ?? label,
                options: options,
                selected: value,
              );
              if (picked != null) {
                onChanged(picked.value);
                state.didChange(picked.value);
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Row of pill toggles for small, mutually exclusive choices.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SelectOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.label),
            selected: o.value == value,
            onSelected: (_) => onChanged(o.value),
            labelStyle: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: o.value == value
                  ? AppColors.onAccent
                  : AppColors.textPrimary,
            ),
            side: BorderSide(
              color: o.value == value ? AppColors.accent : AppColors.border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
      ],
    );
  }
}

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
          ),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

/// A filter pill showing "Label: Value ▾"; highlighted when not default.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label filter: $value',
      child: Material(
        color: active
            ? AppColors.tint(AppColors.accent, 0.12)
            : AppColors.surface,
        shape: StadiumBorder(
          side: BorderSide(color: active ? AppColors.accent : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$label: ',
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.accent : AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: active ? AppColors.accent : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [FilterPill]s.
class FilterChips extends StatelessWidget {
  const FilterChips({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Gap.page),
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}
