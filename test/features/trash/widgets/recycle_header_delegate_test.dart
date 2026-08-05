import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/trash/widgets/recycle_header_delegate.dart';

void main() {
  group('SmoothHeaderDelegate', () {
    const double screenHeight = 800.0;
    const String titleText = 'Recycle Bin';

    Widget buildTestWidget({
      required double offset,
      bool forceCentered = false,
      Brightness brightness = Brightness.light,
    }) {
      return MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          colorScheme: brightness == Brightness.dark 
              ? const ColorScheme.dark() 
              : const ColorScheme.light(),
        ),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: SmoothHeaderDelegate(
                  title: titleText,
                  forceCentered: forceCentered,
                  onEmptyBin: () {},
                  scrollOffset: offset,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 2000)),
            ],
          ),
        ),
      );
    }

    Finder findHeaderMaterial() {
      return find.byKey(const ValueKey('smooth_header_material'));
    }

    testWidgets('Background materializes based on scroll progress', (tester) async {
      tester.view.physicalSize = const Size(400, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // 1. Initial state (0.0 scroll) - Surface progress 0%
      await tester.pumpWidget(buildTestWidget(offset: 0.0));
      expect(tester.widget<Material>(findHeaderMaterial()).elevation, 0.0);
      
      // 2. Intermediate state (surface progress starts at 4% = 32px)
      // At 48px, progress = (48-32)/(64-32) = 0.5. Elevation = 0.5 * 4 = 2.0.
      await tester.pumpWidget(buildTestWidget(offset: 48.0));
      expect(tester.widget<Material>(findHeaderMaterial()).elevation, 2.0);

      // 3. Fully materialized (at 8% = 64px)
      await tester.pumpWidget(buildTestWidget(offset: 100.0));
      expect(tester.widget<Material>(findHeaderMaterial()).elevation, 4.0);
    });

    testWidgets('Title transition stages (Anchor -> Dissolve -> Bloom)', (tester) async {
      tester.view.physicalSize = const Size(400, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Stage 1: Anchor
      await tester.pumpWidget(buildTestWidget(offset: 0.0));
      
      final heroTextFinder = find.descendant(
        of: find.byType(Center),
        matching: find.text(titleText),
      );
      expect(heroTextFinder, findsOneWidget);
      
      final Opacity heroOpacity = tester.widget(find.ancestor(
        of: heroTextFinder,
        matching: find.byType(Opacity),
      ));
      expect(heroOpacity.opacity, 1.0);

      // Stage 2: Dissolve
      await tester.pumpWidget(buildTestWidget(offset: 104.0));
      final Opacity dissolveOpacity = tester.widget(find.ancestor(
        of: heroTextFinder,
        matching: find.byType(Opacity),
      ));
      expect(dissolveOpacity.opacity, lessThan(1.0));

      // Stage 3: Bloom
      await tester.pumpWidget(buildTestWidget(offset: 200.0));
      
      expect(heroTextFinder, findsNothing);

      final navTextFinder = find.descendant(
        of: find.byType(Align),
        matching: find.text(titleText),
      );
      
      expect(navTextFinder, findsOneWidget);
      final Opacity navOpacity = tester.widget(find.ancestor(
        of: navTextFinder,
        matching: find.byType(Opacity),
      ));
      expect(navOpacity.opacity, 1.0);
    });

    testWidgets('forceCentered prevents bloom', (tester) async {
      tester.view.physicalSize = const Size(400, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget(offset: 250.0, forceCentered: true));
      
      expect(find.descendant(
        of: find.byType(Align),
        matching: find.text(titleText),
      ), findsNothing);
      
      expect(find.byIcon(Icons.delete_sweep), findsNothing);
    });

    testWidgets('Empty bin callback is triggered', (tester) async {
      bool emptyBinCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  delegate: SmoothHeaderDelegate(
                    title: titleText,
                    forceCentered: false,
                    onEmptyBin: () => emptyBinCalled = true,
                    scrollOffset: 0.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.delete_sweep));
      expect(emptyBinCalled, isTrue);
    });

    testWidgets('Brightness affects colors', (tester) async {
      tester.view.physicalSize = const Size(400, screenHeight);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Light Mode
      await tester.pumpWidget(buildTestWidget(offset: 100.0, brightness: Brightness.light));
      expect(tester.widget<Material>(findHeaderMaterial()).color, const Color(0xFFF3F3F3));

      // Dark Mode
      await tester.pumpWidget(Container()); // Clear
      await tester.pumpWidget(buildTestWidget(offset: 100.0, brightness: Brightness.dark));
      expect(tester.widget<Material>(findHeaderMaterial()).color, const Color(0xFF2C2C2C));
    });
  });
}
