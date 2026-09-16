import 'package:flutter/material.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// 앱 전체 Material Theme를 구성하는 유일한 진입점이다.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary600,
          brightness: Brightness.light,
          surface: AppColors.surface,
          error: AppColors.danger,
        ).copyWith(
          primary: AppColors.primary600,
          onPrimary: AppColors.textInverse,
          primaryContainer: AppColors.primary100,
          onPrimaryContainer: AppColors.primary900,
          secondary: AppColors.accentWarm,
          onSecondary: AppColors.textInverse,
          secondaryContainer: AppColors.accentWarmBackground,
          onSecondaryContainer: AppColors.textPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.danger,
          onError: AppColors.textInverse,
          outline: AppColors.borderStrong,
          outlineVariant: AppColors.borderSubtle,
          scrim: AppColors.scrim,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamilyFallback: const [
        'Pretendard Variable',
        'Noto Sans KR',
        'Inter',
      ],
      textTheme:
          const TextTheme(
            displaySmall: AppTypography.display,
            headlineSmall: AppTypography.title1,
            titleLarge: AppTypography.title2,
            titleMedium: AppTypography.heading,
            bodyLarge: AppTypography.body1,
            bodyMedium: AppTypography.body2,
            labelLarge: AppTypography.label,
            bodySmall: AppTypography.caption,
          ).apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.borderDefault),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.focusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary100,
        elevation: 0,
        height: 72,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary100,
        selectedIconTheme: IconThemeData(color: AppColors.primary700),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.primary700,
          fontWeight: FontWeight.w600,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        barrierColor: AppColors.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.modal),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceRaised,
        modalBackgroundColor: AppColors.surfaceRaised,
        modalBarrierColor: AppColors.scrim,
        showDragHandle: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(color: AppColors.textInverse),
      ),
      focusColor: AppColors.primary100,
      hoverColor: AppColors.primary50,
    );
  }
}
