import 'package:notepad/core/constants/tokens.dart';

/// Search feature, results, and empty-state layout tokens.
class SearchConstants {
  SearchConstants._();

  // --- Search Bar & Panels ---
  static const double appBarActionPadding = Tokens.spacingSM;
  static const double appBarTitleRightPadding = Tokens.spacingMD;
  static const double searchFieldRadius = Tokens.radiusHuge;
  static const double searchFieldBorderWidth = 1.5;
  static const double panelPadding = Tokens.spacingM;
  static const double filterButtonSize = Tokens.iconMD;
  static const double filterDialogMaxWidth = 600.0;
  static const double dialogBarrierAlpha = 0.5;
  static const double metadataPaddingH = Tokens.spacingMD;
  static const double metadataPaddingV = Tokens.spacingXS;

  // --- Quick Filter Chips ---
  static const double chipBoltGap = 22.5;
  static const double chipGap = Tokens.spacingSM;
  static const double chipLeftPadding = 5.0;
  static const double chipBottomPadding = Tokens.spacingM;
  static const double chipIconSize = Tokens.iconSM;
  static const double resultsRightPadding = 15.0;
  static const double resultsBottomPadding = Tokens.spacingXLarge;
  static const double selectedChipAlpha = 0.8;

  // --- Filter Sheet & Range ---
  static const int filterDayOptionCount = 31;
  static const int filterYearOptionCount = 10;
  static const int filterHourOptionCount = 24;
  static const int filterMinuteOptionCount = 60;
  static const int filterYearDisplayPadding = 4;
  static const int filterDateTimeDisplayPadding = 2;

  static const double filterSheetRadius = Tokens.radiusXLarge;
  static const double filterSheetPaddingH = Tokens.radiusXLarge;
  static const double filterSheetPaddingTop = Tokens.spacingMD;
  static const double filterSheetPaddingBottom = Tokens.spacingXL;
  static const double filterSectionGap = Tokens.spacingSM;
  static const double filterGroupGap = Tokens.spacingXL;
  static const double filterFooterGap = Tokens.spacingXL;
  static const double filterDividerHeight = 40.0;
  static const double filterButtonHeight = Tokens.iconXL;
  static const double filterButtonRadius = Tokens.radiusSM;
  static const double filterButtonGap = Tokens.spacingMD;
  static const double filterTogglePaddingH = Tokens.spacingM;
  static const double filterLabelFontSize = 12.0;
  static const double filterDropdownFontSize = 14.0;
  static const double filterDropdownPaddingH = Tokens.spacingSM;
  static const double filterDropdownPaddingV = Tokens.spacingXXS;
  static const double filterDropdownMaxHeight = 300.0;
  static const double filterDragDismissDistance = Tokens.spacingM;
  static const double filterSheetHandleWidth = 40.0;
  static const double filterSheetHandleHeight = Tokens.spacingXS;
  static const double filterSheetHandleTopMargin = Tokens.spacingM;
  static const double filterSheetHandleBottomMargin = Tokens.spacingXL;
  static const double filterSheetHandleRadius = Tokens.spacingXXS;

  // --- Search Results Card & Empty States ---
  static const double emptyHorizontalPadding = Tokens.spacingXXL;
  static const double emptyIconSize = Tokens.iconXL;
  static const double emptyTitleFontSize = 18.0;
  static const double emptyTitleGap = Tokens.spacingMD;
  static const double emptySubtitleGap = Tokens.spacingS;
  static const double resultTitleFontSize = Tokens.spacingLG;
  static const double resultEditedFontSize = Tokens.spacingMD;
  static const double resultMarginBottom = Tokens.spacingMD;
  static const double resultContentPaddingH = Tokens.spacingLG;
  static const double resultContentPaddingV = Tokens.spacingM;
  static const double resultSubtitleTopPadding = Tokens.spacingS;
  static const double resultSubtitleBottomPadding = Tokens.spacingXXS;

  // --- Scroll Behavior ---
  static const double scrollHideDeltaThreshold = 15.0;
  static const double scrollBottomBoundary = 40.0;
  static const double scrollLayoutShiftSafeZone = 150.0;
}
