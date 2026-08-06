import 'package:notepad/core/constants/tokens.dart';

/// Trash/recycle sheet, empty-state, swipe, and header tokens.
class RecycleConstants {
  RecycleConstants._();

  // --- Layout & List ---
  static const double sheetRadius = Tokens.radiusXLarge;
  static const double listPadding = Tokens.spacingMD;
  static const double cardMargin = Tokens.spacingXS;
  static const double cardRadius = Tokens.radiusMD;
  static const double cardPadding = Tokens.spacingLG;
  static const double iconSize = Tokens.iconLG;
  static const double sheetHandleTopGap = Tokens.spacingMD;
  static const double sheetHandleBottomGap = Tokens.spacingSM;
  static const double sheetHandleWidth = 36.0;
  static const double sheetHandleHeight = 4.5;
  static const double sheetHandleRadius = Tokens.spacingM;
  static const double sheetHandleDarkAlpha = 0.2;
  static const double sheetHandleLightAlpha = 0.15;

  // --- Empty Bin View ---
  static const double emptyRippleOuterSize = 160.0;
  static const double emptyRippleOuterPressedSize = 200.0;
  static const double emptyRippleMiddleSize = Tokens.radiusMD * 10;
  static const double emptyRippleMiddlePressedSize = 145.0;
  static const double emptyRippleInnerSize = Tokens.spacingSM * 10;
  static const double emptyRippleInnerPressedSize = 95.0;
  static const double emptyStateIconSize = 34.0;
  static const double emptyStateIconDarkAlpha = 0.65;
  static const double emptyStateIconLightAlpha = 0.5;
  static const double emptyStateTextTopGap = Tokens.spacingXXL;
  static const double emptyStateTextPaddingH = 40.0;
  static const double emptyStateBodyFontSize = 14.5;
  static const double emptyStateBodyLetterSpacing = -0.1;
  static const double emptyStateBodyDarkAlpha = 0.45;
  static const double emptyStateBodyLightAlpha = 0.4;

  // --- Swipe-to-Restore Actions ---
  static const double swipeBackgroundInset = 0.5;
  static const double swipeBackgroundLeft = Tokens.spacingLG;
  static const double swipeAppearanceThreshold = 30.0;
  static const double swipeRevealFraction = 0.3;
  static const double swipeMinimumProgressDelta = 0.01;
  static const double swipeConfirmedScale = 0.0;
  static const double swipeIconStartScale = 0.5;

  // --- Recycle Header ---
  static const double headerSlideDistance = 50.0;
  static const double headerLeadingPadding = 56.0;
  static const double headerTitleFontSize = Tokens.spacingXL;
  static const double headerActionRightPadding = Tokens.spacingSM;
  static const double headerActionIconSize = 26.0;
}
