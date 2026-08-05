import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/constants/ui_constants.dart';

void main() {
  test('UIConstants regression test', () {
    // Verifies that core tokens remain stable. 
    // If these change, it should be an intentional design decision.
    expect(UIConstants.paddingLG, 16.0);
    expect(UIConstants.radiusMD, 12.0);
    expect(UIConstants.elevationLow, 2.0);
    expect(UIConstants.iconMD, 24.0);
    expect(UIConstants.themeInputRadius, 30.0);
  });
}
