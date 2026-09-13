import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/local_parser/local_voice_parser.dart';

void main() {
  final parser = LocalVoiceParser();

  // Dummy text breakdown for absolute indices:
  // 'test' -> index 10, length 4
  // 'house' -> index 35, length 5
  // 'dog' -> index 50, length 3
  const dummyText = 'This is a test document.\n\nMake the house red.\nThe dog is running.';

  group('LocalVoiceParser', () {
    // --- Original Baseline Tests ---
    test('parses global clear formatting commands instantly', () {
      final res = parser.parse('Nuke it please.', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'unformat_all');
      expect(res.first.target, 'all');
    });

    test('parses structural ordinals to precise formatting instructions', () {
      final res = parser.parse('Make the second line bold', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'bold');
      expect(res.first.value, true);
      expect(res.first.target, 'line:second');
    });

    test('parses basic color styling accurately', () {
      final res = parser.parse('Highlight the first paragraph in red', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'color');
      expect(res.first.value, '#F44336');
      expect(res.first.target, 'paragraph:first');
    });

    test('intercepts explicit selection targets', () {
      final res = parser.parse('Link this to google.com', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'link');
      expect(res.first.value, 'google.com');
      expect(res.first.target, 'selection');
    });

    test('resolves nth occurrence of a literal phrase locally if match exists', () {
      final res = parser.parse('Make the first instance of house red', dummyText);
      expect(res, isNotNull);
      expect(res!.first.target, 'literal:35:5');
    });

    test('parses scaling verbs (increase/shrink) locally for matches', () {
      final res = parser.parse('Increase the size of house', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'size_change');
      expect(res.first.value, 5.0);
      expect(res.first.target, 'literal:35:5');
    });

    test('falls back to cloud parsing for unstructured literal phrases without matches', () {
      final res = parser.parse('Make elephant red', dummyText);
      expect(res, isNotNull);
      expect(res!.first.target, isEmpty);
    });

    // --- New Asymmetric & Flexible Parsing Tests ---
    test('parses prefix-only asymmetric literal commands', () {
      final res = parser.parse('Underline test', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'underline');
      expect(res.first.target, 'literal:10:4');
    });

    test('parses suffix-only asymmetric literal commands', () {
      final res = parser.parse('house bold', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'bold');
      expect(res.first.target, 'literal:35:5');
    });

    // --- New Noise Stripping Tests ---
    test('strips extreme conversational noise before matching literal phrases', () {
      final res = parser.parse('embolden the first time I wrote dog', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'bold');
      expect(res.first.target, 'literal:50:3');
    });

    test('strips occurrence noise while preserving the occurrence math', () {
      const multiWordText = 'cat cat cat';
      // "cat" indices: 0, 4, 8
      final res = parser.parse('make the last occurrence of cat teal', multiWordText);
      expect(res, isNotNull);
      expect(res!.first.key, 'color');
      expect(res.first.value, '#009688'); // Teal
      expect(res.first.target, 'literal:8:3');
    });

    // --- New Vocabulary & Structural Tests ---
    test('resolves expanded color palette hex codes', () {
      final res = parser.parse('make the 3rd line magenta', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'color');
      expect(res.first.value, '#E040FB');
      expect(res.first.target, 'line:3rd');
    });

    test('resolves expanded list synonyms and broader ordinals', () {
      final res = parser.parse('Turn the final paragraph into an ordered list', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'list');
      expect(res.first.value, 'ordered');
      expect(res.first.target, 'paragraph:last');
    });

    test('resolves expanded selection synonyms safely', () {
      final res = parser.parse('strike through current selection', dummyText);
      expect(res, isNotNull);
      expect(res!.first.key, 'strike');
      expect(res.first.target, 'selection');
    });
  });
}