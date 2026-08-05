import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/trash/widgets/scroll_to_top_fab.dart';

void main() {
  testWidgets('ScrollToTopFab visibility based on scroll position', (tester) async {
    final scrollController = ScrollController();
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scrollController,
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
          floatingActionButton: ScrollToTopFab(
            scrollController: scrollController,
            heroTag: 'test_fab',
            behavior: FabScrollBehavior.persistentWhileScrolling,
          ),
        ),
      ),
    );

    // 1. Initial state: pixels = 0, FAB should be invisible (opacity 0)
    final fabFinder = find.byType(FloatingActionButton);
    AnimatedOpacity opacityWidget = tester.widget(find.ancestor(
      of: fabFinder,
      matching: find.byType(AnimatedOpacity),
    ));
    expect(opacityWidget.opacity, 0.0);

    // 2. Scroll past threshold (200px)
    scrollController.jumpTo(300);
    await tester.pump();
    
    // Drag down to scroll UP (Forward direction)
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 50)); 
    await tester.pump(); // Start animation
    await tester.pump(const Duration(milliseconds: 300)); // Complete animation

    opacityWidget = tester.widget(find.ancestor(
      of: fabFinder,
      matching: find.byType(AnimatedOpacity),
    ));
    expect(opacityWidget.opacity, 1.0);

    // 3. Tap to scroll to top
    await tester.tap(fabFinder);
    await tester.pumpAndSettle();
    
    expect(scrollController.offset, 0.0);
  });
}
