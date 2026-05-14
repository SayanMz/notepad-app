import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/features/note/services/voice_ai/voice_ai_prompt.dart';

/// Friendly wrapper for Groq availability/configuration failures.
class GroqServiceException implements Exception {
  GroqServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static Future<void>? _warmUpFuture;
  static String? _apiKey;

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

  /// Ensures the AI environment configuration is available.
  ///
  /// Note: The actual file loading (.env) is now centralized in [AppBootstrapper]
  /// to prevent redundant disk I/O. This method simply validates that the
  /// required keys were loaded successfully.
  static Future<void> _ensureEnvLoaded() async {
    // Optimization: If already cached, exit immediately.
    if (_apiKey != null && _apiKey!.isNotEmpty) return;

    final key = dotenv.env['GROQ_API_KEY'];

    if (key == null || key.isEmpty) {
      throw GroqServiceException(
        'AI service is not configured yet. Please check your .env file.',
      );
    }

    // Cache it for the rest of the app's lifecycle.
    _apiKey = key;
  }

  static Future<List<Map<String, dynamic>>?> parseVoiceCommand(
    String voiceText,
  ) async {
    await _ensureEnvLoaded();

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': voiceAiSystemPrompt},
                {'role': 'user', 'content': voiceText},
              ],
              'temperature': 0.0,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final content = jsonDecode(
          response.body,
        )['choices'][0]['message']['content'];
        final decoded = jsonDecode(content);
        return decoded['instructions'] != null
            ? List<Map<String, dynamic>>.from(decoded['instructions'])
            : null;
      }

      throw GroqServiceException(
        'AI service could not process the request right now. Please try again.',
      );
    } on TimeoutException {
      throw GroqServiceException(
        'AI service timed out. Please check your connection and try again.',
      );
    } on SocketException {
      throw GroqServiceException(
        'AI service is unreachable right now. Please check your internet connection.',
      );
    } on GroqServiceException {
      rethrow;
    } catch (_) {
      throw GroqServiceException(
        'AI service could not be configured right now. Please try again later.',
      );
    }
  }
}
