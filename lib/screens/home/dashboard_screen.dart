import 'package:flutter/material.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../account/plan_screens.dart';
import '../account/profile_screen.dart';
import '../auth/login_screen.dart';
import '../fees/fee_dues_screen.dart';
import 'notifications_screen.dart';
import '../reports/reports_screen.dart';
import '../users/users_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onOpenClasses});

  final VoidCallback onOpenClasses;

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmLabel: 'LOGOUT',
    );
    if (!ok || !context.mounted) return;
    await appState.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          ListenableBuilder(
            listenable: appState,
            builder: (context, _) {
              final count = appNotices().length;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: const Icon(Icons.notifications_none, size: 24),
                ),
                onPressed: () => _push(context, const NotificationsScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'profile':
                  _push(context, const ProfileScreen());
                case 'subscription':
                  _push(context, const SubscriptionScreen());
                case 'logout':
                  _logout(context);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'profile', child: Text('My Profile')),
              PopupMenuItem(
                value: 'subscription',
                child: Text('Subscriptions'),
              ),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => RefreshIndicator(
          onRefresh: () async {
            try {
              await appState.loadAll();
            } catch (e) {
              if (context.mounted) showError(context, '$e');
            }
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              if (appState.accessStatus == 'trial')
                InkWell(
                  onTap: () => _push(context, const SubscriptionScreen()),
                  child: _TrialBanner(days: appState.trialDaysRemaining),
                ),
              if (appState.accessStatus == 'trial') const SizedBox(height: 12),
              if (appState.birthdaysToday.isNotEmpty) ...[
                _BirthdayCard(onTap: () => showBirthdayWishes(context)),
                const SizedBox(height: 12),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.75,
                children: [
                  _StatTile(
                    icon: Icons.school_outlined,
                    value: '${appState.classes.length}',
                    label: 'Classes',
                    colors: AppColors.tileBlue,
                    onTap: onOpenClasses,
                  ),
                  _StatTile(
                    icon: Icons.people_outline,
                    value: '${appState.students.length}',
                    label: 'Students',
                    colors: AppColors.tileGreen,
                    onTap: onOpenClasses,
                  ),
                  _StatTile(
                    icon: Icons.event_available_outlined,
                    value: '${appState.presentToday}',
                    label: 'Present Today',
                    colors: AppColors.tileOrange,
                    onTap: () => _push(context, const ReportsScreen()),
                  ),
                  _StatTile(
                    icon: Icons.payments_outlined,
                    value: appState.canAccessFees
                        ? formatMoney(appState.dueFeesOf(null))
                        : '—',
                    label: 'Fees Due',
                    colors: AppColors.tileRed,
                    onTap: () => _openFeeDues(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children:
                    [
                          _QuickAction(
                            icon: Icons.school_outlined,
                            label: 'Classes',
                            onTap: onOpenClasses,
                          ),
                          _QuickAction(
                            icon: Icons.badge_outlined,
                            label: 'Users',
                            onTap: () => appState.isOwner
                                ? _push(context, const UsersScreen())
                                : showInfo(
                                    context,
                                    'Only the admin can manage users.',
                                  ),
                          ),
                          _QuickAction(
                            icon: Icons.bar_chart,
                            label: 'Reports',
                            onTap: () => _push(context, const ReportsScreen()),
                          ),
                          _QuickAction(
                            icon: Icons.request_quote_outlined,
                            label: 'Fee Dues',
                            onTap: () => _openFeeDues(context),
                          ),
                        ]
                        .expand(
                          (w) => [Expanded(child: w), const SizedBox(width: 9)],
                        )
                        .toList()
                      ..removeLast(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openFeeDues(BuildContext context) => appState.canAccessFees
      ? _push(context, const FeeDuesScreen())
      : showInfo(context, 'You do not have access to fees.');
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFE65100);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Free Trial — $days days remaining',
              style: const TextStyle(
                color: orange,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final List<Color> colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 3,
      shadowColor: colors.first.withValues(alpha: 0.4),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: AppColors.textMuted, size: 20),
              const SizedBox(height: 5),
              FittedBox(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthdayCard extends StatelessWidget {
  const _BirthdayCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = appState.birthdaysToday.map((s) => s.name).join(', ');
    return Card(
      color: const Color(0xFFFCE4EC),
      child: ListTile(
        leading: const Icon(Icons.cake_outlined, color: Color(0xFFE91E63)),
        title: Text(
          'Birthday today: $names',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text('Tap to send wishes by SMS or WhatsApp'),
        trailing: const Icon(Icons.send, color: Color(0xFFE91E63)),
        onTap: onTap,
      ),
    );
  }
}
