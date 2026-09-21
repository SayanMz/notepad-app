import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/links/link_service.dart';
import 'package:notepad/features/note/widgets/editor/link_menu_bar.dart';

void main() {
  testWidgets(
    'LinkMenuBar displays primary button label and triggers callbacks',
    (tester) async {
      bool openCalled = false;
      bool copyCalled = false;
      bool shareCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkMenuBar(
              type: NoteLinkType.phone,
              isDark: false,
              onOpen: () => openCalled = true,
              onCopy: () => copyCalled = true,
              onShare: () => shareCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Call'));
      expect(openCalled, isTrue);

      await tester.tap(find.text('Copy'));
      expect(copyCalled, isTrue);

      await tester.tap(find.text('Share'));
      expect(shareCalled, isTrue);
    },
  );

  testWidgets(
    'LinkMenuBar renders correct primary label for web link type',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LinkMenuBar(
              type: NoteLinkType.web,
              isDark: true,
              onOpen: () {},
              onCopy: () {},
              onShare: () {},
            ),
          ),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
    },
  );
}
