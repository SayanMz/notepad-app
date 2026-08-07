import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/home_app_bar.dart';

void main() {
  testWidgets('HomeAppBar displays title and menu icons', (tester) async {
    bool drawerOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              HomeAppBar(onOpenDrawer: () => drawerOpened = true),
            ],
          ),
        ),
      ),
    );

    // Find the title (It appears twice in the Stack, but only one is visible usually)
    expect(find.text('Notepad'), findsWidgets);
    
    // Find icons
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
    expect(find.byIcon(Icons.sort), findsOneWidget);

    // Test drawer callback
    await tester.tap(find.byIcon(Icons.sort));
    expect(drawerOpened, isTrue);
  });
}
