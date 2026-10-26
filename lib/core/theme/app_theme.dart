import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const pill = 999.0;
}

/// 8-point spacing scale.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const page = 20.0;
}

abstract final class AppTheme {
  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: Color(0xFF0E3B30),
      onPrimaryContainer: AppColors.accent,
      secondary: AppColors.cream,
      onSecondary: AppColors.textOnCream,
      tertiary: AppColors.info,
      onTertiary: AppColors.background,
      error: AppColors.error,
      onError: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceElevated,
      surfaceContainerHighest: AppColors.surfaceHighlight,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSubtle,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme
        .copyWith(
          displaySmall: AppTextStyles.display,
          headlineMedium: AppTextStyles.headline,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.titleSmall,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.body.copyWith(fontSize: 14),
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button,
        )
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTextStyles.title,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: AppTextStyles.bodyMuted.copyWith(
          color: AppColors.textTertiary,
        ),
        labelStyle: AppTextStyles.bodyMuted,
        floatingLabelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.accent,
        ),
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.accent, 1.5),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 1.5),
        disabledBorder: inputBorder(AppColors.borderSubtle),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22),
          ),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.surfaceHighlight;
            }
            if (states.contains(WidgetState.pressed)) {
              return AppColors.accentPressed;
            }
            return AppColors.accent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textTertiary;
            }
            return AppColors.onAccent;
          }),
          overlayColor: WidgetStatePropertyAll(
            AppColors.onAccent.withValues(alpha: 0.08),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(64, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 22),
          ),
          textStyle: const WidgetStatePropertyAll(AppTextStyles.button),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.textTertiary;
            }
            return AppColors.textPrimary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return const BorderSide(color: AppColors.borderSubtle);
            }
            return const BorderSide(color: AppColors.border, width: 1.2);
          }),
          overlayColor: WidgetStatePropertyAll(
            AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 44)),
          textStyle: WidgetStatePropertyAll(
            AppTextStyles.button.copyWith(fontSize: 14),
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.accent),
          shape: const WidgetStatePropertyAll(StadiumBorder()),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
          overlayColor: WidgetStatePropertyAll(
            AppColors.textPrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        disabledColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: AppTextStyles.caption.copyWith(
          color: AppColors.onAccent,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        checkmarkColor: AppColors.onAccent,
        showCheckmark: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: AppTextStyles.title,
        contentTextStyle: AppTextStyles.bodyMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.cream,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: AppColors.textOnCream,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: AppColors.textOnCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onAccent;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.surfaceHighlight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return AppColors.border;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.onAccent),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.onAccent,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
        ),
        unselectedLabelStyle: AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        indicator: const BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceHighlight,
        circularTrackColor: AppColors.surfaceHighlight,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(horizontal: Gap.page),
        minVerticalPadding: 12,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.accent.withValues(alpha: 0.3),
        selectionHandleColor: AppColors.accent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.surfaceElevated,
        headerForegroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppTextStyles.caption.copyWith(color: AppColors.textOnCream),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
