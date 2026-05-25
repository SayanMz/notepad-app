import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// CENTRALIZED COLOR SYSTEM
/// ---------------------------------------------------------------------------
///
/// PURPOSE:
/// - Avoid hardcoded color duplication across the app
/// - Ensure consistency in branding and theming
/// - Simplify future design updates
///
/// USAGE:
/// - Refer to these constants instead of raw Color(...) values

class AppColors {
  // Primary brand colors
  static const teal = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0D9488);

  // Light theme backgrounds
  // Separate tokens let the page body and AppBar be tuned independently.
  static const lightScaffold = Color(0xFFFAFAF7);
  // Soft teal tint for AppBars in light mode.
  static const lightAppBar = Color(0xFFE9F8F6);

  // Dark theme backgrounds (AMOLED optimized)
  static const darkScaffold = Color(0xFF09090B);
  static const darkSurface = Color(0xFF18181B);
  static const darkCard = Color(0xFF1C1C1E);
  static const darkElevated = Color(0xFF27272A);

  // Borders
  static const lightBorder = Color(0xFFE4E4E7);
  static const lightSnackBar = Color(0xFF2F3439);
  static const darkDialogSurface = Color(0xFF1E1E1E);
  static const searchFilterButtonLight = Color(0xFFF1F5F9);
  static const searchFilterTextLight = Color(0xFF475569);
  static const searchFilterSubmitLight = Color(0xFF334155);
  static const recycleSwipeDark = Color(0xFF003D33);
  static const recycleSwipeLight = Color(0xFFC8E6C9);
  static const recycleRestoreDark = Color(0xFF69F0AE);
  static const recycleRestoreLight = Color(0xFF2E7D32);
  static const colorPickerApply = Color(0xFF2C9C8D);
  static const noteAppBarDark = Color(0xFF1A1A1A);
  static const noteAppBarLight = Color(0xFFF8FAFC);
  static const homeFabDark = Color(0xFFFFCC80);
  static const homeFabLight = Color(0xFF4DB6AC);
  static const homeDrawerSurface = Color(0xFF1E1E1E);
  static const storageProgress = Color(0xFF64B5F6);
  static const noteEditorText = Color(0xFF515151);

  // Accent colors
  static const amber = Colors.amberAccent;
  static const amberSecondary = Color(0xFFFFD54F);
  static const hyperlink = Color(0xFF2196F3);
  static const hyperlinkHex = '#2196F3';

  // Text
  static const lightText = Colors.black;
  static const darkText = Color(0xFFF4F4F5);

  ///For Dismissible widget -
  ///Light and dark theme
  // Background
  static const deleteLightBg = Color(0xFFD15B5B); // Muted Crimson
  static const deleteDarkBg = Color(0xFF3F1D1D); // muted deep red
  // Icon / Accent

  static const deleteLightIcon = Colors.white; // strong red
  static const deleteDarkIcon = Color(0xFFFF6B6B); // bright contrast red
}
