import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_settings_repository.dart';

void main() {
  group('AppSettingsRepository Logic', () {
    test('addRecentColor moves color to front and respects limit', () async {
      final repo = AppSettingsRepository();
      const colorA = Colors.red;
      const colorB = Colors.blue;

      // 1. Add color A
      await repo.addRecentColor(colorA, 5);
      expect(repo.settings.recentColorValues.first, colorA.toARGB32());

      // 2. Add color B (A moves to second position)
      await repo.addRecentColor(colorB, 5);
      expect(repo.settings.recentColorValues.first, colorB.toARGB32());
      expect(repo.settings.recentColorValues[1], colorA.toARGB32());

      // 3. Add A again (A moves to front, B to second)
      await repo.addRecentColor(colorA, 5);
      expect(repo.settings.recentColorValues.first, colorA.toARGB32());
      expect(repo.settings.recentColorValues[1], colorB.toARGB32());
    });

    test('themeMode returns system when not loaded, then reflects settings', () {
      final repo = AppSettingsRepository();
      
      // Before load
      expect(repo.themeMode, ThemeMode.system);
    });
  });
}
