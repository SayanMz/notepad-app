import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';

/// ---------------------------------------------------------------------------
/// DARK THEME DEFINITION
/// ---------------------------------------------------------------------------
///
/// DESIGN GOALS:
/// - AMOLED-friendly deep blacks
/// - High contrast with amber accents
/// - Layered surfaces for depth perception

class DarkTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    /// Text selection styling
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.amber,
      selectionColor: AppColors.teal.withValues(
        alpha: UIConstants.themeSelectionAlpha,
      ),
      selectionHandleColor: AppColors.teal,
    ),

    /// Input fields
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.themeInputRadius),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: UIConstants.themeInputBorderWidth,
        ),
      ),
    ),

    /// Shadows
    shadowColor: Colors.black.withValues(alpha: UIConstants.themeShadowAlpha),

    /// Background
    scaffoldBackgroundColor: AppColors.darkScaffold,

    /// AppBar behavior fix (prevents grey overlay on scroll)
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),

    /// Floating Action Button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: AppColors.darkScaffold,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),

    /// SnackBars
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkElevated,
      contentTextStyle: const TextStyle(
        color: AppColors.darkText,
        fontWeight: FontWeight.w500,
      ),
      actionTextColor: AppColors.amber,
      elevation: UIConstants.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),

    /// Explicit color scheme for performance + clarity
    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      secondary: AppColors.amberSecondary,

      /// Surface layering
      surface: AppColors.darkSurface,
      surfaceContainerLowest: AppColors.darkScaffold,
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHighest: AppColors.darkElevated,

      /// Text colors
      onSurface: AppColors.darkText,
      onSurfaceVariant: Colors.grey,
    ),
  );
}
