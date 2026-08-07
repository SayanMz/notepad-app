import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';

void main() {
  testWidgets('triggerVaporizeAnimation marks ids until the animation window ends', (tester) async {
    final controller = AnimationControllerState();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    final future = controller.triggerVaporizeAnimation({'note-1', 'note-2'});

    expect(controller.isVaporizing('note-1'), isTrue);
    expect(controller.isVaporizing('note-2'), isTrue);

    await tester.pump(AnimationConstants.medium);
    await future;

    expect(controller.isVaporizing('note-1'), isFalse);
    expect(controller.isVaporizing('note-2'), isFalse);
  });
}
