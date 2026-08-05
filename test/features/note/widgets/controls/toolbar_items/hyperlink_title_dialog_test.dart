import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/hyperlink_title_dialog.dart';

void main() {
  testWidgets('showHyperlinkTitleDialog returns text on OK', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showHyperlinkTitleDialog(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // 1. Open Dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Hyperlink Title'), findsOneWidget);

    // 2. Type Title
    await tester.enterText(find.byType(TextField), 'My Website');
    
    // 3. Tap OK
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(result, 'My Website');
  });

  testWidgets('showHyperlinkTitleDialog returns null on Cancel', (tester) async {
    String? result = 'Initial';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showHyperlinkTitleDialog(context);
              },
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
