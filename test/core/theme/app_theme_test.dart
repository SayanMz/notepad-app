import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/theme/app_theme.dart';
import 'package:notepad/core/theme/app_colors.dart';

void main() {
  group('AppTheme', () {
    test('light theme has light brightness and correct primary color', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.teal);
    });

    test('dark theme has dark brightness and correct primary color', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppColors.amber);
    });
  });

  group('AppColors Semantic Mappings', () {
    test('surface mappings are correct', () {
      expect(AppColors.surfacePrimaryLight, AppColors.lightScaffold);
      expect(AppColors.surfacePrimaryDark, AppColors.darkScaffold);
    });

    test('action mappings are correct', () {
      expect(AppColors.actionPrimaryLight, AppColors.teal);
      expect(AppColors.actionPrimaryDark, AppColors.amber);
    });
  });
}
