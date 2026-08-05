import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/drawer_items/spinning_sync_icon.dart';

void main() {
  testWidgets('SpinningSyncIcon renders and animates', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SpinningSyncIcon(),
        ),
      ),
    );

    expect(find.byType(SpinningSyncIcon), findsOneWidget);
    
    // Use a descendant finder to isolate the rotation inside our custom widget,
    // as MaterialApp/Scaffold may introduce their own transitions.
    expect(
      find.descendant(
        of: find.byType(SpinningSyncIcon),
        matching: find.byType(RotationTransition),
      ),
      findsOneWidget,
    );
    
    expect(find.byIcon(Icons.sync), findsOneWidget);
  });
}
