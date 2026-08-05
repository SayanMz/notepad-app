import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/selection_tools/premium_color_picker.dart';

void main() {
  testWidgets('PremiumColorPicker displays colors and triggers callback', (tester) async {
    Color? selectedColor;
    final recentColors = [Colors.red, Colors.green, Colors.blue];
    final offsetNotifier = ValueNotifier<Offset>(Offset.zero);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PremiumColorPicker(
            initialColor: Colors.red,
            recentColors: recentColors,
            onPreviewChanged: (color) => selectedColor = color,
            dialogOffsetNotifier: offsetNotifier,
          ),
        ),
      ),
    );

    expect(find.text('Color'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    
    // Check if recent color swatches are rendered
    expect(find.byType(GestureDetector), findsAtLeast(3));

    // Tap a recent color (Green)
    await tester.tap(find.byType(GestureDetector).at(2)); // index 2 is usually the first swatch in the wrap
    await tester.pump();

    // Verify callback was triggered
    expect(selectedColor, isNotNull);
  });
}
