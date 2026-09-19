import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/extensions/context_extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('closeKeyboard completes normally when unfocused', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hello'),
        ),
      ),
    );

    await tester.runAsync(() async {
      await closeKeyboard();
    });
  });

  testWidgets('closeKeyboard removes primary focus when text field is focused', (tester) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(
            focusNode: focusNode,
            autofocus: true,
          ),
        ),
      ),
    );

    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.runAsync(() async {
      await closeKeyboard();
    });

    await tester.pump();
    expect(focusNode.hasFocus, isFalse);
  });
}
