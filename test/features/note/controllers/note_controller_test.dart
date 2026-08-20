import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/note_constants.dart';

void main() {
  test('toggleEditMode flips editing state', () {
    final controller = NoteUIController();

    expect(controller.isEditing.value, isFalse);

    controller.toggleEditMode();
    expect(controller.isEditing.value, isTrue);

    controller.toggleEditMode();
    expect(controller.isEditing.value, isFalse);

    controller.dispose();
  });

  test('orchestrateButtonVisibility dims and restores the AI button', () async {
    final controller = NoteUIController();

    controller.orchestrateButtonVisibility();
    expect(controller.aiButtonOpacity.value, NoteConstants.aiButtonOpacityDim);

    // Wait for the timer to fire (extraLong is 800ms)
    await Future.delayed(AnimationConstants.extraLong + const Duration(milliseconds: 200));

    expect(controller.aiButtonOpacity.value, NoteConstants.aiButtonOpacityFull);
    controller.dispose();
  });
}
