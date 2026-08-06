import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/database/storage_service.dart';

typedef BootstrapStep = Future<void> Function();

/// Bootstraps persistence and repository setup before the app renders.
class AppInitializer {
  AppInitializer({
    required this.noteRepository,
    required this.appSettingsRepository,
    void Function(String message)? log,
  }) : log = log ?? debugPrint,
       initializePersistenceStep = _initializePersistence,
       initializeRepositoriesStep = _accessRepositories(
         noteRepository,
         appSettingsRepository,
       );

  @visibleForTesting
  AppInitializer.forTesting({
    required this.noteRepository,
    required this.appSettingsRepository,
    required this.initializePersistenceStep,
    required this.initializeRepositoriesStep,
    void Function(String message)? log,
  }) : log = log ?? debugPrint;

  final NoteRepository noteRepository;
  final AppSettingsRepository appSettingsRepository;
  final void Function(String message) log;
  final BootstrapStep initializePersistenceStep;
  final BootstrapStep initializeRepositoriesStep;

  // Cache the in-flight future so startup work runs once per attempt.
  Future<void>? _bootstrapFuture;

  Future<void> initialize() async {
    if (_bootstrapFuture != null) return _bootstrapFuture!;

    try {
      _bootstrapFuture = _runBootstrapPipeline();
      await _bootstrapFuture;
    } catch (error, stack) {
      _bootstrapFuture = null;
      log('Bootstrap failed: $error');

      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  Future<void> _runBootstrapPipeline() async {
    log('Bootstrap: initializing persistence');
    await initializePersistenceStep();

    log('Bootstrap: initializing repositories');
    await initializeRepositoriesStep();

    log('Bootstrap: complete');
  }

  static Future<void> _initializePersistence() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      debugPrint('Bootstrap: No .env file found or failed to load.');
    }

    await Hive.initFlutter();
    await StorageService.initializeEncryptedStorage();
  }

  // Settings must load first so seed checks read the persisted notes version.
  static BootstrapStep _accessRepositories(
    NoteRepository noteRepository,
    AppSettingsRepository appSettingsRepository,
  ) {
    return () async {
      await appSettingsRepository.load();
      await noteRepository.init();
    };
  }
}
