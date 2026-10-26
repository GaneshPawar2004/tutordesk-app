import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_scope.dart';
import '../../shared/widgets/widgets.dart';

/// Demo entry point. Picks a preview role — this is not authentication.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _pickStaff(BuildContext context) async {
    final app = context.appRead;
    final members = app.staff.all.where((s) => s.isActive).toList();
    final picked = await showSelectSheet<String>(
      context,
      title: 'Preview as staff',
      subtitle: 'Each staff member sees only what their permissions allow.',
      options: [
        for (final m in members)
          SelectOption(
            m.id,
            m.name,
            subtitle: '${m.designation} · ${m.permissions.length} permissions',
            icon: Icons.person_outline_rounded,
          ),
      ],
      selected: members.first.id,
    );
    if (picked != null) app.signInAsStaff(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _FlowLinesPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: Gap.lg),
                        const _Logo(),
                        const SizedBox(height: 40),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Everything your tuition needs, ',
                              ),
                              TextSpan(
                                text: 'in one place.',
                                style: AppTextStyles.display.copyWith(
                                  color: AppColors.accent,
                                ),
                              ),
                            ],
                          ),
                          style: AppTextStyles.display,
                        ),
                        const SizedBox(height: Gap.md),
                        Text(
                          'Students, attendance, fees, exams and parent messages — '
                          'built for tuition owners and teachers.',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: Gap.lg),
                        const _FeatureCards(),
                        const Spacer(),
                        const SizedBox(height: Gap.lg),
                        Text('CHOOSE A PREVIEW', style: AppTextStyles.label),
                        const SizedBox(height: 12),
                        PillArrowButton(
                          label: 'Admin preview',
                          inverted: true,
                          onPressed: () => context.appRead.signInAsAdmin(),
                        ),
                        const SizedBox(height: 12),
                        PillArrowButton(
                          label: 'Staff preview',
                          icon: Icons.person_outline_rounded,
                          onPressed: () => _pickStaff(context),
                        ),
                        const SizedBox(height: Gap.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Demo access modes · sample data only, nothing is sent',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Gap.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: AppColors.onAccent,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Tutor'),
              TextSpan(
                text: 'Desk',
                style: TextStyle(color: AppColors.accent),
              ),
            ],
          ),
          style: AppTextStyles.title.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FeatureCard(
            title: 'Attendance in a minute',
            body: 'Mark a full class and notify parents.',
            icon: Icons.fact_check_outlined,
            background: AppColors.cream,
            foreground: AppColors.textOnCream,
            iconBackground: AppColors.accent,
            iconColor: AppColors.onAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FeatureCard(
            title: 'Results to parents',
            body: 'Marks become ready-to-send messages.',
            icon: Icons.insights_rounded,
            background: AppColors.accent,
            foreground: AppColors.onAccent,
            iconBackground: AppColors.onAccent,
            iconColor: AppColors.accent,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.iconBackground,
    required this.iconColor,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color iconBackground;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTextStyles.caption.copyWith(
              color: foreground.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin flowing turquoise curves — an abstract nod to progress lines.
class _FlowLinesPainter extends CustomPainter {
  const _FlowLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      final t = i / 4;
      paint.color = AppColors.accent.withValues(alpha: 0.10 + 0.12 * (1 - t));
      final path = Path();
      final startX = size.width * (0.55 + 0.12 * i);
      path.moveTo(startX, -10);
      for (var y = 0.0; y <= size.height * 0.62; y += 8) {
        final x =
            startX +
            math.sin((y / size.height) * math.pi * 2.2 + i * 0.6) *
                (30 + i * 10) +
            y * 0.08;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
