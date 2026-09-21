import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/ai_prompt.dart';

void main() {
  group('voiceAiSystemPrompt', () {
    test('contains required JSON schema instructions and formatting directives', () {
      expect(voiceAiSystemPrompt, contains('{ "instructions":'));
      expect(voiceAiSystemPrompt, contains('CRITICAL TARGET RULES'));
      expect(voiceAiSystemPrompt, contains('FEATURE & SYNONYM MAPPING'));
      expect(voiceAiSystemPrompt, contains('NATURAL CONVERSATION EXAMPLES'));
    });

    test('specifies sentence to line prefix mapping rule', () {
      expect(voiceAiSystemPrompt, contains('"sentence" and "line" are IDENTICAL'));
      expect(voiceAiSystemPrompt, contains('line:first'));
    });

    test('specifies selection rule for pronouns and selected text', () {
      expect(voiceAiSystemPrompt, contains('target: "selection"'));
    });
  });
}
