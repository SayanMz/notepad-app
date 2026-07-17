import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/note_page.dart';

void main() {
  testWidgets('NotePage shows the editor shell and opens the toolbar',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NotePage(
          title: 'Draft note',
          content: 'Hello world',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unified_note_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty_space')), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.byIcon(Icons.auto_fix_high));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('note_toolbar')), findsOneWidget);
  });
}
