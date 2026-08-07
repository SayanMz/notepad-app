import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_empty_state.dart';

void main() {
  testWidgets('NoteEmptyState displays robot and messaging', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NoteEmptyState(),
        ),
      ),
    );

    expect(find.byType(Lottie), findsOneWidget);
    expect(find.text('It’s awfully quiet in here'), findsOneWidget);
    expect(find.textContaining('Feed me some notes'), findsOneWidget);
  });
}
