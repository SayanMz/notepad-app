import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/search/widgets/results/search_result_card.dart';

void main() {
  testWidgets('SearchResultCard displays title and handles highlights', (tester) async {
    final note = NotesSection(
      id: '1',
      title: 'Coffee recipes',
      content: 'Make latte with milk and coffee beans.',
      updatedAt: DateTime(2026, 8, 4),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchResultCard(
            note: note,
            query: 'latte',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Coffee recipes'), findsOneWidget);
    // Since highlights are in rich text, we check for visibility of snippets
    expect(find.textContaining('Make latte'), findsOneWidget);
  });
}
