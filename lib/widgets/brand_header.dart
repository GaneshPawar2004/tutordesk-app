import 'package:flutter/material.dart';

/// Kaksha wordmark (icon + name + tagline) shown on the auth screens.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/kaksha_wordmark.png',
      width: compact ? 200 : 240,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Kaksha – Crafted by a teacher, for teachers.',
    );
  }
}
