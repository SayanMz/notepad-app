import 'dart:async';

/// Core data model encapsulating a structured voice formatting instruction.
class VoiceInstruction {
  final String key;
  final dynamic value;
  final String target;
  final String occurrence;

  const VoiceInstruction({
    required this.key,
    required this.value,
    required this.target,
    required this.occurrence,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'value': value,
      'target': target,
      'occurrence': occurrence,
    };
  }

  factory VoiceInstruction.fromMap(Map<String, dynamic> map) {
    return VoiceInstruction(
      key: map['key']?.toString() ?? '',
      value: map['value'],
      target: map['target']?.toString() ?? '',
      occurrence: map['occurrence']?.toString() ?? 'all',
    );
  }
}

/// Abstract contract enforcing a unified parsing signature for both local regex engines and cloud AI services.
abstract class BaseVoiceParser {
  /// Parses raw conversational text into a list of structured [VoiceInstruction]s.
  /// Receives [voiceText] and optional [currentEditorText] to perform deterministic positional math.
  /// Returns null if the parser cannot confidently determine an instruction.
  FutureOr<List<VoiceInstruction>?> parse(
    String voiceText, [
    String currentEditorText = '',
  ]);
}
