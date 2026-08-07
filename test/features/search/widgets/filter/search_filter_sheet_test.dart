import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_sheet.dart';

void main() {
  testWidgets('SearchFilterBottomSheet renders and toggles range mode', (tester) async {
    const initialFilters = SearchFilters();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchFilterBottomSheet(initialFilters: initialFilters),
        ),
      ),
    );

    // Initial state: No range search, just "DATE" and "TIME"
    expect(find.text('DATE'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('Search range'), findsOneWidget);

    // Toggle range search (using the "Search range" button)
    await tester.tap(find.text('Search range'));
    await tester.pumpAndSettle();

    // Now it should show START/END sections
    expect(find.text('START DATE'), findsOneWidget);
    expect(find.text('END DATE'), findsOneWidget);
  });
}
