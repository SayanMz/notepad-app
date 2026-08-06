import 'package:flutter/material.dart';

/// Centralizes the application's color palette and semantic tokens.
///
/// This class organizes colors by their role in the UI (Surfaces, Content, Actions)
/// to ensure consistency across Light and Dark themes.
class AppColors {
  AppColors._();

  // ===========================================================================
  // BASE PALETTE
  // Raw color values used to derive semantic tokens.
  // ===========================================================================

  static const teal = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0D9488);
  static const amber = Colors.amberAccent;
  static const amberSecondary = Color(0xFFFFD54F);

  static const lightScaffold = Color(0xFFFAFAF7);
  static const lightAppBar = Color(0xFFE9F8F6);
  static const lightBorder = Color(0xFFE4E4E7);
  static const lightSnackBar = Color(0xFF2F3439);

  static const darkScaffold = Color(0xFF09090B);
  static const darkSurface = Color(0xFF18181B);
  static const darkCard = Color(0xFF1C1C1E);
  static const darkElevated = Color(0xFF27272A);
  static const darkDialogSurface = Color(0xFF1E1E1E);

  static const lightText = Colors.black;
  static const darkText = Color(0xFFF4F4F5);

  static const deleteLightBg = Color(0xFFD15B5B);
  static const deleteDarkBg = Color(0xFF3F1D1D);
  static const deleteLightIcon = Colors.white;
  static const deleteDarkIcon = Color(0xFFFF6B6B);

  // ===========================================================================
  // SEMANTIC TOKENS: SURFACE ROLES
  // Backgrounds for different UI containers.
  // ===========================================================================

  static const surfacePrimaryLight = lightScaffold;
  static const surfaceSecondaryLight = lightAppBar;
  static const surfacePrimaryDark = darkScaffold;
  static const surfaceSecondaryDark = darkSurface;
  static const surfaceTertiaryDark = darkCard;
  static const surfaceElevatedDark = darkElevated;

  static const cardSurfaceLight = Colors.white;
  static const cardSurfaceDark = darkCard;
  static const elevatedSurfaceDark = darkElevated;

  // ===========================================================================
  // SEMANTIC TOKENS: CONTENT ROLES
  // Text and icon colors based on emphasis level.
  // ===========================================================================

  static const contentPrimaryLight = lightText;
  static const contentPrimaryDark = darkText;
  static const contentSecondaryLight = Color(0xFF475569);
  static const contentSecondaryDark = Colors.grey;

  // ===========================================================================
  // SEMANTIC TOKENS: BORDER & OVERLAY ROLES
  // Dividers, subtle outlines, and depth effects.
  // ===========================================================================

  static const borderSubtleLight = lightBorder;
  static const borderSubtleDark = Color(0xFF3F3F46);

  static const overlaySurfaceDark = Colors.black;
  static const overlaySurfaceLight = Colors.white;
  static const overlayBorder = Colors.white;
  static const overlayShadow = Colors.black;

  // ===========================================================================
  // SEMANTIC TOKENS: ACTION ROLES
  // Interactive elements like buttons and status indicators.
  // ===========================================================================

  static const actionPrimaryLight = teal;
  static const actionPrimaryDark = amber;
  static const actionSecondary = tealDark;
  static const actionSuccess = Color(0xFF2E7D32);
  static const actionWarning = Color(0xFFFFD54F);
  static const actionDangerLight = deleteLightBg;
  static const actionDangerDark = deleteDarkBg;

  // ===========================================================================
  // FEATURE ROLES: APP BAR & SNACKBAR
  // ===========================================================================

  static const appBarSurfaceLight = lightAppBar;
  static const appBarSurfaceDark = darkSurface;
  static const appBarSurfaceTintLight = Color(0xFFB8E6DD);
  static const appBarSurfaceTintDark = darkSurface;

  static const snackbarSurfaceLight = lightSnackBar;
  static const snackbarSurfaceDark = darkElevated;
  static const snackbarContentLight = Colors.white;
  static const snackbarContentDark = darkText;

  // ===========================================================================
  // FEATURE ROLES: SEARCH
  // ===========================================================================

  static const searchFilterSurfaceLight = searchFilterButtonLight;
  static const searchFilterTextLightSemantic = searchFilterTextLight;
  static const searchFilterSubmitLightSemantic = searchFilterSubmitLight;

  static const searchFilterButtonLight = Color(0xFFF1F5F9);
  static const searchFilterTextLight = Color(0xFF475569);
  static const searchFilterSubmitLight = Color(0xFF334155);

  static const searchResultTitleDark = Colors.white;
  static const searchResultTitleLight = Colors.black;
  static const searchResultSubtitleDark = Colors.grey;
  static const searchResultSubtitleLight = Color(0xFF475569);
  static const searchResultDividerDark = Color(0xFF27272A);
  static const searchResultDividerLight = Color(0xFFE2E8F0);
  static const searchResultHighlight = Color(0xFFFFF176);

  static const searchChipSurfaceDark = Color(0xFF27272A);
  static const searchChipSurfaceLight = Color(0xFFF1F5F9);
  static const searchMetadataTextLight = Color(0xFF64748B);

  // ===========================================================================
  // FEATURE ROLES: HOME & NAVIGATION
  // ===========================================================================

  static const homeFabDark = Color(0xFFFFCC80);
  static const homeFabLight = Color(0xFF4DB6AC);
  static const homeDrawerSurface = Color(0xFF1E1E1E);
  static const storageProgress = Color(0xFF64B5F6);
  static const storageCritical = Colors.redAccent;

  static const drawerHeaderTintDark = Colors.white;
  static const drawerHeaderTintLight = Colors.black;
  static const drawerHeaderSurfaceDark = Colors.white;
  static const drawerActionIconDark = Colors.white;
  static const drawerActionIconLight = Colors.black87;

  // ===========================================================================
  // FEATURE ROLES: TOOLBAR & PICKERS
  // (Shared UI components used in editors)
  // ===========================================================================

  static const toolbarShadow = Colors.black;
  static const toolbarInactiveIconDark = Colors.white;
  static const toolbarInactiveIconLight = Colors.black87;
  static const toolbarActiveIcon = Colors.blueAccent;
  static const toolbarActiveLink = Colors.blueAccent;
  static const toolbarAccentBlue = Colors.blue;
  static const toolbarAccentGreen = Colors.green;
  static const toolbarAccentGrey = Colors.grey;
  static const toolbarAccentWhite = Colors.white;
  static const toolbarAccentLightGreen = Colors.lightGreenAccent;
  static const toolbarAccentRed = Colors.red;
  static const toolbarAccentPink = Colors.pinkAccent;
  static const toolbarAccentAmber = Colors.amber;
  static const toolbarAccentPurple = Colors.purple;
  static const toolbarAccentOrange = Colors.orange;
  static const toolbarAccentIndigo = Colors.indigo;
  static const toolbarBorderWhite = Colors.white;
  static const toolbarBorderBlack = Colors.black87;

  static const pickerSurfaceLight = Colors.white;
  static const pickerBorderDark = Colors.white;
  static const pickerBorderLight = Colors.black;
  static const pickerTitleDark = Colors.white;
  static const pickerTitleLight = Colors.black;
  static const pickerRecentDark = Colors.white54;
  static const pickerRecentLight = Colors.black45;
  static const pickerSwatchBorderDark = Colors.white24;
  static const pickerSwatchBorderLight = Colors.black12;
  static const colorPickerApply = Color(0xFF2C9C8D);

  static const noteToolbarGradientDark = Colors.black;
  static const noteToolbarGradientLight = Colors.transparent;
  static const noteToolbarTextDark = Colors.white;
  static const noteToolbarTextLight = Colors.black87;

  static const hyperlink = Color(0xFF2196F3);
  static const hyperlinkHex = '#2196F3';

  // ===========================================================================
  // FEATURE ROLES: TRASH & RECYCLE BIN
  // ===========================================================================

  static const recycleSwipeSurfaceDark = recycleSwipeDark;
  static const recycleSwipeSurfaceLight = recycleSwipeLight;
  static const recycleRestoreSurfaceDark = recycleRestoreDark;
  static const recycleRestoreSurfaceLight = recycleRestoreLight;

  static const recycleSwipeDark = Color(0xFF003D33);
  static const recycleSwipeLight = Color(0xFFC8E6C9);
  static const recycleRestoreDark = Color(0xFF69F0AE);
  static const recycleRestoreLight = Color(0xFF2E7D32);

  static const recycleEmptyBodyDark = Colors.white;
  static const recycleEmptyBodyLight = Colors.black;
  static const recycleFabBgDark = Color(0xFF2C2C2C);
  static const recycleFabBgLight = Color(0xFFF3F3F3);
  static const recycleFabFgDark = Colors.white;
  static const recycleFabFgLight = Colors.black;
  static const recycleTextIconDark = Colors.white;
  static const recycleTextIconLight = Colors.grey;
  static const recycleDaysStripDark = Colors.white;
  static const recycleDaysStripLight = Colors.grey;

  // ===========================================================================
  // FEATURE ROLES: LINK POPUPS
  // ===========================================================================

  static const linkPopupSurfaceDark = Color(0xFF1E1E1E);
  static const linkPopupSurfaceLight = Colors.white;
  static const linkPopupShadow = Colors.black26;
  static const linkPopupPrimary = Colors.blue;
  static const linkPopupSecondary = Colors.grey;
  static const linkPopupSuccess = Colors.green;
}
