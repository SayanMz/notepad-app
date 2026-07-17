import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/home_constants.dart';

void main() {
  test('updateFabState keeps FAB state and position in sync', () {
    final controller = HomeController();

    expect(controller.isFabExtended.value, isTrue);
    expect(controller.fabAlignX.value, 0.0);

    controller.updateFabState(extend: false);
    expect(controller.isFabExtended.value, isFalse);
    expect(controller.fabAlignX.value, HomeConstants.fabAlignCollapsedX);

    controller.updateFabState(extend: true);
    expect(controller.isFabExtended.value, isTrue);
    expect(controller.fabAlignX.value, HomeConstants.fabAlignExpandedX);

    controller.setDraggingState(true);
    expect(controller.isDraggingNote, isTrue);

    controller.dispose();
  });

  test('updateSyncStatus stores the message immediately and resets later', () async {
    final controller = HomeController();

    controller.updateSyncStatus('Backed up', color: null);
    expect(controller.syncStatusNotifier.value, 'Backed up');

    await Future.delayed(
      AnimationConstants.snackbarLong + const Duration(milliseconds: 50),
    );

    expect(controller.syncStatusNotifier.value, 'Ready to sync');
    expect(controller.statusColorNotifier.value, isNull);

    controller.dispose();
  });

  test('executeBulkDelete is a no-op when nothing is selected', () async {
    final controller = HomeController();

    await controller.executeBulkDelete();

    expect(controller.selectionController.selectedIds, isEmpty);

    controller.dispose();
  });

  test('shareSelectedNotes returns quietly when nothing is selected', () async {
    final controller = HomeController();
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
