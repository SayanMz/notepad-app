import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  /// Shortcut for checking dark mode
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Shortcut for checking light mode
  bool get isLight => !isDark;

  /// Shortcut for accessing the color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Bonus: Quick access to text styles
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Shortcut for the active media query
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Shortcut for the current screen size
  Size get screenSize => mediaQuery.size;

  /// Shortcut for the current bottom inset, useful for keyboards.
  double get viewInsetsBottom => mediaQuery.viewInsets.bottom;

  /// Shortcut for the current top padding, useful for safe areas.
  double get topPadding => mediaQuery.padding.top;
}
