import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale. Uses the platform sans-serif (Roboto on Android).
abstract final class AppTextStyles {
  static const tabular = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 34,
    height: 1.08,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    color: AppColors.textPrimary,
  );

  static const headline = TextStyle(
    fontSize: 26,
    height: 1.15,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.7,
    color: AppColors.textPrimary,
  );

  static const title = TextStyle(
    fontSize: 19,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
  );

  static const titleSmall = TextStyle(
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const bodyMuted = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Small uppercase tracking label, e.g. "TODAY'S ACTIVITY".
  static const label = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: AppColors.textSecondary,
  );

  static const button = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
  );

  static const metric = TextStyle(
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const amount = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );
}
