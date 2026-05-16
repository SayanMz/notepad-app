import 'package:flutter/material.dart';

extension ContextExtensions on BuildContext {
  /// Shortcut for checking dark mode
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Shortcut for accessing the color scheme
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Bonus: Quick access to text styles
  TextTheme get textTheme => Theme.of(this).textTheme;
}
