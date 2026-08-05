import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';

void main() {
  testWidgets('ScaffoldMessengerUiNotifier displays and clears snackbars',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );

    // 1. Show Success SnackBar
    showSuccessSnackBar('Success message');
    await tester.pump(); // Start animation
    
    expect(find.text('Success message'), findsOneWidget);
    
    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.backgroundColor, Colors.green.shade700);

    // 2. Show Error SnackBar (should replace existing)
    showErrorSnackBar('Error message');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // Wait for transition

    expect(find.text('Success message'), findsNothing);
    expect(find.text('Error message'), findsOneWidget);
    
    final errorSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(errorSnackBar.backgroundColor, AppColors.deleteDarkIcon);

    // 3. Clear SnackBars
    uiNotifier.clearSnackBars();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('showRestorationSnackBar displays undo action', (tester) async {
    bool undoCalled = false;
    
    // Set a larger screen size to ensure the SnackBar with large margins is visible
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        home: const Scaffold(body: Text('Home')),
      ),
    );

    showRestorationSnackBar(
      message: 'Note deleted',
      onUndo: () => undoCalled = true,
      undoLabel: 'RESTORE',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Note deleted'), findsOneWidget);
    expect(find.text('RESTORE'), findsOneWidget);

    await tester.tap(find.text('RESTORE'));
    expect(undoCalled, isTrue);
  });
}
