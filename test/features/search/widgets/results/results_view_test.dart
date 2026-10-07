import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/controllers/search_controller.dart' as search_ctrl;
import 'package:notepad/features/search/widgets/results/results_view.dart';
import 'package:notepad/features/search/widgets/results/search_empty_state.dart';

void main() {
  testWidgets('ResultsMetadataHeader renders clear filter button when filters active', (tester) async {
    final controller = search_ctrl.SearchController();
    bool clearCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultsMetadataHeader(
            controller: controller,
            onClearFilter: () => clearCalled = true,
          ),
        ),
      ),
    );

    expect(find.byType(ResultsMetadataHeader), findsOneWidget);
    expect(clearCalled, isFalse);

    controller.dispose();
  });

  testWidgets('ResultsView renders initial state when no criteria provided', (tester) async {
    final controller = search_ctrl.SearchController();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultsView(
            controller: controller,
            scrollController: scrollController,
          ),
        ),
      ),
    );

    expect(find.byType(SearchInitialState), findsOneWidget);

    scrollController.dispose();
    controller.dispose();
  });

  testWidgets('ResultsView renders search empty state when query provided but no matches found', (tester) async {
    final controller = search_ctrl.SearchController();
    controller.textController.text = 'unmatched_query_x_123';
    controller.onQueryChanged('unmatched_query_x_123');

    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultsView(
            controller: controller,
            scrollController: scrollController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SearchEmptyState), findsOneWidget);

    scrollController.dispose();
    controller.dispose();
  });
}
