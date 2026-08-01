import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/status/save_indicator.dart';

void main() {
  Widget wrapWidget(ValueNotifier<SaveState> state) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [SaveIndicator(saveState: state)]),
      ),
    );
  }

  testWidgets('SaveIndicator displays saving state', (tester) async {
    final state = ValueNotifier<SaveState>(SaveState.saving);

    await tester.pumpWidget(wrapWidget(state));

    expect(find.text('Saving...'), findsOneWidget);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('SaveIndicator displays saved state', (tester) async {
    final state = ValueNotifier<SaveState>(SaveState.saved);

    await tester.pumpWidget(wrapWidget(state));

    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Saving...'), findsNothing);
  });

  testWidgets('SaveIndicator stays hidden while idle', (tester) async {
    final state = ValueNotifier<SaveState>(SaveState.idle);

    await tester.pumpWidget(wrapWidget(state));

    expect(find.text('Saved'), findsNothing);
    expect(find.text('Saving...'), findsNothing);
  });
}
