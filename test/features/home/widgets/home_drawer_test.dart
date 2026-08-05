import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/auth_controller.dart';
import 'package:notepad/features/home/controllers/sync_controller.dart';
import 'package:notepad/features/home/widgets/drawer_items/home_drawer.dart';

class MockAuthController extends AuthController {
  @override
  String? get displayName => 'Test User';
  @override
  String? get displayEmail => 'test@example.com';
  @override
  bool get isAuthenticated => true;
  @override
  Map<String, dynamic> get storageStats => {'percent': 0.7, 'text': '70% used'};
}

class MockSyncController extends SyncController {
  MockSyncController({required super.authController});
  @override
  bool get isSaving => false;
  @override
  String get statusText => 'Idle';
}

void main() {
  testWidgets('HomeDrawer displays user info and storage stats', (tester) async {
    final auth = MockAuthController();
    final sync = MockSyncController(authController: auth);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          drawer: HomeDrawer(
            authController: auth,
            syncController: sync,
          ),
        ),
      ),
    );

    // Open drawer
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Test User'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('70% used'), findsOneWidget);
  });
}
