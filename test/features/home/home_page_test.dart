import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/home_page.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';
import 'package:notepad/features/home/widgets/home_fab.dart';
import 'package:notepad/features/home/widgets/note_list_items/note_list.dart';

void main() {
  testWidgets('HomePage renders essential components', (tester) async {
    // Set a fixed screen size
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );

    // Initial pump to build the UI
    await tester.pump();

    expect(find.byType(HomeAppBar), findsOneWidget);
    expect(find.byType(NoteList), findsOneWidget);
    expect(find.byType(HomeFab), findsOneWidget);
  });

  testWidgets('HomePage shows the drawer when menu is tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(),
      ),
    );

    await tester.pump();

    final appBar = find.byType(HomeAppBar);
    expect(appBar, findsOneWidget);

    final menuButton = find.descendant(
      of: appBar,
      matching: find.byIcon(Icons.sort),
    );

    await tester.tap(menuButton);
    // Use pump instead of pumpAndSettle to avoid timeout from persistent animations
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(Scaffold), findsOneWidget);
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    expect(scaffoldState.isEndDrawerOpen, isTrue);
  });
}
