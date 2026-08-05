import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/controllers/home_fab_controller.dart';
import 'package:notepad/features/home/home_constants.dart';

void main() {
  group('HomeFabController', () {
    late HomeFabController controller;

    setUp(() {
      controller = HomeFabController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state is extended and aligned at expansion point', () {
      expect(controller.isExtended.value, isTrue);
      expect(controller.alignX.value, HomeConstants.fabAlignExpandedX);
    });

    test('updateState synchronizes extension and alignment', () {
      controller.updateState(extend: false);
      expect(controller.isExtended.value, isFalse);
      expect(controller.alignX.value, HomeConstants.fabAlignCollapsedX);

      controller.updateState(extend: true);
      expect(controller.isExtended.value, isTrue);
      expect(controller.alignX.value, HomeConstants.fabAlignExpandedX);
    });

    testWidgets('handleScroll collapses FAB when scrolling down past threshold',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final notification = ScrollUpdateNotification(
                  metrics: FixedScrollMetrics(
                    minScrollExtent: 0,
                    maxScrollExtent: 1000,
                    pixels: 100,
                    viewportDimension: 500,
                    axisDirection: AxisDirection.down,
                    devicePixelRatio: 1.0,
                  ),
                  scrollDelta: HomeConstants.homeBulkDeleteThreshold + 1,
                  context: context,
                );

                controller.handleScroll(notification, isSelectionMode: false);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(controller.isExtended.value, isFalse);
    });

    testWidgets('handleScroll expands FAB when scrolling up past threshold',
        (tester) async {
      // First collapse it
      controller.updateState(extend: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final notification = ScrollUpdateNotification(
                  metrics: FixedScrollMetrics(
                    minScrollExtent: 0,
                    maxScrollExtent: 1000,
                    pixels: 100,
                    viewportDimension: 500,
                    axisDirection: AxisDirection.down,
                    devicePixelRatio: 1.0,
                  ),
                  scrollDelta: -(HomeConstants.homeBulkDeleteThreshold + 1),
                  context: context,
                );

                controller.handleScroll(notification, isSelectionMode: false);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(controller.isExtended.value, isTrue);
    });

    testWidgets('handleScroll expands FAB when near top regardless of delta',
        (tester) async {
      controller.updateState(extend: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final notification = ScrollUpdateNotification(
                  metrics: FixedScrollMetrics(
                    minScrollExtent: 0,
                    maxScrollExtent: 1000,
                    pixels: HomeConstants.homeTopSnapThreshold - 1,
                    viewportDimension: 500,
                    axisDirection: AxisDirection.down,
                    devicePixelRatio: 1.0,
                  ),
                  scrollDelta: 5.0, // scrolling down slightly but at top
                  context: context,
                );

                controller.handleScroll(notification, isSelectionMode: false);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(controller.isExtended.value, isTrue);
    });
  });
}
