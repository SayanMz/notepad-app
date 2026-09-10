import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/controllers/search_controller.dart' as search_ctrl;
import 'package:notepad/features/search/widgets/header/quick_chips.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('quick_chips_test_');
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

  testWidgets('SearchQuickChips renders quick date chips and smart search section', (tester) async {
    final controller = search_ctrl.SearchController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchQuickChips(controller: controller),
        ),
      ),
    );

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Past 7 days'), findsOneWidget);
    expect(find.text('Past 30 days'), findsOneWidget);
    expect(find.text('Smart Search'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('tapping quick date chip applies filter to search controller', (tester) async {
    final controller = search_ctrl.SearchController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchQuickChips(controller: controller),
        ),
      ),
    );

    await tester.tap(find.text('Past 7 days'));
    await tester.pump();

    expect(controller.filters.hasFilters, isTrue);
    expect(controller.filters.isRangeSearch, isTrue);

    controller.dispose();
  });
}
