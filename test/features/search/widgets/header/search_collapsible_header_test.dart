import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/controllers/search_controller.dart' as search_ctrl;
import 'package:notepad/features/search/widgets/header/search_collapsible_header.dart';
import 'package:notepad/features/search/widgets/header/search_input_field_bar.dart';
import 'package:notepad/features/search/widgets/header/quick_chips.dart';
import 'package:notepad/features/search/widgets/filter/filter_button.dart';

void main() {
  testWidgets('SearchCollapsibleHeader renders input bar, filter button, and quick chips', (tester) async {
    final controller = search_ctrl.SearchController();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SearchCollapsibleHeader(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SearchInputFieldBar), findsOneWidget);
    expect(find.byType(SearchFilterButton), findsOneWidget);
    expect(find.byType(SearchQuickChips), findsOneWidget);

    focusNode.dispose();
    controller.dispose();
  });
}
