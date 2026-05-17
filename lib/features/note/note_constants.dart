import 'package:flutter/material.dart';

class NoteConstants {
  NoteConstants._();

  static const double toolbarNudgeDistance = 100.0;
  static const double toolbarItemWidthDivisor = 4.5;
  static const double toolbarHeight = 56.0;
  static const double toolbarMarginH = 16.0;
  static const double toolbarMarginTop = 8.0;
  static const double toolbarMarginBottom = 0.0;
  static const double toolbarBorderRadius = 12.0;
  static const double toolbarAlphaDark = 0.08;
  static const double toolbarAlphaLight = 0.7;
  static const double toolbarBorderAlpha = 0.2;
  static const double toolbarShadowAlpha = 0.05;
  static const double toolbarShadowBlur = 10.0;
  static const double toolbarShadowOffsetY = 4.0;
  static const double toolbarBlurSigma = 10.0;
  static const double toolbarGradientStopStart = 0.05;
  static const double toolbarGradientStopEnd = 0.95;
  static const double toolbarGradientStopEdge = 0.0;
  static const double toolbarGradientStopOppositeEdge = 1.0;

  static const double titlePaddingLeft = 12.0;
  static const double titlePaddingRight = 8.0;
  static const double titlePaddingBottom = 12.0;
  static const double titleFontSize = 32.0;
  static const double titleLineHeight = 1.5;
  static const double titleLetterSpacing = -0.5;
  static const double titleIconPaddingRight = 8.0;
  static const double titleIconSize = 24.0;

  static const double editorFontSize = 18.0;
  static const double editorLineHeight = 1.6;
  static const Color editorTextColor = Color(0xFF515151);
  static const double editorHorizontalPadding = 12.0;

  static const Color appBarBackgroundDark = Color(0xFF1A1A1A);
  static const Color appBarBackgroundLight = Color(0xFFF8FAFC);
  static const double appBarRightPadding = 8.0;
  static const double appBarMenuOffsetY = 8.0;

  static const double progressBarHeight = 2.0;
  static const double progressBarBackgroundAlpha = 0.6;

  static const Duration notePageKeyboardDismissDelay = Duration(milliseconds: 200);
  static const Duration notePageToolbarSizeDelay = Duration(milliseconds: 250);
  static const Duration notePageFabScaleDuration = Duration(milliseconds: 250);
  static const Duration notePageFabFadeDuration = Duration(milliseconds: 200);
  static const double notePageReadonlySpacerHeight = 0.0;
  static const double notePageToolbarPaddingBottom = 8.0;

  static const double aiButtonOpacityDim = 0.15;
  static const double aiButtonOpacityFull = 1.0;
  static const Duration aiSpeechSilenceTimeout = Duration(seconds: 5);
  static const Duration aiSpeechResultDelay = Duration(seconds: 1);
  static const Duration aiProcessingDelay = Duration(milliseconds: 50);
}
