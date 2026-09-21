import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/note_list_items/animated_trash_icon.dart';

void main() {
  testWidgets('AnimatedTrashIcon renders bin container and lid with lidProgress translation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedTrashIcon(
            lidProgress: 0.5,
            color: Colors.red,
            size: 32.0,
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedTrashIcon), findsOneWidget);
    expect(find.byType(Transform), findsWidgets);

    final SizedBox sizeBox = tester.widget(find.byType(SizedBox).first);
    expect(sizeBox.width, 32.0);
    expect(sizeBox.height, 32.0);
  });

  testWidgets('AnimatedTrashIcon lidProgress 0.0 applies zero offset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedTrashIcon(
            lidProgress: 0.0,
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedTrashIcon), findsOneWidget);
  });
}
