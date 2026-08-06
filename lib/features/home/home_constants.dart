import 'package:flutter/material.dart';
import 'package:notepad/core/constants/tokens.dart';
import 'package:notepad/core/theme/app_colors.dart';

/// Home feature layout, drawer, app bar, note card, and empty-state tokens.
class HomeConstants {
  HomeConstants._();

  // --- Drawer Navigation ---
  static const double drawerMarginTop = 90.0;
  static const double drawerMarginRight = Tokens.spacingLG;
  static const double drawerBorderRadius = Tokens.radiusXL;
  static const double drawerElevation = Tokens.shadowHuge;
  static const double drawerWidthFactor = 0.65;
  static const double drawerMaxHeightFactor = 0.7;
  static const double drawerHeaderPaddingH = Tokens.spacingLG;
  static const double drawerHeaderPaddingT = Tokens.spacingLG;
  static const double drawerHeaderPaddingB = Tokens.spacingMD;
  static const double drawerIconSize = Tokens.iconLG;
  static const double drawerHeaderTitleFontSize = 18.0;
  static const double drawerHeaderStatusFontSize = 12.0;
  static const double drawerHeaderTightGap = Tokens.spacingXS;
  static const double drawerHeaderSectionGap = Tokens.spacingM;
  static const double drawerHeaderBlockGap = 14.0;
  static const double drawerSectionGap = Tokens.spacingSM;
  static const double drawerActionsPaddingH = Tokens.spacingMD;
  static const double drawerActionRadius = Tokens.radiusLG;

  // --- Home AppBar ---
  static const Color appBarSurfaceTint = AppColors.appBarSurfaceTintLight;
  static const double appBarOverscrollThreshold = 15.0;
  static const double appBarScrolledUnderElevation = 1.5;
  static const double appBarTitleFontSize = 30.0;
  static const double appBarExpandedTitleFontSize = 48.0;
  static const double appBarExpandedBottomPadding = 56.0;
  static const double appBarCompactIconSpacing = Tokens.spacingSM;

  // --- Main FAB (Floating Action Button) ---
  static const double fabExpandedWidth = 145.0;
  static const double fabCollapsedWidth = 60.0;
  static const double fabHeight = 60.0;
  static const double fabAlignExpandedX = 0.0;
  static const double fabAlignCollapsedX = 0.95;
  static const double fabAlignSelectionY = 1.5;
  static const double fabAlignDefaultY = 0.95;
  static const double fabHorizontalPadding = Tokens.spacingXL;
  static const double fabClosedRadius = 18.0;
  static const double fabCollapsedIconSpacing = 18.0;
  static const double fabTextSpacing = Tokens.spacingMD;
  static const double fabTextFontSize = 15.0;

  // --- Selection Overlay ---
  static const double selectionOverlayPaddingL = Tokens.spacingLG;
  static const double selectionOverlayPaddingR = Tokens.spacingLG;
  static const double selectionOverlayPaddingB = Tokens.spacingXL;
  static const double selectionOverlayRadius = 100.0;
  static const double selectionOverlayBlurSigma = 12.0;
  static const double selectionOverlayShadowBlur = Tokens.spacingXL;
  static const double selectionOverlayShadowOffsetY = Tokens.spacingSM;
  static const double selectionOverlayBorderWidth = 0.8;
  static const double selectionOverlayBorderAlpha = 0.5;
  static const double selectionOverlayDarkAlpha = 0.25;
  static const double selectionOverlayLightAlpha = 0.35;
  static const double selectionOverlayShadowAlpha = 0.15;

  // --- Storage & Sync ---
  static const double storageProgressHeight = Tokens.spacingXXL;
  static const double storageProgressMinIndicator = 0.04;
  static const double storageProgressBorderWidth = 3.0;
  static const double storageProgressNearCompleteThreshold = 0.9;
  static const double storageProgressInnerPadding = Tokens.spacingXS;
  static const double storageProgressInnerInset = Tokens.spacingSM;

  // --- Thresholds & Cache ---
  static const double homeScrollCacheExtent = 400.0;
  static const double homeBulkDeleteThreshold = 25.0;
  static const double homeTopSnapThreshold = 10.0;

  // --- Note List & Layout Breakpoints ---
  static const double noteListLargeDesktopBreakpoint = 1200.0;
  static const double noteListTabletBreakpoint = 900.0;
  static const double noteListCompactBreakpoint = 600.0;
  static const double noteListSectionHeaderFontSize = 12.0;
  static const double noteListSectionHeaderLetterSpacing = 1.2;

  // --- Note Card Previews ---
  static const double noteCardPreviewHeight = 250.0;
  static const double noteCardPreviewTitleFontSize = 20.0;
  static const double noteCardTitleFontSize = 16.0;
  static const double noteCardEditedFontSize = 12.0;
  static const double noteCardPreviewFontSize = 13.0;
  static const double noteCardChecklistFontSize = 12.0;
  static const double selectionBorderWidth = 2.0;
  static const int noteCardPreviewFetchLimit = 12;
  static const int noteCardPreviewPhoneLines = 2;
  static const int noteCardPreviewSmallTabletLines = 5;
  static const int noteCardPreviewTabletLines = 8;
  static const int noteCardPreviewLargeDesktopLines = 12;
  static const int noteCardPreviewMidWidthLines = 2;
  static const int noteCardPreviewCompactWidthLines = 1;
  static const double noteCardPreviewWideLineHeight = 1.3;
  static const double noteCardPreviewRegularLineHeight = 1.5;

  // --- Empty States ---
  static const double noteEmptyStateBodyFontSize = 14.0;
  static const double noteEmptyStateBodyLineHeight = 1.4;
  static const double noteEmptyStateTitleLetterSpacing = -0.5;
}
