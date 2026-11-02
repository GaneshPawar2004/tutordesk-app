import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF3F51B5);
  static const primaryDark = Color(0xFF1A237E);
  static const primaryMid = Color(0xFF3949AB);
  static const accent = Color(0xFFE91E63);
  static const background = Color(0xFFF4F4F4);
  static const fieldFill = Color(0xFFF4F4F4);
  static const fieldBorder = Color(0xFFE0E0E0);
  static const textDark = Color(0xFF1C1B2E);
  static const textMuted = Color(0xFF757575);
  static const hint = Color(0xFFADADAD);

  static const success = Color(0xFF43A047);
  static const successDark = Color(0xFF1B5E20);
  static const danger = Color(0xFFE53935);
  static const warning = Color(0xFFF9A825);

  static const tileBlue = [Color(0xFF1565C0), Color(0xFF1976D2)];
  static const tileGreen = [Color(0xFF2E7D32), Color(0xFF388E3C)];
  static const tileOrange = [Color(0xFFE65100), Color(0xFFF57C00)];
  static const tileRed = [Color(0xFFB71C1C), Color(0xFFD32F2F)];

  static const buttonGradient = LinearGradient(
    colors: [primaryMid, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF2F80ED), Color(0xFF3949AB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        toolbarHeight: 58,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      datePickerTheme: const DatePickerThemeData(
        headerBackgroundColor: Color(0xFF4F5D96),
        headerForegroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.textMuted,
          );
        }),
      ),
    );
  }
}
