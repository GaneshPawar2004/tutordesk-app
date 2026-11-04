import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/phone.dart';
import '../../widgets/common.dart';
import '../account/plan_screens.dart';
import '../fees/fee_dues_screen.dart';
import '../sms/pending_sms_screen.dart';

/// Something the teacher should look at, built from the loaded data.
class AppNotice {
  const AppNotice({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final void Function(BuildContext context) onTap;
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// Opens the SMS/WhatsApp sheet with a birthday wish for each student.
void showBirthdayWishes(BuildContext context) {
  final inst = appState.instituteName;
  showSmsSheet(
    context,
    title: 'Birthday wishes (${appState.birthdaysToday.length})',
    kind: 'birthday',
    listTitle: 'Birthday wishes ${formatDate(DateTime.now())}',
    items: [
      for (final s in appState.birthdaysToday)
        SmsItem(
          studentId: s.id,
          name: s.name,
          number: parentNumber(s),
          message:
              'Happy Birthday, ${s.name}! Wishing you a wonderful year ahead. '
              '- ${inst.isEmpty ? 'Your teacher' : inst}',
        ),
    ],
  );
}

/// Current notices: plan ending, birthdays, overdue and upcoming fees.
List<AppNotice> appNotices() {
  final out = <AppNotice>[];
  final today = DateUtils.dateOnly(DateTime.now());

  if (appState.accessStatus == 'trial' && appState.trialDaysRemaining <= 3) {
    out.add(
      AppNotice(
        icon: Icons.schedule,
        color: AppColors.warning,
        title: 'Free trial ends in ${appState.trialDaysRemaining} day(s)',
        detail: 'Contact us to keep using Kaksha without a break.',
        onTap: (c) => _push(c, const SubscriptionScreen()),
      ),
    );
  }
  if (appState.accessStatus == 'active' && appState.accessUntil != null) {
    final days = appState.accessUntil!.difference(DateTime.now()).inDays;
    if (days <= 7) {
      out.add(
        AppNotice(
          icon: Icons.schedule,
          color: AppColors.warning,
          title: 'Plan ends on ${formatDate(appState.accessUntil)}',
          detail: 'Contact us to extend your plan.',
          onTap: (c) => _push(c, const SubscriptionScreen()),
        ),
      );
    }
  }

  if (appState.pendingSms > 0) {
    out.add(
      AppNotice(
        icon: Icons.sms_failed_outlined,
        color: AppColors.danger,
        title: '${appState.pendingSms} parent SMS not sent yet',
        detail:
            'A phone ran out of SMS or sending stopped. Send the rest from your phone.',
        onTap: (c) => _push(c, const PendingSmsScreen()),
      ),
    );
  }

  final birthdays = appState.birthdaysToday;
  if (birthdays.isNotEmpty) {
    out.add(
      AppNotice(
        icon: Icons.cake_outlined,
        color: const Color(0xFFE91E63),
        title: '${birthdays.length} birthday(s) today',
        detail: birthdays.map((s) => s.name).join(', '),
        onTap: showBirthdayWishes,
      ),
    );
  }

  if (appState.canAccessFees) {
    final due = appState.students.where(
      (s) => !s.disabled && s.feesDue > 0 && s.feesDueDate != null,
    );
    final overdue = due.where(
      (s) => DateUtils.dateOnly(s.feesDueDate!).isBefore(today),
    );
    final soon = due.where((s) {
      final d = DateUtils.dateOnly(s.feesDueDate!);
      return !d.isBefore(today) && d.difference(today).inDays <= 7;
    });
    if (overdue.isNotEmpty) {
      final sum = overdue.fold<double>(0, (a, s) => a + s.feesDue);
      out.add(
        AppNotice(
          icon: Icons.warning_amber_rounded,
          color: AppColors.danger,
          title: '${overdue.length} student(s) with overdue fees',
          detail: '${formatMoney(sum)} pending past the due date.',
          onTap: (c) => _push(c, const FeeDuesScreen()),
        ),
      );
    }
    if (soon.isNotEmpty) {
      final sum = soon.fold<double>(0, (a, s) => a + s.feesDue);
      out.add(
        AppNotice(
          icon: Icons.event_note_outlined,
          color: AppColors.primary,
          title: '${soon.length} fee payment(s) due this week',
          detail: '${formatMoney(sum)} due in the next 7 days.',
          onTap: (c) => _push(c, const FeeDuesScreen()),
        ),
      );
    }
  }
  return out;
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final notices = appNotices();
          if (notices.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              message: "You're all caught up. No new notifications.",
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: notices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = notices[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.color.withValues(alpha: .12),
                    child: Icon(n.icon, color: n.color),
                  ),
                  title: Text(
                    n.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(n.detail),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => n.onTap(context),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
