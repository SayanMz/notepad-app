import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/storage_service.dart' as db;

/// ---------------------------------------------------------------------------
/// APP SETTINGS REPOSITORY (INTERVIEW NOTE)
/// ---------------------------------------------------------------------------
///
/// Role:
/// Acts as the bridge between UI state and persistent storage for app settings.
///
/// Responsibilities:
/// - Maintains in-memory settings state
/// - Loads persisted settings on startup
/// - Persists updates to storage
/// - Notifies UI of changes (theme, preferences)
///
/// Why this design:
/// Separates persistence concerns from UI, ensuring:
/// - consistent state management
/// - reactive updates across the app
///
/// Architectural Placement:
/// UI → Repository → db → Hive
///
/// Key Decisions:
/// - Uses ChangeNotifier for reactive UI updates
/// - Keeps AppSettings immutable for safe state transitions
/// - Delegates storage logic to db
///
/// Trade-offs:
/// - Immediate persistence on every update (simpler, but not batched)
/// - Uses global instance (can be refactored into full DI later)
///
/// Consistency Consideration:
/// Ensures UI state and disk state remain synchronized,
/// reducing risk of stale or inconsistent configuration.
/// In-memory settings store that keeps UI state and disk state aligned.
class AppSettingsRepository extends ChangeNotifier {
  AppSettings _settings = const AppSettings();

  /// Exposes the current settings snapshot as read-only state.
  AppSettings get settings => _settings;

  /// Resolves the active app theme from persisted settings.
  ThemeMode get themeMode =>
      _settings.isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> addRecentColor(Color color, int maxColors) async {
    final updatedValues = List<int>.from(_settings.recentColorValues);

    updatedValues.remove(color.toARGB32());
    updatedValues.insert(0, color.toARGB32());

    if (updatedValues.length > maxColors) {
      updatedValues.removeLast();
    }

    await update(_settings.copyWith(recentColorValues: updatedValues));
  }

  /// Loads saved settings when the app starts.
  Future<void> load() async {
    try {
      _settings = db.loadSettings();
    } catch (e) {
      // If the data is corrupted or old, reset to defaults automatically
      debugPrint('Settings load failed, resetting to defaults: $e');
      _settings = const AppSettings();
      await persist();
      notifyListeners();
    }
  }

  /// Writes the current settings snapshot to local storage.
  Future<void> persist() => db.saveSettings(_settings);

  /// Replaces the current settings and notifies listeners.
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

/// Shared instance used by the app root and settings UI.
final AppSettingsRepository appSettingsRepository = AppSettingsRepository();
