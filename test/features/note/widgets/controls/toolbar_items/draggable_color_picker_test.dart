import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/draggable_color_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

void main() {
  testWidgets('DraggableColorPicker renders with initial color', (tester) async {
    Color? changedColor;
    bool dismissRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableColorPicker(
            initialColor: Colors.blue,
            isDark: false,
            onColorChanged: (color) => changedColor = color,
            onDismissRequested: () => dismissRequested = true,
          ),
        ),
      ),
    );

    expect(find.byType(ColorPickerArea), findsOneWidget);
    expect(find.byType(ColorPickerSlider), findsOneWidget);
    expect(changedColor, isNull);
    expect(dismissRequested, isFalse);
  });

  testWidgets('DraggableColorPicker dragging does not crash', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableColorPicker(
            initialColor: Colors.blue,
            isDark: false,
            onColorChanged: (_) {},
            onDismissRequested: () {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(DraggableColorPicker), const Offset(50, 50));
    await tester.pump();

    expect(find.byType(DraggableColorPicker), findsOneWidget);
  });

  testWidgets('DraggableColorPicker changing color triggers callback', (tester) async {
    Color? changedColor;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableColorPicker(
            initialColor: Colors.blue,
            isDark: false,
            onColorChanged: (color) => changedColor = color,
            onDismissRequested: () {},
          ),
        ),
      ),
    );

    // Tap on the ColorPickerArea to change color
    await tester.tap(find.byType(ColorPickerArea));
    await tester.pump();

    expect(changedColor, isNotNull);
    expect(changedColor, isNot(Colors.blue));
  });
}
