import 'package:flutter/material.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/storage_service.dart';

// Manages global application configuration, persistence, and granular UI notification.
class AppSettingsRepository{
  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  final ValueNotifier<int> themeRevision = ValueNotifier<int>(0);

  bool _isLoaded = false;

  ThemeMode get themeMode {
    if (!_isLoaded) return ThemeMode.system;
    return _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }


  Future<void> load() async {
    try {
      _settings = StorageService.loadSettings();
    } catch (e) {
      debugPrint('Settings load failed, resetting to defaults: $e');
      _settings = const AppSettings();
      await persist();
    } finally {
      _isLoaded = true;
      themeRevision.value++;
    }
  }

  Future<void> update(AppSettings newSettings) async {
    if (newSettings == _settings) return;

    _settings = newSettings;
    await persist();
  }

  Future<void> persist() => StorageService.saveSettings(_settings);

  Future<void> setSeedVersion(int version) async {
    await update(_settings.copyWith(seedVersion: version));
  }

  Future<void> recordMaintenanceCompleted(DateTime latestDate) async {
    await update(_settings.copyWith(lastMaintenanceDate: latestDate));
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
}



final AppSettingsRepository appSettingsRepository = AppSettingsRepository();
