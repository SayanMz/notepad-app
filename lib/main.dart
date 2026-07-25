import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/bootstrap/app_bootstrapper.dart';
import 'package:notepad/core/bootstrap/bootstrap_app.dart';
import 'package:notepad/core/database/app_settings_repository.dart';
import 'package:notepad/core/database/notes_repository.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/services/ui_management/theme_fader.dart';
import 'package:notepad/core/theme/app_theme.dart';
import 'package:notepad/features/home/widgets/splash_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// App startup wires global error handling, storage init, and theme bootstrapping.
Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (!kIsWeb) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }

      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exceptionAsString()}');
        if (details.stack != null) {
          debugPrintStack(stackTrace: details.stack);
        }
      };

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isInitializationComplete =
        BootstrapScope.of(context)?.isInitializationComplete ?? false;

    return ListenableBuilder(
      listenable: appSettingsRepository,
      builder: (_, settings) {
        return RepaintBoundary(
          key: ThemeFader.appBoundaryKey,
          child: MaterialApp(
            title: 'My Notepad',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: appSettingsRepository.themeMode,
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
                PointerDeviceKind.trackpad,
              },
            ),
            home: SplashPage(
              isInitializationComplete: isInitializationComplete,
            ),
          ),
        );
      },
    );
  }
}
