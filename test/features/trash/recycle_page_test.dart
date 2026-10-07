import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/trash/recycle_page.dart';
import 'package:notepad/features/trash/widgets/recycle_empty_state.dart';

void main() {
  testWidgets('RecyclePage shows empty state when no notes deleted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RecyclePage(),
      ),
    );

    expect(find.text('Recycle Bin'), findsOneWidget);
    expect(find.byType(RecycleEmptyState), findsOneWidget);
  });
}
