import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/theme/dark_theme.dart';
import 'package:notepad/core/theme/light_theme.dart';

void main() {
  group('DarkTheme & LightTheme', () {
    test('DarkTheme creates dark brightness ThemeData with Material 3 enabled', () {
      final theme = DarkTheme.theme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('LightTheme creates light brightness ThemeData with Material 3 enabled', () {
      final theme = LightTheme.theme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, isNotNull);
      expect(theme.colorScheme.brightness, Brightness.light);
    });
  });
}
