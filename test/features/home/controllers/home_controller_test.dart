import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/animation_controller.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';

HomeController _buildController() {
  return HomeController(
    selectionController: SelectionController(),
    animationController: AnimationControllerState(),
  );
}

void main() {
  test('openNote forwards the provided note id', () async {
    final controller = _buildController();
    String? receivedId;

    await controller.openNote(
      noteId: 'note-1',
      onNavigate: (noteId) async {
        receivedId = noteId;
      },
    );

    expect(receivedId, 'note-1');

    controller.dispose();
  });

  test('updateSelectedColors notifies local color listeners', () {
    final controller = _buildController();
    final previousTick = controller.colorChangeNotifier.value;

    controller.updateSelectedColors(Colors.red);

    expect(controller.colorChangeNotifier.value, previousTick + 1);

    controller.dispose();
  });

  test('executeBulkDelete is a no-op when nothing is selected', () async {
    final controller = _buildController();

    await controller.executeBulkDelete();

    expect(controller.selectionController.selectedIds, isEmpty);

    controller.dispose();
  });

  test('shareSelectedNotes returns quietly when nothing is selected', () async {
    final controller = _buildController();
    var errorCalled = false;

    await controller.shareSelectedNotes(
      onError: (_) {
        errorCalled = true;
      },
    );

    expect(errorCalled, isFalse);

    controller.dispose();
  });
}
