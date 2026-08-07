import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/widgets/search_drag_handle.dart';

void main() {
  testWidgets('SearchDragHandle renders custom painter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SearchDragHandle(),
        ),
      ),
    );

    // Verify that the handle specifically contains its custom painter.
    // We use a descendant finder because Scaffold/Material can introduce other CustomPaints.
    expect(find.byType(SearchDragHandle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SearchDragHandle),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });
}
