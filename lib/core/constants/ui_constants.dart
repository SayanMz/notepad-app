import 'tokens.dart';

/// Legacy layout bridge pointing to the central [Tokens] engine.
class UIConstants {
  UIConstants._();

  static const double paddingXXS = Tokens.spacingXXS;
  static const double paddingXS = Tokens.spacingXS;
  static const double paddingS = Tokens.spacingS;
  static const double paddingSM = Tokens.spacingSM;
  static const double paddingM = Tokens.spacingM;
  static const double paddingMD = Tokens.spacingMD;
  static const double paddingLG = Tokens.spacingLG;
  static const double paddingXLarge = Tokens.spacingXLarge;
  static const double paddingXL = Tokens.spacingXL;
  static const double paddingXXL = Tokens.spacingXXL;

  static const double radiusTiny = Tokens.radiusTiny;
  static const double radiusSM = Tokens.radiusSM;
  static const double radiusMD = Tokens.radiusMD;
  static const double radiusLG = Tokens.radiusLG;
  static const double radiusXLarge = Tokens.radiusXLarge;
  static const double radiusXL = Tokens.radiusHuge;

  static const double elevationLow = Tokens.shadowLow;
  static const double elevationMedium = Tokens.shadowMedium;
  static const double elevationHigh = Tokens.shadowHigh;

  static const double iconXS = Tokens.iconXS;
  static const double iconSmall = Tokens.iconSM;
  static const double iconSM = 20.0;
  static const double iconMD = Tokens.iconMD;
  static const double iconLG = Tokens.iconLG;
  static const double iconXL = Tokens.iconXL;

  static const double listPadding = Tokens.spacingMD;
  static const double cardVerticalMargin = Tokens.spacingSM;

  static const double themeInputRadius = Tokens.radiusHuge;
  static const double themeInputBorderWidth = 1.5;
  static const double themeCardBorderWidth = 1.5;
  static const double themeSelectionAlpha = 0.3;
  static const double themeShadowAlpha = 0.4;
  static const double themeFabElevation = Tokens.shadowLow;
  static const double themeFabHighlightElevation = Tokens.shadowMedium;

  static const double headerTitleFontSize = 22.0;

  static const double routeSlideInBeginX = 1.0;
  static const double routeSlideOutEndX = -0.2;
}
