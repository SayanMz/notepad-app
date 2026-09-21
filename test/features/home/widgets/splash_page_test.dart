import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/widgets/splash_page.dart';

void main() {
  testWidgets('SplashPage renders the brand title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage(isInitializationComplete: false)),
    );

    await tester.pump();

    expect(find.text('Notepad'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
