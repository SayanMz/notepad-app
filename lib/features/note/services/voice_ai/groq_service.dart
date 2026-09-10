import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/features/note/services/voice_ai/voice_ai_prompt.dart';

/// Manages Groq Cloud API interactions to dynamically resolve active Qwen LLM models
/// and parse spoken voice commands into structured document editing instructions.
class GroqService {
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _modelsEndpoint = 'https://api.groq.com/openai/v1/models';

  static String? _resolvedModel;
  static String? _apiKey;
  static Future<void>? _warmUpFuture;

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
    if (_apiKey == null || _apiKey!.isEmpty) {
      final key = dotenv.env['GROQ_API_KEY'];

      if (key == null || key.isEmpty) {
        throw GroqServiceException(
          'AI service is not configured yet. Please check your .env file.',
        );
      }
      _apiKey = key;
    }

    if (_resolvedModel == null || _resolvedModel!.isEmpty) {
      _resolvedModel = await _fetchActiveQwenModel();
    }
  }

  /// Centralized execution helper encapsulating network calls, timeouts,
  /// socket errors, and JSON decoding guards.
  static Future<T> _executeRequest<T>({
    required Future<http.Response> Function() call,
    required T Function(dynamic jsonBody) parser,
    String failureMessage =
        'AI service could not process the request right now.',
    String parseErrorMessage = 'Failed to parse data from the AI service.',
  }) async {
    http.Response response;

    try {
      response = await call().timeout(AnimationConstants.voiceRequestTimeout);
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
        'AI service could not connect right now. Please try again later.',
      );
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(response.body);
        return parser(decoded);
      } on GroqServiceException {
        rethrow;
      } catch (_) {
        throw GroqServiceException(parseErrorMessage);
      }
    }

    debugPrint('Groq API Error [${response.statusCode}]: ${response.body}');
    throw GroqServiceException('$failureMessage [${response.statusCode}]');
  }

  /// Automatically queries Groq's live model catalog to find the highest-version Qwen model.
  static Future<String> _fetchActiveQwenModel() async {
    return _executeRequest<String>(
      call: () => _client.get(
        Uri.parse(_modelsEndpoint),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ),
      failureMessage: 'AI service could not verify model availability',
      parseErrorMessage: 'Failed to parse the active models from AI service.',
      parser: (json) {
        final List<dynamic> models = json['data'] ?? [];
        final qwenModels = models
            .map((m) => m['id'] as String)
            .where((id) => id.startsWith('qwen/'))
            .toList();

        if (qwenModels.isEmpty) {
          throw GroqServiceException(
            'No active Qwen models are currently available on Groq.',
          );
        }

        // Sort descending so the latest active release (e.g. qwen4, qwen3.9) is chosen
        qwenModels.sort((a, b) => b.compareTo(a));
        final selected = qwenModels.first;
        debugPrint(
          'GroqService: Dynamically selected active Qwen model: $selected',
        );
        return selected;
      },
    );
  }

  static Future<List<Map<String, dynamic>>?> parseVoiceCommand(
    String voiceText,
  ) async {
    await _ensureEnvLoaded();

    return _executeRequest<List<Map<String, dynamic>>?>(
      call: () => _client.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _resolvedModel,
          'response_format': {'type': 'json_object'},
          'messages': [
            {'role': 'system', 'content': voiceAiSystemPrompt},
            {'role': 'user', 'content': voiceText},
          ],
          'temperature': 0.0,
        }),
      ),
      failureMessage: 'AI service could not process the voice command',
      parseErrorMessage: 'Failed to parse the voice response from AI service.',
      parser: (json) {
        final content = json['choices'][0]['message']['content'];
        final decoded = jsonDecode(content);
        final instructions = decoded['instructions'];
        return instructions != null
            ? List<Map<String, dynamic>>.from(instructions)
            : null;
      },
    );
  }
}

class GroqServiceException implements Exception {
  GroqServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
