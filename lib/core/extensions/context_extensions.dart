import 'package:flutter/material.dart';

// Shared `BuildContext` helpers used throughout the UI layer.
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ColorScheme get colorScheme => theme.colorScheme;
  TextTheme get textTheme => theme.textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  Size get screenSize => mediaQuery.size;
  double get viewInsetsBottom => mediaQuery.viewInsets.bottom;
  double get topPadding => mediaQuery.padding.top;
}
