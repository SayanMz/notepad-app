import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/links/link_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NoteLinkHandler manages overlay popup lifecycle', (tester) async {
    final handler = NoteLinkHandler();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  handler.showHorizontalLinkMenu(
                    context,
                    'https://example.com',
                    false,
                  );
                },
                child: const Text('Show Menu'),
              );
            },
          ),
        ),
      ),
    );

    expect(handler.activeLink, isNull);
    expect(handler.isPopupActive, isFalse);

    await tester.tap(find.text('Show Menu'));
    await tester.pump();

    expect(handler.activeLink, 'https://example.com');
    expect(handler.isPopupActive, isTrue);

    handler.removeLinkPopup();
    await tester.pump();

    expect(handler.activeLink, isNull);
    expect(handler.isPopupActive, isFalse);
  });
}
