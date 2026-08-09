import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/widgets/results/empty_states.dart';

void main() {
  testWidgets('SearchInitialState shows the default empty-search guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SearchInitialState())),
    );

    expect(find.text('Search your notes by title or content'), findsOneWidget);
    expect(
      find.text('Type a keyword or use the filter to find notes.'),
      findsOneWidget,
    );
  });

  testWidgets('SearchEmptyState reflects whether a query was provided', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SearchEmptyState(query: 'draft')),
      ),
    );

    expect(find.text('No notes matched "draft"'), findsOneWidget);
    expect(
      find.text('Try a shorter phrase or adjust your selection.'),
      findsOneWidget,
    );
  });
}
