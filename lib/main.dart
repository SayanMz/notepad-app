import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'package:notepad/core/bootstrap/app_bootstrapper.dart';
import 'package:notepad/core/bootstrap/bootstrap_app.dart';
import 'package:notepad/core/data/app_settings_repository.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_theme.dart';
import 'package:notepad/features/home/home_page.dart';
import 'package:notepad/core/data/notes_repository.dart';

/// ===========================================================================
/// APPLICATION ENTRY POINT
/// ===========================================================================

Future<void> main() async {
  /// Executes the application inside a guarded zone to capture uncaught
  /// synchronous and asynchronous errors across the full runtime lifecycle.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      /// Handles Flutter framework errors.
      /// Maintains default error presentation while ensuring structured logging.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exceptionAsString()}');
        if (details.stack != null) {
          debugPrintStack(stackTrace: details.stack);
        }
      };

      /// Captures platform and engine-level errors not surfaced through
      /// FlutterError, preventing silent failures across async boundaries.
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Platform error: $error');
        debugPrintStack(stackTrace: stack);
        return true;
      };

      debugPrint('Starting Notepad bootstrap...');

      final bootstrapper = AppBootstrapper(
        noteRepository: noteRepository,
        appSettingsRepository: appSettingsRepository,
      );

      runApp(
        BootstrapApp(
          bootstrapper: bootstrapper.initialize,
          child: const MyApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Fatal startup error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

/// ===========================================================================
/// ROOT APPLICATION
/// ===========================================================================

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettingsRepository,
      builder: (_, settings) {
        return MaterialApp(
          title: 'My Notepad',
          debugShowCheckedModeBanner: false,
          //showPerformanceOverlay: true,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appSettingsRepository.themeMode,
          home: const HomePage(),
          scaffoldMessengerKey: uiNotifier.scaffoldMessengerKey,
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
            },
          ),
        );
      },
    );
  }
}
