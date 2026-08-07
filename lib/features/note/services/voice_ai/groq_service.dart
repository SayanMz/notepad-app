import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/services/voice_ai/voice_ai_prompt.dart';

// Groq AI client for voice-command parsing, warm-up, and error-normalized responses.
class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static Future<void>? _warmUpFuture;
  static String? _apiKey;

  @visibleForTesting
  static http.Client? httpClient;
  static http.Client get _client => httpClient ?? http.Client();

  static Future<void> warmUp() {
    final existing = _warmUpFuture;
    if (existing != null) return existing;

    final future = _ensureEnvLoaded().catchError((error) {
      _warmUpFuture = null;
      throw error;
    });

    _warmUpFuture = future;
    return future;
  }

  static Future<void> _ensureEnvLoaded() async {
    if (_apiKey != null && _apiKey!.isNotEmpty) return;

    final key = dotenv.env['GROQ_API_KEY'];

    if (key == null || key.isEmpty) {
      throw GroqServiceException(
        'AI service is not configured yet. Please check your .env file.',
      );
    }

    _apiKey = key;
  }

  static Future<List<Map<String, dynamic>>?> parseVoiceCommand(
    String voiceText,
  ) async {
    await _ensureEnvLoaded();
    http.Response response;

    try {
      response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'llama-3.3-70b-versatile',
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': voiceAiSystemPrompt},
                {'role': 'user', 'content': voiceText},
              ],
              'temperature': 0.0,
            }),
          )
          .timeout(AnimationConstants.voiceRequestTimeout);
      // Network Request
    } on TimeoutException {
      throw GroqServiceException(
        'AI service timed out. Please check your connection and try again.',
      );
      // Network Offline
    } on SocketException {
      throw GroqServiceException(
        'AI service is unreachable right now. Please check your internet connection.',
      );
    } catch (_) {
      // Catch-all fallback for UNKNOWN errors (e.g. JSON parsing crash)
      throw GroqServiceException(
        'AI service could not be configured right now. Please try again later.',
      );
    }

    if (response.statusCode == 200) {
      final content = jsonDecode(
        response.body,
      )['choices'][0]['message']['content'];
      final decoded = jsonDecode(content);
      return decoded['instructions'] != null
          ? List<Map<String, dynamic>>.from(decoded['instructions'])
          : null;
    }
    //The HTTP Failure Exception
    throw GroqServiceException(
      'AI service could not process the request right now. Please try again.',
    );
  }
}

class GroqServiceException implements Exception {
  GroqServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
