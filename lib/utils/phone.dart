import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Number to contact parents on: parent's mobile first, else student contact.
String parentNumber(Student s) =>
    s.parentMobile.isNotEmpty ? s.parentMobile : s.contact;

/// Opens the phone's SMS app with [numbers] and [message] pre-filled. The SMS
/// is sent from the user's own SIM after they tap send in that app.
Future<void> openSms(
  BuildContext context,
  List<String> numbers,
  String message,
) async {
  final uri = Uri.parse(
    'sms:${numbers.join(',')}?body=${Uri.encodeComponent(message)}',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showError(context, 'Could not open SMS app.');
}

Future<void> openDialer(BuildContext context, String number) async {
  final ok = await launchUrl(
    Uri(scheme: 'tel', path: number),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) showError(context, 'Could not open dialer.');
}

class SmsItem {
  const SmsItem({
    required this.name,
    required this.number,
    required this.message,
  });

  final String name;
  final String number;
  final String message;
}

/// Bottom sheet listing one SMS per student. Each SEND opens the SMS app with
/// that student's message; students without a number are shown but disabled.
Future<void> showSmsSheet(
  BuildContext context, {
  required String title,
  required List<SmsItem> items,
}) {
  if (items.isEmpty) {
    showInfo(context, 'No students to message.');
    return Future.value();
  }
  final opened = <int>{};
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(
                'Tap SEND to open your SMS app. Messages go from your own SIM.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final hasNumber = it.number.isNotEmpty;
                  final done = opened.contains(i);
                  return ListTile(
                    title: Text(it.name),
                    subtitle: Text(
                      hasNumber ? it.message : 'No mobile number saved',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: hasNumber ? null : AppColors.danger,
                      ),
                    ),
                    trailing: done
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          )
                        : TextButton(
                            onPressed: hasNumber
                                ? () async {
                                    await openSms(ctx, [it.number], it.message);
                                    setState(() => opened.add(i));
                                  }
                                : null,
                            child: const Text('SEND'),
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
