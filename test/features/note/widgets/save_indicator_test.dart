import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/save_indicator.dart';

void main() {
  testWidgets('SaveIndicator displays "Saving..." when state is saving', (
    WidgetTester tester,
  ) async {
    final fakeState = ValueNotifier<SaveState>(SaveState.saving);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(actions: [SaveIndicator(saveState: fakeState)]),
        ),
      ),
    );

    expect(find.text('Saving...'), findsOneWidget);

    expect(find.text('Saved'), findsNothing);
  });
}
