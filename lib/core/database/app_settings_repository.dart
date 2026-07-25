// Keeps local app settings in memory and mirrors them back to disk.
import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/storage_service.dart' as db;

// Keeps local app settings in memory and mirrors them back to disk.
class AppSettingsRepository extends ChangeNotifier {
  AppSettings _settings = const AppSettings();
  bool _isLoaded = false;

  AppSettings get settings => _settings;

  ThemeMode get themeMode {
    // Before disk read completes, fall back to the phone's system dark/light mode
    if (!_isLoaded) return ThemeMode.system;

    return _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> addRecentColor(Color color, int maxColors) async {
    final updatedValues = List<int>.from(_settings.recentColorValues);

    updatedValues.remove(color.toARGB32());
    updatedValues.insert(0, color.toARGB32());

    if (updatedValues.length > maxColors) {
      updatedValues.removeLast();
    }

    await update(_settings.copyWith(recentColorValues: updatedValues));
  }

  Future<void> load() async {
    try {
      _settings = db.loadSettings();
    } catch (e) {
      debugPrint('Settings load failed, resetting to defaults: $e');
      _settings = const AppSettings();
      await persist();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> persist() => db.saveSettings(_settings);

  Future<void> update(AppSettings newSettings) async {
    _settings = newSettings;
    await persist();
    notifyListeners();
  }

  Future<void> setSeedVersion(int version) async {
    await update(_settings.copyWith(seedVersion: version));
  }

  Future<void> recordMaintenanceCompleted() async {
    await update(_settings.copyWith(lastMaintenanceDate: DateTime.now()));
  }
}

final AppSettingsRepository appSettingsRepository = AppSettingsRepository();
