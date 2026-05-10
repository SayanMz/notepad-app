import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/data/notes_repository.dart';

/// ---------------------------------------------------------------------------
/// APP BOOTSTRAPPER (INTERVIEW NOTE)
/// ---------------------------------------------------------------------------
///
/// Role:
/// Orchestrates the full application startup lifecycle independently
/// from the UI layer.
///
/// Responsibilities:
/// - Initializes persistence layer (Hive)
/// - Registers adapters safely
/// - Initializes repositories
/// - Provides structured startup logging
/// - Ensures bootstrap runs only once (idempotent)
///
/// Why this design:
/// Separates startup logic from UI to:
/// - Improve testability
/// - Isolate failure points
/// - Keep app initialization deterministic
///
/// Architectural Placement:
/// Bootstrap → Dependencies → UI
///
/// Key Decisions:
/// - Uses injectable BootstrapStep functions for flexibility and testing
/// - Uses Future caching to prevent duplicate initialization
/// - Uses sequential orchestration for dependency safety
/// - Uses parallel execution (Future.wait) where possible for performance
///
/// Trade-offs:
/// - Sequential startup may slightly increase launch time
///   but guarantees consistency
/// - Logging is lightweight (debugPrint) instead of full telemetry system
///
/// Scalability:
/// Designed to support:
/// - multiple environments (prod/dev/test)
/// - staged initialization
/// - future observability integration
typedef BootstrapStep = Future<void> Function();

/// Defines runtime environment modes
///
/// Can be used for:
/// - environment-specific configuration
/// - conditional initialization logic
enum AppEnvironment { production, development, test }

/// ---------------------------------------------------------------------------
/// APP BOOTSTRAPPER
/// ---------------------------------------------------------------------------
///
/// Responsible for:
/// - Coordinating application startup sequence
/// - Initializing persistence layer (Hive)
/// - Initializing repositories
/// - Providing logging hooks for observability
///
/// Design:
/// - Fully testable (steps are injectable)
/// - Idempotent initialization (runs once, reuses future)
/// - Fail-safe (resets state on error)
/// - Supports dependency injection and custom bootstrap flows
class AppBootstrapper {
  AppBootstrapper({
    required this.noteRepository,
    required this.appSettingsRepository,

    /// Optional override for persistence initialization
    BootstrapStep? initializePersistence,

    /// Optional override for repository initialization
    BootstrapStep? initializeRepositories,

    /// Optional logging function (defaults to debugPrint)
    void Function(String message)? log,
  }) : _log = log ?? debugPrint,
       _initializePersistenceStep =
           initializePersistence ?? _defaultInitializePersistence,
       _initializeRepositoriesStep =
           initializeRepositories ??
           _defaultRepositoriesStep(noteRepository, appSettingsRepository);

  /// Repository for note data
  final NoteRepository noteRepository;

  /// Repository for app settings
  final AppSettingsRepository appSettingsRepository;

  /// Logging function used for bootstrap observability
  final void Function(String message) _log;

  /// Step responsible for persistence setup
  final BootstrapStep _initializePersistenceStep;

  /// Step responsible for repository initialization
  final BootstrapStep _initializeRepositoriesStep;

  /// Cached bootstrap future to ensure single execution
  Future<void>? _bootstrapFuture;

  /// -------------------------------------------------------------------------
  /// INITIALIZATION ENTRY POINT
  /// -------------------------------------------------------------------------
  ///
  /// Ensures bootstrap runs only once:
  /// - Returns existing future if already in progress
  /// - Resets state on failure for retry
  Future<void> initialize() {
    final existing = _bootstrapFuture;
    if (existing != null) return existing;

    final future = _initialize().catchError((error, stack) {
      /// Reset future to allow retry after failure
      _bootstrapFuture = null;

      /// Log failure details
      _log('Bootstrap failed: $error');

      if (stack is StackTrace) {
        debugPrintStack(stackTrace: stack);
      }

      throw error;
    });

    _bootstrapFuture = future;
    return future;
  }

  /// -------------------------------------------------------------------------
  /// BOOTSTRAP PIPELINE
  /// -------------------------------------------------------------------------
  ///
  /// Executes startup steps sequentially:
  /// 1. Persistence initialization
  /// 2. Repository initialization
  Future<void> _initialize() async {
    _log('Bootstrap: initializing persistence');
    await _initializePersistenceStep();

    _log('Bootstrap: initializing repositories');
    await _initializeRepositoriesStep();

    _log('Bootstrap: complete');
  }

  /// -------------------------------------------------------------------------
  /// DEFAULT PERSISTENCE INITIALIZATION
  /// -------------------------------------------------------------------------
  ///
  /// Responsibilities:
  /// - Initialize Hive
  /// - Register adapters (idempotent)
  /// - Open required boxes in parallel
  static Future<void> _defaultInitializePersistence() async {
    await Hive.initFlutter();

    /// Adapter registration guarded to prevent duplicates
    if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
      Hive.registerAdapter(NotesSectionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    /// Open storage boxes concurrently
    await Future.wait([
      Hive.openBox<NotesSection>('notes_box'),
      Hive.openBox<AppSettings>('settings_box'),
    ]);
  }

  /// -------------------------------------------------------------------------
  /// DEFAULT REPOSITORY INITIALIZATION
  /// -------------------------------------------------------------------------
  ///
  /// Initializes all repositories required by the app.
  ///
  /// Uses parallel execution for efficiency.
  static BootstrapStep _defaultRepositoriesStep(
    NoteRepository noteRepository,
    AppSettingsRepository appSettingsRepository,
  ) {
    return () async {
      await Future.wait([noteRepository.init(), appSettingsRepository.load()]);
    };
  }
}
