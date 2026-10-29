import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/remote/api_client.dart';
import 'cards.dart';

/// Consistent confirmation dialogs. Every outward or irreversible action in the
/// demo (sending messages, publishing results, corrections) goes through here.
abstract final class ConfirmationDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData icon = Icons.help_outline_rounded,
    Widget? extra,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AppDialog(
        title: title,
        message: message,
        icon: icon,
        destructive: destructive,
        extra: extra,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.background,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Confirmation that requires a written reason (audit note).
  static Future<String?> showWithNote(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String noteLabel = 'Reason for change',
    String noteHint = 'e.g. Student arrived after attendance was taken',
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _NoteDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        noteLabel: noteLabel,
        noteHint: noteHint,
      ),
    );
  }
}

class _AppDialog extends StatelessWidget {
  const _AppDialog({
    required this.title,
    required this.message,
    required this.icon,
    required this.actions,
    this.destructive = false,
    this.extra,
  });

  final String title;
  final String message;
  final IconData icon;
  final List<Widget> actions;
  final bool destructive;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: IconWell(
        icon: icon,
        color: destructive ? AppColors.error : AppColors.accent,
        size: 48,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMuted,
            ),
            if (extra != null) ...[const SizedBox(height: Gap.md), extra!],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actionsPadding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      actions: actions,
    );
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.noteLabel,
    required this.noteHint,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String noteLabel;
  final String noteHint;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppDialog(
      title: widget.title,
      message: widget.message,
      icon: Icons.edit_note_rounded,
      extra: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: widget.noteLabel,
          hintText: widget.noteHint,
          fillColor: AppColors.surface,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _controller.text.trim().length < 3
              ? null
              : () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

enum ToastType { success, info, warning, error }

abstract final class AppToast {
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
  }) {
    final (icon, color) = switch (type) {
      ToastType.success => (
        Icons.check_circle_rounded,
        const Color(0xFF138A5E),
      ),
      ToastType.info => (Icons.info_rounded, const Color(0xFF2E6CB5)),
      ToastType.warning => (
        Icons.warning_amber_rounded,
        const Color(0xFFA86D00),
      ),
      ToastType.error => (Icons.error_rounded, const Color(0xFFC03A3B)),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

/// Runs a server action; on failure shows the server's message as a toast.
/// Returns true on success.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  try {
    await action();
  } on ApiException catch (e) {
    if (context.mounted) {
      AppToast.show(context, e.message, type: ToastType.error);
    }
    return false;
  }
  if (success != null && context.mounted) AppToast.show(context, success);
  return true;
}
