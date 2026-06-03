import 'package:flutter/material.dart';
import 'package:notepad/core/constants/ui_constants.dart';
import 'app_colors.dart';


class LightTheme {
  static final ThemeData theme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    shadowColor: AppColors.tealDark.withValues(
      alpha: UIConstants.themeShadowAlpha,
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.teal,
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

    scaffoldBackgroundColor: AppColors.lightScaffold,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightAppBar,
      foregroundColor: Colors.black,
    ),

    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: Brightness.light,
      primary: AppColors.teal,
      surface: Colors.white,
    ),

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

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.tealDark,
      foregroundColor: Colors.white,
      elevation: UIConstants.themeFabElevation,
      highlightElevation: UIConstants.themeFabHighlightElevation,
    ),

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
