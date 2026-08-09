import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_dialog.dart';
import 'package:notepad/features/search/controllers/search_controller.dart' as search_ctrl;
import 'package:notepad/features/search/models/search_filters.dart';
import 'package:notepad/features/search/widgets/filter/search_filter_sheet.dart';

class FakeSearchController extends Fake implements search_ctrl.SearchController {
  @override
  final SearchFilters filters = const SearchFilters();
}

void main() {
  testWidgets('SearchFilterButton renders correctly', (tester) async {
    final controller = FakeSearchController();
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SearchFilterButton(controller: controller),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SearchFilterButton), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('SearchFilterButton opens dialog when tapped', (tester) async {
    final controller = FakeSearchController();
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              SearchFilterButton(controller: controller),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    // The dialog transition takes 350ms, plus some delays in the code.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SearchFilterBottomSheet), findsOneWidget);
  });
}
