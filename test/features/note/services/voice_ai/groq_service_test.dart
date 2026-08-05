import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/features/note/services/voice_ai/groq_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FakeHttpClient extends Fake implements http.Client {
  http.Response? response;
  bool postCalled = false;

  @override
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    postCalled = true;
    if (response != null) return response!;
    throw Exception('No response set in FakeHttpClient');
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

    test('parseVoiceCommand returns instructions on success', () async {
      fakeClient.response = http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'instructions': [
                    {'action': 'format', 'target': 'bold'}
                  ]
                })
              }
            }
          ]
        }),
        200,
      );

      final result = await GroqService.parseVoiceCommand('make it bold');

      expect(result, isNotNull);
      expect(result!.first['action'], 'format');
      expect(fakeClient.postCalled, isTrue);
    });

    test('parseVoiceCommand throws GroqServiceException on error', () async {
      fakeClient.response = http.Response('Error', 500);

      expect(
        () => GroqService.parseVoiceCommand('hello'),
        throwsA(isA<GroqServiceException>()),
      );
    });
  });
}
