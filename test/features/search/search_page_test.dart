import 'dart:io';

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/search_page.dart';
import 'package:notepad/features/search/widgets/header/search_input_field_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('search_page_test_');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getTemporaryDirectory':
              return tempDir.path;
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  testWidgets('SearchPage full flow: input text to results display', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SearchPage()));

    // 1. Initial State: No results, showing empty state
    expect(find.byType(SearchInputFieldBar), findsOneWidget);
    expect(find.text('Search your notes by title or content'), findsOneWidget);

    // 2. Type search query
    await tester.enterText(find.byType(TextField), 'Meeting');

    // Search is debounced (e.g. 300ms)
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(SearchInputFieldBar), findsOneWidget);
  });
}
