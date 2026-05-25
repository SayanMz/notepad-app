/// Centralized UI constants to eliminate magic numbers and
/// enforce consistency across the app.
///
/// RULE:
/// - Values here should represent design decisions, not arbitrary numbers.
class UIConstants {
  UIConstants._(); // prevent instantiation

  // ======================
  // Animation Durations
  // ======================

  /// Fast animations (e.g., color changes, scale toggles, icon switches, checkboxes).
  static const Duration animationFast = Duration(milliseconds: 200);

  /// Medium animations (e.g., expanding toolbars, fade transitions, dialogs).
  static const Duration animationMedium = Duration(milliseconds: 300);

  /// Slow animations (e.g., primary page slide transitions).
  static const Duration animationSlow = Duration(milliseconds: 400);

  /// Extra slow animations (e.g., complex routing, FAB container morphing).
  static const Duration animationExtraSlow = Duration(milliseconds: 500);

  /// Standard delay before triggering debounced actions (e.g., auto-save, search typing).
  static const Duration debounceStandard = Duration(milliseconds: 300);

  /// How long the "Saved" indicator remains visible before hiding.
  static const Duration saveIndicatorDuration = Duration(seconds: 3);

  /// Standard duration for brief snackbar notifications.
  static const Duration snackbarShort = Duration(seconds: 2);

  /// Standard duration for longer error snackbar notifications.
  static const Duration snackbarLong = Duration(seconds: 4);

  /// Continuous ambient spin duration used by decorative color affordances.
  static const Duration colorWheelSpinDuration = Duration(seconds: 10);

  /// Voice request timeout for the remote formatting assistant.
  static const Duration voiceRequestTimeout = Duration(seconds: 20);

  // ======================
  // Spacing
  // ======================
  // Standardized padding and margin scale used throughout the app.

  static const double paddingXXS = 2.0;
  static const double paddingXS = 4.0;
  static const double paddingS = 6.0;
  static const double paddingSM = 8.0;
  static const double paddingM = 10.0;
  static const double paddingMD = 12.0;
  static const double paddingLG = 16.0;
  static const double paddingXLarge = 20.0;
  static const double paddingXL = 24.0;
  static const double paddingXXL = 32.0;

  // ======================
  // Border Radius
  // ======================

  /// Tiny radius for small internal elements (e.g., color picker circles).
  static const double radiusTiny = 4.0;

  /// Small radius for minor containers or tags.
  static const double radiusSM = 8.0;

  /// Medium radius for standard cards, toolbars, and list tiles.
  static const double radiusMD = 12.0;

  /// Large radius for elevated containers or prominent buttons.
  static const double radiusLG = 16.0;

  /// Extra large radius for bottom sheets or modal dialogs.
  static const double radiusXLarge = 20.0;

  /// Fully rounded pill shape for search bars or chips.
  static const double radiusXL = 30.0;

  // ======================
  // Elevation
  // ======================

  /// Subtle shadow for standard note cards.
  static const double elevationLow = 2.0;

  /// Noticeable shadow for selected states or toolbars.
  static const double elevationMedium = 4.0;

  /// High shadow for floating action buttons (FABs) or modals.
  static const double elevationHigh = 6.0;

  // ======================
  // Icon Sizes
  // ======================

  /// Extra small icons (e.g., tiny status indicators).
  static const double iconXS = 14.0;

  /// Small icons (e.g., list bullets or minor actions).
  static const double iconSmall = 16.0;

  /// Standard UI icons (e.g., pin, export, edit).
  static const double iconSM = 20.0;

  /// Medium standard icons (e.g., app bar actions).
  static const double iconMD = 24.0;

  /// Large icons (e.g., recycle bin swipe background).
  static const double iconLG = 28.0;

  /// Extra large icons (e.g., empty state placeholder graphics).
  static const double iconXL = 48.0;

  // ======================
  // Layout (Specific Component Values)
  // ======================

  /// Standard padding wrapping the main list views.
  static const double listPadding = 12.0;

  /// Vertical spacing between individual note cards.
  static const double cardVerticalMargin = 8.0;

  /// Height of the top linear progress indicator during saves/exports.
  static const double progressBarHeight = 2.0;

  // --- Theme Defaults ---
  static const double themeInputRadius = 30.0;
  static const double themeInputBorderWidth = 1.5;
  static const double themeCardBorderWidth = 1.5;
  static const double themeSelectionAlpha = 0.3;
  static const double themeShadowAlpha = 0.4;
  static const double themeFabElevation = 2.0;
  static const double themeFabHighlightElevation = 4.0;

  // --- Shared Widget Tokens ---
  // These are used across multiple features and represent app-wide design decisions.
  static const double toolbarBorderWidth = 1.0;
  static const double toolbarMenuWidth = 190.0;
  static const double toolbarColorCircleSize = 30.0;
  static const double toolbarColorCircleMargin = 6.0;
  static const double toolbarColorCircleBorderWidth = 2.0;

  static const double headerTitleFontSize = 22.0;

  static const double saveIndicatorSpinnerSize = 14.0;
  static const double saveIndicatorIconSize = 16.0;
  static const double saveIndicatorTextFontSize = 12.0;
  static const double saveIndicatorSpacingTiny = 4.0;
  static const double saveIndicatorSpacingSmall = 6.0;

  static const double noteCardPreviewHeight = 250.0;
  static const double noteCardPreviewTitleFontSize = 20.0;
  static const double noteCardTitleFontSize = 16.0;
  static const double noteCardEditedFontSize = 12.0;
  static const double noteCardPreviewFontSize = 13.0;
  static const int noteCardPreviewLargeDesktopLines = 12;
  static const int noteCardPreviewTabletLines = 8;
  static const int noteCardPreviewSmallTabletLines = 5;
  static const int noteCardPreviewPhoneLines = 2;
  static const double selectionBorderWidth = 2.0;

  static const double voiceButtonHiddenThreshold = 0.2;
  static const double voiceButtonPressedScale = 0.92;
  static const double voiceButtonListeningSize = 80.0;
  static const double voiceButtonIdleSize = 72.0;
  static const double voiceButtonListeningAssetSize = 70.0;
  static const double voiceButtonIdleAssetSize = 60.0;
  static const double voiceButtonListeningShadowBlur = 30.0;
  static const double voiceButtonListeningShadowSpread = 8.0;
  static const double voiceButtonPressedShadowBlur = 10.0;
  static const double voiceButtonPressedShadowSpread = 2.0;

  // --- App Router Transitions ---
  /// Starting X offset for the incoming page (Slide transition).
  static const double routeSlideInBeginX = 1.0;

  /// Ending X offset for the outgoing page (Slide transition background effect).
  static const double routeSlideOutEndX = -0.2;

  // --- Interactive States ---
  /// Scale multiplier when a note pin is toggled.
  static const double pinnedScale = 1.2;
}
