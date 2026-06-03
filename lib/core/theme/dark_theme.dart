import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';


class DarkTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.amber,
      selectionColor: AppColors.teal.withValues(
        alpha: UIConstants.themeSelectionAlpha,
      ),
      selectionHandleColor: AppColors.teal,
    ),

    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(UIConstants.themeInputRadius),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: UIConstants.themeInputBorderWidth,
        ),
      ),
    ),

    shadowColor: Colors.black.withValues(alpha: UIConstants.themeShadowAlpha),

    scaffoldBackgroundColor: AppColors.darkScaffold,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: AppColors.darkScaffold,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLG),
      ),
    ),

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

    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      secondary: AppColors.amberSecondary,

      surface: AppColors.darkSurface,
      surfaceContainerLowest: AppColors.darkScaffold,
      surfaceContainer: AppColors.darkCard,
      surfaceContainerHighest: AppColors.darkElevated,

      onSurface: AppColors.darkText,
      onSurfaceVariant: Colors.grey,
    ),
  );
}
