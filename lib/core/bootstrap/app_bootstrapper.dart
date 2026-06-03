// Keep bootstrap outside the widget tree so retries stay deterministic.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/services/security_key_vault_service.dart';

typedef BootstrapStep = Future<void> Function();

enum AppEnvironment { production, development, test }

// Keep bootstrap outside the widget tree so retries stay deterministic.
class AppBootstrapper {
  AppBootstrapper({
    required this.noteRepository,
    required this.appSettingsRepository,
    BootstrapStep? initializePersistence,
    BootstrapStep? initializeRepositories,
    void Function(String message)? log,
  }) : _log = log ?? debugPrint,
       _initializePersistenceStep =
           initializePersistence ?? _defaultInitializePersistence,
       _initializeRepositoriesStep =
           initializeRepositories ??
           _defaultRepositoriesStep(noteRepository, appSettingsRepository);

  final NoteRepository noteRepository;
  final AppSettingsRepository appSettingsRepository;
  final void Function(String message) _log;
  final BootstrapStep _initializePersistenceStep;
  final BootstrapStep _initializeRepositoriesStep;

  // Cache the in-flight future so startup work runs once per attempt.
  Future<void>? _bootstrapFuture;

  Future<void> initialize() {
    final existing = _bootstrapFuture;
    if (existing != null) return existing;

    final future = _initialize().catchError((error, stack) {
      // Clear the cached future so a later launch can retry from scratch.
      _bootstrapFuture = null;
      _log('Bootstrap failed: $error');

      if (stack is StackTrace) {
        debugPrintStack(stackTrace: stack);
      }

      throw error;
    });

    _bootstrapFuture = future;
    return future;
  }

  Future<void> _initialize() async {
    _log('Bootstrap: initializing persistence');
    await _initializePersistenceStep();

    _log('Bootstrap: initializing repositories');
    await _initializeRepositoriesStep();

    _log('Bootstrap: complete');
  }

  static Future<void> _defaultInitializePersistence() async {
    await dotenv.load(fileName: '.env');

    // Windows and desktop startup depend on this client id being present.
    if (!dotenv.env.containsKey('GOOGLE_CLIENT_ID')) {
      throw Exception('Missing GOOGLE_CLIENT_ID in .env');
    }

    await Hive.initFlutter();

    // Adapter registration must tolerate hot restart and retry paths.
    if (!Hive.isAdapterRegistered(NotesSectionAdapter().typeId)) {
      Hive.registerAdapter(NotesSectionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppSettingsAdapter().typeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }

    // A single stable device key keeps encrypted boxes readable across launches.
    final List<int> encryptionKey =
        await SecureKeyVaultService.getOrCreateEncryptionKey();

    // Once the key exists, both boxes can open in parallel.
    await Future.wait([
      Hive.openBox<NotesSection>(
        'notes_box',
        encryptionCipher: HiveAesCipher(encryptionKey),
      ),
      Hive.openBox<AppSettings>(
        'settings_box',
        encryptionCipher: HiveAesCipher(encryptionKey),
      ),
    ]);
  }

  static BootstrapStep _defaultRepositoriesStep(
    NoteRepository noteRepository,
    AppSettingsRepository appSettingsRepository,
  ) {
    // Settings must load first so seed checks read the persisted version.
    return () async {
      await appSettingsRepository.load();
      await noteRepository.init();
    };
  }
}
