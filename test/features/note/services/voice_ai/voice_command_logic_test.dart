import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';

void main() {
  group('Voice Command Logic Tests', () {
    late QuillController controller;

    setUp(() {
      controller = QuillController.basic();
    });

    void setupDocument(String text) {
      controller.document = Document()..insert(0, text);
    }

    test('1. Global Reset - "Clear all formatting"', () {
      setupDocument('Bold text and red text.');
      controller.formatText(0, 4, Attribute.bold);
      controller.formatText(9, 3, Attribute.fromKeyValue('color', '#FF0000'));

      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Clear all formatting',
        instructions: [
          {'target': 'all', 'key': 'unformat_all', 'value': true, 'occurrence': 'all'}
        ],
      );

      final styles = controller.document.collectStyle(0, controller.document.length);
      expect(styles.attributes, isEmpty, reason: 'Global reset should wipe all attributes');
    });

    test('2. Selection Interceptor - "Make this bold"', () {
      setupDocument('Select this part.');
      controller.updateSelection(const TextSelection(baseOffset: 7, extentOffset: 11), ChangeSource.local); // "this"

      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make this bold',
        instructions: [
          {'target': 'selection', 'key': 'bold', 'value': true, 'occurrence': 'all'}
        ],
      );

      expect(controller.document.collectStyle(7, 1).attributes['bold'], isNotNull);
      expect(controller.document.collectStyle(0, 1).attributes['bold'], isNull);
    });

    test('3. Global Document Lock - "Make everything red"', () {
      setupDocument('Whole document red.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make everything red',
        instructions: [
          {'target': 'all', 'key': 'color', 'value': '#FF0000', 'occurrence': 'all'}
        ],
      );

      for (int i = 0; i < 15; i++) {
        expect(controller.document.collectStyle(i, 1).attributes['color']?.value, '#FF0000');
      }
    });

    test('4. Line & Sentence Segmentation - "Make the first line bold"', () {
      setupDocument('First line.\nSecond line.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make the first line bold',
        instructions: [
          {'target': 'line:first', 'key': 'bold', 'value': true, 'occurrence': 'all'}
        ],
      );

      expect(controller.document.collectStyle(0, 5).attributes['bold'], isNotNull);
      expect(controller.document.collectStyle(12, 5).attributes['bold'], isNull);
    });

    test('5. Paragraph Segmentation - "Make the first paragraph italic"', () {
      setupDocument('Paragraph 1.\n\nParagraph 2.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make the first paragraph italic',
        instructions: [
          {'target': 'paragraph:first', 'key': 'italic', 'value': true, 'occurrence': 'all'}
        ],
      );

      expect(controller.document.collectStyle(0, 11).attributes['italic'], isNotNull);
      expect(controller.document.collectStyle(14, 11).attributes['italic'], isNull);
    });

    test('6. Literal Phrase Targeting - "Underline golden retriever"', () {
      setupDocument('I have a golden retriever at home.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Underline golden retriever',
        instructions: [
          {'target': 'golden retriever', 'key': 'underline', 'value': true, 'occurrence': 'all'}
        ],
      );

      // "golden retriever" starts at index 9
      expect(controller.document.collectStyle(9, 16).attributes['underline'], isNotNull);
      expect(controller.document.collectStyle(0, 5).attributes['underline'], isNull);
    });

    test('7. Nth Occurrence - "Make the second instance of dog bold"', () {
      setupDocument('The first dog and the second dog.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make the second instance of dog bold',
        instructions: [
          {'target': 'dog', 'key': 'bold', 'value': true, 'occurrence': 'second'}
        ],
      );

      // First dog at index 10, second dog at index 29
      expect(controller.document.collectStyle(10, 3).attributes['bold'], isNull);
      expect(controller.document.collectStyle(29, 3).attributes['bold'], isNotNull);
    });

    test('8. Surgical List Engine - "Make menu items a checklist"', () {
      setupDocument('Menu items:\nPizza\nBurger\nSoda');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make menu items a checklist',
        instructions: [
          {'target': 'menu items', 'key': 'list', 'value': 'unchecked', 'occurrence': 'all'}
        ],
      );

      // The header "Menu items:" should remain normal, items below should be checklist
      // "Pizza" starts at index 12
      expect(controller.document.collectStyle(0, 10).attributes['list'], isNull);
      expect(controller.document.collectStyle(12, 5).attributes['list']?.value, 'unchecked');
    });

    test('9. Relative Sizing - "Make the word warning look massive"', () {
      setupDocument('This is a warning.');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make the word warning look massive',
        instructions: [
          {'target': 'warning', 'key': 'size_change', 'value': 5, 'occurrence': 'all'}
        ],
      );

      // Default is 16.0, massive (+5) should be 21.0
      expect(controller.document.collectStyle(10, 7).attributes['size']?.value, 21.0);
    });

    test('10. Hyperlink Engine - "Link this to youtube.com"', () {
      setupDocument('Watch this video.');
      controller.updateSelection(const TextSelection(baseOffset: 6, extentOffset: 10), ChangeSource.local); // "this"
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Link this to youtube.com',
        instructions: [
          {'target': 'selection', 'key': 'link', 'value': 'youtube.com', 'occurrence': 'all'}
        ],
      );

      final style = controller.document.collectStyle(6, 1);
      // NOTE: Verify against CURRENT lib implementation (which doesn't prepend https to selections yet)
      expect(style.attributes['link']?.value, 'youtube.com');
    });

    test('11. Multi-Attribute Rejection - "Make the second line bold"', () {
      setupDocument('Line 1\nLine 2');
      
      VoiceFormattingService.applyInstructions(
        controller: controller,
        commandText: 'Make the second line bold',
        instructions: [
          {'target': 'line:second', 'key': 'bold', 'value': true, 'occurrence': 'all'}
        ],
      );

      final style = controller.document.collectStyle(7, 6);
      expect(style.attributes['bold'], isNotNull);
      expect(style.attributes['color'], isNull);
      expect(style.attributes['size'], isNull);
    });
  });
}
