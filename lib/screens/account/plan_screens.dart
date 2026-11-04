import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import '../auth/login_screen.dart';
import '../home/home_shell.dart';

/// Where to go after sign-in: the app, or the access screen when the
/// institute's trial/plan has ended.
Widget homeAfterSignIn() =>
    appState.accessAllowed ? const HomeShell() : const AccessScreen();

/// Shown instead of the app when the trial/plan has ended or the tuition was
/// blocked. Access returns once the admin allows it (admin web page).
class AccessScreen extends StatefulWidget {
  const AccessScreen({super.key});

  @override
  State<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends State<AccessScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    try {
      await appState.recheckAccess();
      if (!mounted) return;
      if (appState.accessAllowed) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
        showSuccess(context, 'Your account is active again.');
      } else {
        showInfo(context, 'Not activated yet. Please contact us.');
      }
    } catch (e) {
      if (mounted) showError(context, '$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    await appState.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = appState.accessStatus == 'blocked';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Icon(
              blocked ? Icons.block : Icons.lock_clock_outlined,
              size: 72,
              color: blocked ? AppColors.danger : AppColors.warning,
            ),
            const SizedBox(height: 18),
            Text(
              blocked ? 'Account paused' : 'Free trial has ended',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              appState.accessMessage.isEmpty
                  ? 'Please contact us to continue using Kaksha.'
                  : appState.accessMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your classes, students and records are safe and will be back as soon as your account is activated.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            const ContactSupportCard(),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _checking ? null : _retry,
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.refresh),
              label: const Text("I'VE BEEN ACTIVATED — CHECK AGAIN"),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _logout, child: const Text('Logout')),
          ],
        ),
      ),
    );
  }
}

/// Current plan: trial days left / allowed until / ended, with contact info.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final (title, detail, color) = switch (appState.accessStatus) {
      'active' => (
        'Active plan',
        appState.accessUntil == null
            ? 'Your account is active with no end date.'
            : 'Your account is active until ${formatDate(appState.accessUntil)}.',
        AppColors.success,
      ),
      'blocked' => (
        'Account paused',
        'Please contact us to activate your account.',
        AppColors.danger,
      ),
      _ => (
        'Free trial',
        '${appState.trialDaysRemaining} day(s) remaining. Contact us before it '
            'ends to keep using Kaksha.',
        AppColors.warning,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: ListView(
        padding: const EdgeInsets.all(15),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: color.withValues(alpha: .15),
                    child: Icon(Icons.workspace_premium, color: color),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(detail, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              'Staff logins are free. To activate or extend your plan, contact us:',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          const ContactSupportCard(),
        ],
      ),
    );
  }
}

/// Call / WhatsApp / email buttons for Kaksha support (from the server).
class ContactSupportCard extends StatelessWidget {
  const ContactSupportCard({super.key});

  Future<void> _open(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showError(context, 'Could not open the app.');
  }

  @override
  Widget build(BuildContext context) {
    final phone = appState.supportPhone;
    final email = appState.supportEmail;
    final about =
        'Kaksha activation: ${appState.instituteName} (${appState.userEmail ?? ''})';
    final waNumber = () {
      final d = phone.replaceAll(RegExp(r'\D'), '');
      return d.length == 10 ? '91$d' : d;
    }();
    return Card(
      child: Column(
        children: [
          if (phone.isNotEmpty) ...[
            ListTile(
              leading: const Icon(
                Icons.call_outlined,
                color: AppColors.primary,
              ),
              title: Text(phone),
              subtitle: const Text('Call us'),
              onTap: () => _open(context, Uri(scheme: 'tel', path: phone)),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              subtitle: const Text('Message us'),
              onTap: () => _open(
                context,
                Uri.parse(
                  'https://wa.me/$waNumber?text=${Uri.encodeComponent(about)}',
                ),
              ),
            ),
          ],
          if (email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline, color: AppColors.danger),
              title: Text(email),
              subtitle: const Text('Email us'),
              onTap: () => _open(
                context,
                Uri(
                  scheme: 'mailto',
                  path: email,
                  query: 'subject=${Uri.encodeComponent(about)}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
