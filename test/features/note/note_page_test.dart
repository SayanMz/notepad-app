import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/features/note/note_page.dart';
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';

class _FakeHttpClient extends Fake implements http.Client {
  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return http.Response(
      jsonEncode({
        'data': [
          {'id': 'qwen/qwen-2.5-32b'}
        ]
      }),
      200,
    );
  }
}

void main() {
  setUpAll(() async {
    // Required to prevent 'NotInitializedError' during Groq warmup in initState
    dotenv.loadFromString(envString: 'GROQ_API_KEY=test_key');
    GroqService.httpClient = _FakeHttpClient();
  });

  testWidgets('NotePage shows the editor shell and opens the toolbar',
      (tester) async {
    // 1. Load a dummy starting point
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotePage(
                    title: 'Draft note',
                    content: 'Hello world',
                  ),
                ),
              ),
              child: const Text('Push'),
            ),
          ),
        ),
      ),
    );

    // 2. Trigger a REAL route transition
    await tester.tap(find.text('Push'));

    // 3. Advance the animation clock manually to avoid pumpAndSettle hangs
    // We wait 1.5s for the route transition and initial UI setups to finish.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Now _isTransitionAnimating should be false
    expect(find.byKey(const ValueKey('unified_note_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('empty_space')), findsOneWidget);

    // 4. Open the toolbar
    await tester.tap(find.byIcon(Icons.auto_fix_high));

    // 5. Final Cleanup: Wait for all background timers (Nudge: 1.1s, Autosave: 3s)
    // We wait 5 seconds to be absolutely sure all debouncers and animations are dead.
    // We do this BEFORE the test ends to ensure no pending timers remain.
    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byKey(const ValueKey('note_toolbar')), findsOneWidget);

    // 6. Pop the page to trigger clean disposal
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
  });
}
