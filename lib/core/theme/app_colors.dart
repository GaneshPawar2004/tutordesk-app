import 'package:flutter/material.dart';

/// Design tokens for the Bright Future / Tuition app.
abstract final class AppColors {
  // Surfaces
  static const background = Color(0xFF0B0D0C);
  static const surface = Color(0xFF151917);
  static const surfaceElevated = Color(0xFF1D2320);
  static const surfaceHighlight = Color(0xFF242B27);

  // Accent
  static const accent = Color(0xFF00D9A6);
  static const accentPressed = Color(0xFF00B98B);
  static const onAccent = Color(0xFF04140F);

  // Cream
  static const cream = Color(0xFFF3EFE4);
  static const creamBorder = Color(0xFFE2DCCB);
  static const creamTrack = Color(0xFFDDD6C3);

  // Text
  static const textPrimary = Color(0xFFF7F8F5);
  static const textSecondary = Color(0xFFA4ADA7);
  static const textTertiary = Color(0xFF6F7872);
  static const textOnCream = Color(0xFF171A18);
  static const textOnCreamMuted = Color(0xFF615F57);

  // Lines
  static const border = Color(0xFF303833);
  static const borderSubtle = Color(0xFF232926);

  // Semantic
  static const success = Color(0xFF39C98A);
  static const warning = Color(0xFFF4B84A);
  static const error = Color(0xFFF16F70);
  static const info = Color(0xFF76B7FF);

  /// Tinted background for a semantic colour, used by chips and icon wells.
  static Color tint(Color color, [double alpha = 0.14]) =>
      color.withValues(alpha: alpha);

  /// Muted avatar palette (kept small on purpose).
  static const avatarPalette = [
    Color(0xFF2A3B34),
    Color(0xFF33302A),
    Color(0xFF2B3340),
    Color(0xFF3A2C30),
    Color(0xFF2E3A2A),
    Color(0xFF353046),
  ];
}
