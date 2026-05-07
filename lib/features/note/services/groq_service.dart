import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
  static bool _envLoaded = false;
  static Future<void>? _warmUpFuture;

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
    if (_envLoaded) return;

    try {
      await dotenv.load(fileName: '.env');
      _envLoaded = true;
    } on FileSystemException catch (_) {
      throw GroqServiceException(
        'AI service is not configured yet. Please check your setup and try again.',
      );
    } catch (_) {
      throw GroqServiceException(
        'AI service is temporarily unavailable. Please check your network connection and try again.',
      );
    }
  }

  static Future<List<Map<String, dynamic>>?> parseVoiceCommand(
    String voiceText,
  ) async {
    await _ensureEnvLoaded();

    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw GroqServiceException(
        'AI service is not configured. Please add your API key and try again.',
      );
    }

    const systemPrompt = """
  You are an advanced, natural language JSON formatting engine for a Flutter app.
  Translate messy, conversational human speech into this STRICT JSON schema: 
  { "instructions": [{"target": "phrase", "key": "attr", "value": val, "occurrence": "all"|"first"|"last"|"second"}] }

  CRITICAL TARGET RULES (NEVER USE "all" UNLESS EXPLICITLY TOLD "everything"):
  1. DEFINITIONS: 
     - "sentence" and "line" are IDENTICAL. ALWAYS use prefix "line:" (e.g., "line:first"). NEVER use "sentence:".
     - "paragraph" / "block" -> ALWAYS use prefix "paragraph:" (e.g., "paragraph:2nd").
  2. SELECTION: If the command contains "this", "that", "it" (e.g., "Make it green"), "this line", or "this paragraph" -> YOU MUST set target: "selection". NEVER use "all".
  3. POSITION: Map ordinals intelligently. "bottom line", "last line" , "ending line" -> "line:last".
  4. TARGET ISOLATION (CRITICAL): Extract ONLY the exact text from the document. STRIP formatting words from the target. 
     - Correct: "Make menu items a checklist" -> target: "menu items". 
     - WRONG: target: "menu items a checklist".
  5. OCCURRENCE: "second instance", "last time I said [word]" -> set occurrence to "second" or "last".
  6. CLEARING: "clear formatting", "remove styles", "start over", "nuke it" -> EXACTLY: { "instructions": [{"target": "all", "key": "unformat_all", "value": true, "occurrence": "all"}] }

  FEATURE & SYNONYM MAPPING:
  1. Styles: "bold", "italic", "underline", "strike" / "cross out" -> boolean true.
  2. Colors: "highlight in red", "make it green" -> key "color", value is a hex code.
  3. Size: "huge", "giant" -> key: "size_change", value: 5. "tiny" -> key: "size_change", value: -5. Exact size ("size 20") -> key: "size", value: numeric.
  4. Alignments: "put in the middle", "center it" -> "align": "center". "push left/right" -> "align": "left"/"right".
 5. Lists: "list" -> key: "list", value: "bullet". "checklist" / "to-do list" -> value: "unchecked". "numbered list" / "numbers" -> value: "ordered".

  NATURAL CONVERSATION EXAMPLES:
  - "Make it green" -> {"instructions": [{"target": "selection", "key": "color", "value": "#008000", "occurrence": "all"}]}
  - "Make menu items a checklist" -> {"instructions": [{"target": "menu items", "key": "list", "value": "unchecked", "occurrence": "all"}]}
  - "Make the first sentence yellow" -> {"instructions": [{"target": "line:first", "key": "color", "value": "#FFFF00", "occurrence": "all"}]}
""";

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': 'llama-3.1-8b-instant',
              'response_format': {'type': 'json_object'},
              'messages': [
                {'role': 'system', 'content': systemPrompt},
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
