import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';

/// Defines the Light Theme configuration for the application.
///
/// Implements a clean, high-contrast Material 3 design using
/// custom semantic tokens defined in [AppColors].
class LightTheme {
  LightTheme._();

  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // --- Interactive States ---
    shadowColor: AppColors.actionSecondary.withValues(
      alpha: UIConstants.themeShadowAlpha,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.actionPrimaryLight,
      selectionColor: AppColors.actionPrimaryLight.withValues(
        alpha: UIConstants.themeSelectionAlpha,
      ),
      selectionHandleColor: AppColors.actionPrimaryLight,
    ),

    // --- Form Controls ---
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.themeInputRadius),
        borderSide: const BorderSide(
          color: AppColors.actionPrimaryLight,
          width: UIConstants.themeInputBorderWidth,
        ),
      ),
    ),

    // --- Global Surfaces ---
    scaffoldBackgroundColor: AppColors.surfacePrimaryLight,

    // --- Header & Navigation ---
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBarSurfaceLight,
      foregroundColor: AppColors.contentPrimaryLight,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),

    // --- Semantic Color Scheme ---
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.actionPrimaryLight,
      brightness: Brightness.light,
      primary: AppColors.actionPrimaryLight,
      secondary: AppColors.actionSecondary,
      surface: AppColors.surfacePrimaryLight,
      onSurface: AppColors.contentPrimaryLight,
      onSurfaceVariant: AppColors.contentSecondaryLight,
    ),

    // --- Container Styling ---
    cardTheme: CardThemeData(
      color: AppColors.cardSurfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusMD),
        side: const BorderSide(
          color: AppColors.borderSubtleLight,
          width: UIConstants.themeCardBorderWidth,
        ),
      ),
    ),

    // --- Action Buttons ---
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.actionSecondary,
      foregroundColor: AppColors.surfacePrimaryLight,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
    ),

    // --- System Notifications ---
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.snackbarSurfaceLight,
      contentTextStyle: const TextStyle(
        color: AppColors.snackbarContentLight,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AppColors.actionPrimaryLight,
      elevation: UIConstants.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),
  );
}
