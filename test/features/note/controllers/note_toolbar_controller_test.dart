import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/controllers/note_toolbar_controller.dart';

void main() {
  test('register, unregister, and closeAllMenus cooperate safely', () {
    final controller = NoteToolbarController();
    var firstCount = 0;
    var secondCount = 0;

    void firstClose() {
      firstCount++;
    }

    void secondClose() {
      secondCount++;
    }

    controller.register(firstClose);
    controller.register(secondClose);
    controller.closeAllMenus();

    expect(firstCount, 1);
    expect(secondCount, 1);

    controller.unregister(firstClose);
    controller.closeAllMenus();

    expect(firstCount, 1);
    expect(secondCount, 2);
  });
}
