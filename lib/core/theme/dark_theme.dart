import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';

/// Defines the Dark Theme configuration for the application.
///
/// Leverages Material 3 design principles with custom color mappings
/// from [AppColors] for consistent brand identity in dark mode.
class DarkTheme {
  DarkTheme._();

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // --- Interactive States ---
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.actionPrimaryDark,
      selectionColor: AppColors.actionSecondary.withValues(
        alpha: UIConstants.themeSelectionAlpha,
      ),
      selectionHandleColor: AppColors.actionSecondary,
    ),

    // --- Form Controls ---
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.themeInputRadius),
        borderSide: const BorderSide(
          color: AppColors.actionSecondary,
          width: UIConstants.themeInputBorderWidth,
        ),
      ),
    ),

    // --- Depth & Shadows ---
    shadowColor: Colors.black.withValues(alpha: UIConstants.themeShadowAlpha),

    // --- Global Surfaces ---
    scaffoldBackgroundColor: AppColors.surfacePrimaryDark,

    // --- Header & Navigation ---
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBarSurfaceDark,
      foregroundColor: AppColors.contentPrimaryDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
    ),

    // --- Action Buttons ---
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.actionPrimaryDark,
      foregroundColor: AppColors.surfacePrimaryDark,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),

    // --- System Notifications ---
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.snackbarSurfaceDark,
      contentTextStyle: const TextStyle(
        color: AppColors.snackbarContentDark,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AppColors.actionPrimaryDark,
      elevation: UIConstants.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),

    // --- Semantic Color Scheme ---
    colorScheme: const ColorScheme.dark(
      primary: AppColors.actionPrimaryDark,
      secondary: AppColors.actionWarning,

      surface: AppColors.surfaceSecondaryDark,
      surfaceContainerLowest: AppColors.surfacePrimaryDark,
      surfaceContainer: AppColors.surfaceTertiaryDark,
      surfaceContainerHighest: AppColors.surfaceElevatedDark,

      onSurface: AppColors.contentPrimaryDark,
      onSurfaceVariant: Colors.grey,
    ),
  );
}
