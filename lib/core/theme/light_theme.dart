import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';

/// ---------------------------------------------------------------------------
/// LIGHT THEME DEFINITION
/// ---------------------------------------------------------------------------
///
/// DESIGN GOALS:
/// - Clean, minimal, soft UI
/// - Teal-based branding
/// - Subtle elevation and borders for structure

class LightTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    /// Global shadow styling
    shadowColor: AppColors.tealDark.withValues(
      alpha: UIConstants.themeShadowAlpha,
    ),

    /// Text selection (cursor + highlight)
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.teal,
      selectionColor: AppColors.teal.withValues(
        alpha: UIConstants.themeSelectionAlpha,
      ),
      selectionHandleColor: AppColors.teal,
    ),

    /// Input field styling
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.themeInputRadius),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: UIConstants.themeInputBorderWidth,
        ),
      ),
    ),

    /// Background
    scaffoldBackgroundColor: AppColors.lightScaffold,

    /// AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightAppBar,
      foregroundColor: Colors.black,
    ),

    /// Material 3 Color System
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      primary: AppColors.teal,
      surface: Colors.white,
    ),

    /// Cards
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusMD),
        side: const BorderSide(
          color: AppColors.lightBorder,
          width: UIConstants.themeCardBorderWidth,
        ),
      ),
    ),

    /// Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.tealDark,
      foregroundColor: Colors.white,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
    ),

    /// SnackBars
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.lightSnackBar,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AppColors.teal,
      elevation: UIConstants.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),
  );
}
