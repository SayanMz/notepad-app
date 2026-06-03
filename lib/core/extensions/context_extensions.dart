// Shared BuildContext helpers keep widget code readable.
import 'package:flutter/material.dart';

// Shared `BuildContext` helpers used throughout the UI layer.
extension ContextExtensions on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  bool get isLight => !isDark;

  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  TextTheme get textTheme => Theme.of(this).textTheme;

  MediaQueryData get mediaQuery => MediaQuery.of(this);

  Size get screenSize => mediaQuery.size;

  double get viewInsetsBottom => mediaQuery.viewInsets.bottom;

  double get topPadding => mediaQuery.padding.top;
}

