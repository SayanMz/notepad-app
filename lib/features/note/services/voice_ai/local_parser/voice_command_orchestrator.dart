import 'dart:async';
import 'package:flutter/material.dart';
import '../groq_service.dart';
import 'base_voice_parser.dart';
import 'local_voice_parser.dart';

/// Central control center that manages the fallback cascade between local regex parsing and cloud AI processing.
class VoiceCommandOrchestrator {
  final BaseVoiceParser localParser;
  final BaseVoiceParser remoteParser;

  VoiceCommandOrchestrator({
    BaseVoiceParser? localParser,
    BaseVoiceParser? remoteParser,
  }) : localParser = localParser ?? LocalVoiceParser(),
       remoteParser = remoteParser ?? GroqService();

  /// Routes the voice text through the parsing pipeline.
  /// First attempts local, deterministic parsing for ~1ms latency.
  /// If local fails (or target extraction is too complex), falls back to the remote AI parser.
  Future<List<Map<String, dynamic>>?> routeCommand(
    String voiceText, [
    String currentEditorText = '',
  ]) async {
    final cleanText = voiceText.trim();
    if (cleanText.isEmpty) return null;

    try {
      // 1. Tries Local Parser
      final localInstructions = await localParser.parse(
        cleanText,
        currentEditorText,
      );

      // We only consider the local parse successful if it definitively extracted a target
      if (localInstructions != null && localInstructions.isNotEmpty) {
        final instruction = localInstructions.first;
        if (instruction.target.isNotEmpty) {
          debugPrint(
            'VoiceCommandOrchestrator: [Match Success] Local parser hit.',
          );
          return localInstructions.map((i) => i.toMap()).toList();
        }
      }

      // 2. [No Match/Empty] -> Forward to Groq
      debugPrint(
        'VoiceCommandOrchestrator: [No Match] Falling back to cloud parsing.',
      );
      final remoteInstructions = await remoteParser.parse(
        cleanText,
        currentEditorText,
      );

      if (remoteInstructions != null) {
        return remoteInstructions.map((i) => i.toMap()).toList();
      }

      return null;
    } on GroqServiceException catch (_) {
      // 3. [Offline / Connectivity Failure] Safe UI Fallback
      rethrow;
    } catch (e) {
      debugPrint('VoiceCommandOrchestrator: Unexpected routing error: $e');
      return null;
    }
  }
}
