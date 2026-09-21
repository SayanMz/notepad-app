import 'dart:io';

import 'package:flutter/material.dart' hide SearchController;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/controllers/search_controller.dart';
import 'package:notepad/features/search/widgets/header/search_input_field_bar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('search_input_field_bar_test_');
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

  testWidgets('SearchInputFieldBar handles input and clear actions', (
    tester,
  ) async {
    final controller = SearchController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchInputFieldBar(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ),
    );

    // Initial state
    expect(find.text('Search title or content...'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);

    // Enter text
    await tester.enterText(find.byType(TextField), 'Draft note');
    await tester.pump();

    // Verify clear icon appears
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(controller.textController.text, 'Draft note');

    // Tap clear
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pump();

    expect(controller.textController.text, '');
    expect(find.byIcon(Icons.clear), findsNothing);
  });
}
