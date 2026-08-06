import 'package:flutter/material.dart';
import 'package:notepad/core/constants/tokens.dart';

/// Note editor, toolbar, voice, and save-state semantic tokens.
class NoteConstants {
  NoteConstants._();

  // --- Editor Toolbar ---
  static const double toolbarHeight = 56.0;
  static const double toolbarNudgeDistance = 100.0;
  static const double toolbarItemWidthDivisor = 4.5;
  static const double toolbarMarginH = Tokens.spacingLG;
  static const double toolbarMarginTop = Tokens.spacingSM;
  static const double toolbarMarginBottom = 0.0;
  static const double toolbarBorderRadius = Tokens.radiusMD;
  static const double toolbarAlphaDark = 0.08;
  static const double toolbarAlphaLight = 0.7;
  static const double toolbarBorderAlpha = 0.2;
  static const double toolbarShadowAlpha = 0.05;
  static const double toolbarShadowBlur = 10.0;
  static const double toolbarShadowOffsetY = Tokens.spacingXS;
  static const double toolbarBlurSigma = 10.0;
  static const double toolbarGradientStopStart = 0.05;
  static const double toolbarGradientStopEnd = 0.95;
  static const double toolbarGradientStopEdge = 0.0;
  static const double toolbarGradientStopOppositeEdge = 1.0;

  // --- Editor Title Section ---
  static const double titlePaddingLeft = Tokens.spacingMD;
  static const double titlePaddingRight = Tokens.spacingSM;
  static const double titlePaddingBottom = Tokens.spacingMD;
  static const double titleFontSize = 32.0;
  static const double titleLineHeight = 1.5;
  static const double titleLetterSpacing = -0.5;
  static const double titleIconPaddingRight = Tokens.spacingSM;
  static const double titleIconSize = Tokens.iconMD;

  // --- Editor Main Surface ---
  static const double editorFontSize = 18.0;
  static const double editorLineHeight = 1.6;
  static const Color editorTextColor = Color(0xFF515151);
  static const Color editorTextColorDark = Color(0xFF94A3B8);
  static const double editorHorizontalPadding = Tokens.spacingMD;

  // --- Feature Gradients (Magic Wand / UI Effects) ---
  static const List<Color> titleGradientActiveDark = [Color(0xFF9D4EDD), Color(0xFF00F5D4)];
  static const List<Color> titleGradientActiveLight = [Color(0xFF6200EE), Color(0xFF03DAC6)];
  static const List<Color> titleGradientInactiveDark = [Colors.white, Colors.white70];
  static const List<Color> titleGradientInactiveLight = [Color(0xFF0F172A), Color(0xFF64748B)];

  // --- AppBar Logic ---
  static const Color appBarBackgroundDark = Color(0xFF1A1A1A);
  static const Color appBarBackgroundLight = Color(0xFFF8FAFC);
  static const double appBarRightPadding = Tokens.spacingSM;
  static const double appBarMenuOffsetY = Tokens.spacingSM;
  static const double progressBarHeight = 2.0;
  static const double progressBarBackgroundAlpha = 0.6;

  // --- Interaction Delays & Spacers ---
  static const Duration notePageKeyboardDismissDelay = Duration(milliseconds: 200);
  static const Duration notePageToolbarSizeDelay = Duration(milliseconds: 250);
  static const Duration notePageFabScaleDuration = Duration(milliseconds: 250);
  static const Duration notePageFabFadeDuration = Duration(milliseconds: 200);
  static const double notePageReadonlySpacerHeight = 0.0;
  static const double notePageToolbarPaddingBottom = 8.0;

  // --- Save Indicator ---
  static const double saveIndicatorSpinnerSize = Tokens.iconXS;
  static const double saveIndicatorIconSize = 16.0;
  static const double saveIndicatorTextFontSize = 12.0;
  static const double saveIndicatorSpacingTiny = Tokens.spacingXS;
  static const double saveIndicatorSpacingSmall = Tokens.spacingS;

  // --- Voice AI (Groq & STT) ---
  static const double aiButtonOpacityDim = 0.15;
  static const double aiButtonOpacityFull = 1.0;
  static const Duration aiSpeechSilenceTimeout = Duration(seconds: 5);
  static const Duration aiSpeechResultDelay = Duration(seconds: 1);
  static const Duration aiProcessingDelay = Duration(milliseconds: 50);

  static const double voiceButtonHiddenThreshold = 0.2;
  static const double voiceButtonPressedScale = 0.92;
  static const double voiceButtonListeningSize = 80.0;
  static const double voiceButtonIdleSize = 72.0;
  static const double voiceButtonListeningShadowBlur = 30.0;
  static const double voiceButtonListeningShadowSpread = Tokens.spacingSM;
  static const double voiceButtonPressedShadowBlur = Tokens.spacingM;
  static const double voiceButtonPressedShadowSpread = Tokens.spacingXXS;
}
