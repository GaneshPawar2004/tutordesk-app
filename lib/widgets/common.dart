import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Grey icon + message shown when a list is empty.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: const Color(0xFFCFCFCF)),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// White text field used as an AppBar title while searching.
class SearchTitleField extends StatelessWidget {
  const SearchTitleField({
    super.key,
    required this.hint,
    required this.onChanged,
  });

  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      autofocus: true,
      onChanged: onChanged,
      cursorColor: Colors.white,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
    );
  }
}

/// Uppercase caption above an underlined text field (dialog style).
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.validator,
    this.autofocus = false,
    this.required = false,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool autofocus;
  final bool required;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldCaption(required ? '$label*' : label),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: autofocus,
            maxLength: maxLength,
            validator:
                validator ??
                (required
                    ? (v) => (v == null || v.trim().isEmpty)
                          ? 'This field is required'
                          : null
                    : null),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.fromLTRB(9, 10, 9, 10),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldCaption extends StatelessWidget {
  const FieldCaption(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textMuted,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// Underlined, tappable date field with a chevron (opens a date picker).
class DatePickerField extends StatelessWidget {
  const DatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? helper;
  final DateTime? firstDate;
  final DateTime? lastDate;

  Future<void> _pick(BuildContext context) async {
    final picked = await showAppDatePicker(
      context,
      initial: value ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(picked.date);
  }

  @override
  Widget build(BuildContext context) {
    String text = '';
    if (value != null) {
      text =
          '${value!.day.toString().padLeft(2, '0')}-'
          '${value!.month.toString().padLeft(2, '0')}-${value!.year}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldCaption(label),
          InkWell(
            onTap: () => _pick(context),
            child: Container(
              padding: const EdgeInsets.fromLTRB(9, 16, 9, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFDDDDDD), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(text, style: const TextStyle(fontSize: 14)),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Result of [showAppDatePicker]. `date == null` means the user pressed CLEAR.
class PickedDate {
  const PickedDate(this.date);
  final DateTime? date;
}

/// Date picker with CLEAR / CANCEL / SET, like the design. Returns null when
/// cancelled.
Future<PickedDate?> showAppDatePicker(
  BuildContext context, {
  required DateTime initial,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  DateTime selected = initial;
  final first = firstDate ?? DateTime(1950);
  final last = lastDate ?? DateTime(2100);

  return showDialog<PickedDate>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          return Dialog(
            backgroundColor: const Color(0xFFF0F0F7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(27),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: const Color(0xFF4F5D96),
                  padding: const EdgeInsets.fromLTRB(21, 18, 21, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selected.year}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${weekdays[selected.weekday - 1]}, '
                        '${selected.day} ${months[selected.month - 1]}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 33,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(
                      ctx,
                    ).colorScheme.copyWith(primary: const Color(0xFF4F5D96)),
                  ),
                  child: CalendarDatePicker(
                    initialDate: selected,
                    firstDate: first,
                    lastDate: last,
                    onDateChanged: (d) => setState(() => selected = d),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, const PickedDate(null)),
                        child: const Text('CLEAR'),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL'),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(ctx, PickedDate(selected)),
                        child: const Text('SET'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// CANCEL (outlined) + primary (filled) buttons at the bottom of dialogs.
class DialogButtons extends StatelessWidget {
  const DialogButtons({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.onCancel,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: OutlinedButton(
            onPressed: onCancel ?? () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(minimumSize: const Size(90, 39)),
            child: const FittedBox(
              child: Text('CANCEL', style: TextStyle(fontSize: 13)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: ElevatedButton(
            onPressed: onPrimary,
            style: ElevatedButton.styleFrom(minimumSize: const Size(75, 39)),
            child: FittedBox(
              child: Text(primaryLabel, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ),
      ],
    );
  }
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.successDark,
      ),
    );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: const Color(0xFF323232),
      ),
    );
}

void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: AppColors.danger,
      ),
    );
}

/// Placeholder for actions that need the backend / native integrations.
void showComingSoon(BuildContext context, String feature) => showInfo(
  context,
  '$feature will be available once the backend is connected.',
);

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'DELETE',
  Color confirmColor = AppColors.danger,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: confirmColor),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// "Notice" dialog with a title bar, close icon and OK button (screen 21).
Future<void> showNotice(
  BuildContext context,
  String message, {
  String title = 'Notice',
}) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(21, 14, 9, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(21),
            child: Text(
              message,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(82, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Light indigo info box with an (i) icon (attendance & marks screens).
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.children});

  final List<InlineSpan> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE0F5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: children),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
