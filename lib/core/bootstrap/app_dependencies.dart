import 'package:notepad/core/bootstrap/app_bootstrapper.dart' as bootstrap;
import 'package:notepad/core/data/app_settings_repository.dart' as settings_lib;
import 'package:notepad/core/services/ui_notifier.dart' as ui_lib;
import 'package:notepad/features/note/data/note_repository.dart' as note_lib;

/// ---------------------------------------------------------------------------
/// APP DEPENDENCIES (INTERVIEW NOTE)
/// ---------------------------------------------------------------------------
///
/// Role:
/// Acts as the composition root of the application.
///
/// Responsibilities:
/// - Centralizes dependency wiring (repositories, services, notifiers)
/// - Provides environment-based configuration
/// - Supplies dependencies to the root UI layer
///
/// Why this design:
/// Avoids scattered global singletons and enables controlled dependency
/// injection, improving modularity and testability.
///
/// Architectural Placement:
/// Composition Root → Injected into App → Used by UI/Controllers
///
/// Key Decisions:
/// - Uses factory constructors for environment-specific setups
/// - Keeps object immutable after creation
/// - Separates wiring from usage
///
/// Trade-offs:
/// - Still relies on underlying singleton instances internally
///   (pragmatic choice for simplicity)
/// - Manual DI instead of frameworks (e.g., GetIt/Riverpod)
///
/// Scalability:
/// Easily extendable for:
/// - mock dependencies (testing)
/// - debug services
/// - alternate data sources
class AppDependencies {
  const AppDependencies._({
    required this.noteRepository,
    required this.appSettingsRepository,
    required this.uiNotifier,
    required this.environment,
  });

  /// Repository handling note data and persistence
  final note_lib.NoteRepository noteRepository;

  /// Repository managing app-level settings (e.g., theme)
  final settings_lib.AppSettingsRepository appSettingsRepository;

  /// UI notification abstraction (e.g., SnackBars)
  final ui_lib.UiNotifier uiNotifier;

  /// Current application environment
  final bootstrap.AppEnvironment environment;

  /// -------------------------------------------------------------------------
  /// PRODUCTION CONFIGURATION
  /// -------------------------------------------------------------------------
  ///
  /// Uses app-wide shared instances (singletons).
  ///
  /// Intended for:
  /// - Real user environment
  /// - Stable runtime configuration
  factory AppDependencies.production() {
    return AppDependencies._(
      noteRepository: note_lib.noteRepository,
      appSettingsRepository: settings_lib.appSettingsRepository,
      uiNotifier: ui_lib.uiNotifier,
      environment: bootstrap.AppEnvironment.production,
    );
  }

  /// -------------------------------------------------------------------------
  /// DEVELOPMENT CONFIGURATION
  /// -------------------------------------------------------------------------
  ///
  /// Currently mirrors production wiring.
  ///
  /// Purpose:
  /// - Provides a clear extension point for:
  ///     • mock services
  ///     • debug tools
  ///     • alternate repositories
  ///
  /// Future:
  /// - Can inject fake data sources or logging layers
  factory AppDependencies.development() {
    return AppDependencies._(
      noteRepository: note_lib.noteRepository,
      appSettingsRepository: settings_lib.appSettingsRepository,
      uiNotifier: ui_lib.uiNotifier,
      environment: bootstrap.AppEnvironment.development,
    );
  }
}
