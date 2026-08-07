import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_ui_controller.dart';
import 'package:notepad/features/note/note_constants.dart';

void main() {
  group('NoteUIController', () {
    late NoteUIController controller;

    setUp(() {
      controller = NoteUIController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has editing disabled and full opacity', () {
      expect(controller.isEditing.value, isFalse);
      expect(controller.aiButtonOpacity.value, 1.0);
    });

    test('toggleEditMode flips the isEditing state', () {
      controller.toggleEditMode();
      expect(controller.isEditing.value, isTrue);

      controller.toggleEditMode();
      expect(controller.isEditing.value, isFalse);
    });

    test('orchestrateButtonVisibility dims the AI button immediately', () {
      controller.orchestrateButtonVisibility();
      expect(controller.aiButtonOpacity.value, NoteConstants.aiButtonOpacityDim);
    });
  });
}
