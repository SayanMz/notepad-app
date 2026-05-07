import 'package:flutter/material.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/services/storage_service.dart';

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
/// UI → Repository → StorageService → Hive
///
/// Key Decisions:
/// - Uses ChangeNotifier for reactive UI updates
/// - Keeps AppSettings immutable for safe state transitions
/// - Delegates storage logic to StorageService
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
    // 1. Get current list from the immutable settings object
    List<int> updatedValues = List.from(_settings.recentColorValues);

    // 2. Apply your FIFO logic
    updatedValues.remove(color.value); // Remove if exists to prevent duplicates
    updatedValues.insert(0, color.value); // Add to front

    if (updatedValues.length > maxColors) {
      updatedValues.removeLast(); // Clamp the list
    }

    // 3. Update the whole settings object and persist
    await update(_settings.copyWith(recentColorValues: updatedValues));
  }

  /// Loads saved settings when the app starts.
  Future<void> load() async {
    try {
      _settings = StorageService.loadSettings();
    } catch (e) {
      // If the data is corrupted or old, reset to defaults automatically
      debugPrint('Settings load failed, resetting to defaults: $e');
      _settings = const AppSettings();
      await persist();
    }
  }

  /// Writes the current settings snapshot to local storage.
  Future<void> persist() => StorageService.saveSettings(_settings);

  /// Replaces the current settings and notifies listeners.
  Future<void> update(AppSettings newSettings) async {
    _settings = newSettings;
    await persist();
    notifyListeners();
  }
}

/// Shared instance used by the app root and settings UI.
final AppSettingsRepository appSettingsRepository = AppSettingsRepository();
