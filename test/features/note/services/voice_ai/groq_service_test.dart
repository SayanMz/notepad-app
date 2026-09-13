import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FakeHttpClient extends Fake implements http.Client {
  http.Response? response;
  bool postCalled = false;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    if (url.toString().contains('/models')) {
      return http.Response(
        jsonEncode({
          'data': [
            {'id': 'qwen/qwen-2.5-32b'}
          ]
        }),
        200,
      );
    }
    if (response != null) return response!;
    throw Exception('No response set in FakeHttpClient for GET $url');
  }

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    postCalled = true;
    if (response != null) return response!;
    throw Exception('No response set in FakeHttpClient for POST $url');
  }
}

void main() {
  setUpAll(() async {
    dotenv.loadFromString(envString: 'GROQ_API_KEY=test_api_key');
  });

  group('GroqService', () {
    late FakeHttpClient fakeClient;

    setUp(() {
      fakeClient = FakeHttpClient();
      GroqService.httpClient = fakeClient;
    });

    test('parse returns VoiceInstructions on success', () async {
      fakeClient.response = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'instructions': [
                    {'key': 'bold', 'value': true, 'target': 'selection', 'occurrence': 'all'}
                  ]
                })
              }
            }
          ]
        }),
        200,
      );

      final result = await GroqService().parse('make it bold');

      expect(result, isNotNull);
      expect(result!.first.key, 'bold');
      expect(result.first.target, 'selection');
      expect(fakeClient.postCalled, isTrue);
    });

    test('parse throws GroqServiceException on error', () async {
      fakeClient.response = http.Response('Error', 500);

      // Temporarily silence debugPrint to keep logs clean for expected failures
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};

      try {
        await expectLater(
          () => GroqService().parse('hello'),
          throwsA(isA<GroqServiceException>()),
        );
      } finally {
        debugPrint = originalDebugPrint;
      }
    });
  });
}
