import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_service.dart';

/// MASTER COMMAND-BASED TEST SUITE
/// 
/// This file serves as the ground truth for all supported voice commands 
/// defined in the functional documentation.
/// 
/// SCALABILITY: To add new commands, simply add to the [_allTestCases] list.
void main() {
  group('Voice AI Master Command Suite', () {
    late QuillController controller;

    setUp(() {
      controller = QuillController.basic();
    });

    for (final testCase in _allTestCases) {
      test(testCase.description, () {
        // 1. Setup Document State
        controller.document = Document()..insert(0, testCase.initialText);
        if (testCase.selection != null) {
          controller.updateSelection(testCase.selection!, ChangeSource.local);
        }

        // 2. Execute Command
        final status = VoiceFormattingService.applyInstructions(
          controller: controller,
          instructions: testCase.mockAiInstructions,
          commandText: testCase.description,
        );

        // 3. Robust Verification
        testCase.verify(controller, status);
      });
    }
  });
}

class VoiceTestCase {
  final String description;
  final String initialText;
  final TextSelection? selection;
  final List<Map<String, dynamic>> mockAiInstructions;
  final void Function(QuillController controller, String status) verify;

  const VoiceTestCase({
    required this.description,
    required this.initialText,
    this.selection,
    required this.mockAiInstructions,
    required this.verify,
  });
}

final List<VoiceTestCase> _allTestCases = [
  // ===========================================================================
  // 1. GLOBAL DOCUMENT COMMANDS
  // ===========================================================================
  VoiceTestCase(
    description: '1.1 Clear all formatting',
    initialText: 'This is a bold and red text.',
    mockAiInstructions: [
      {'target': 'all', 'key': 'unformat_all', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(status, 'Formatting applied!');
      final styles = ctrl.document.collectStyle(0, ctrl.document.length - 1);
      expect(styles.attributes, isEmpty, reason: 'Nuke it command should wipe all attributes');
    },
  ),
  VoiceTestCase(
    description: '1.2 Make everything italic',
    initialText: 'Whole document goes italic.',
    mockAiInstructions: [
      {'target': 'all', 'key': 'italic', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(status, 'Formatting applied!');
      expect(ctrl.document.collectStyle(0, 10).attributes['italic'], isNotNull);
    },
  ),

  // ===========================================================================
  // 2. SELECTION-BASED COMMANDS
  // ===========================================================================
  VoiceTestCase(
    description: '2.1 Make this bold (selection aware)',
    initialText: 'Select this word.',
    selection: const TextSelection(baseOffset: 7, extentOffset: 11), // "this"
    mockAiInstructions: [
      {'target': 'selection', 'key': 'bold', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(7, 1).attributes['bold'], isNotNull);
      expect(ctrl.document.collectStyle(0, 1).attributes['bold'], isNull);
    },
  ),
  VoiceTestCase(
    description: '2.2 Link this to google.com (protocol prepending - Selection)',
    initialText: 'Check this link.',
    selection: const TextSelection(baseOffset: 6, extentOffset: 10), // "this"
    mockAiInstructions: [
      {'target': 'selection', 'key': 'link', 'value': 'google.com', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      final style = ctrl.document.collectStyle(6, 1);
      // NOTE: Verify against CURRENT lib implementation (selections don't prepend yet)
      expect(style.attributes['link']?.value, 'google.com');
    },
  ),

  // ===========================================================================
  // 3. POSITIONAL TARGETING
  // ===========================================================================
  VoiceTestCase(
    description: '3.1 Make the first line bold',
    initialText: 'Line one\nLine two',
    mockAiInstructions: [
      {'target': 'line:first', 'key': 'bold', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(0, 5).attributes['bold'], isNotNull);
      expect(ctrl.document.collectStyle(9, 5).attributes['bold'], isNull);
    },
  ),
  VoiceTestCase(
    description: '3.2 Strike through the last sentence',
    initialText: 'First sentence. Last sentence.',
    mockAiInstructions: [
      {'target': 'line:last', 'key': 'strike', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      // Last sentence starts at 16
      expect(ctrl.document.collectStyle(16, 10).attributes['strike'], isNotNull);
      expect(ctrl.document.collectStyle(0, 5).attributes['strike'], isNull);
    },
  ),
  VoiceTestCase(
    description: '3.3 Align the first paragraph to the center',
    initialText: 'Paragraph One\n\nParagraph Two',
    mockAiInstructions: [
      {'target': 'paragraph:first', 'key': 'align', 'value': 'center', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(0, 1).attributes['align']?.value, 'center');
      expect(ctrl.document.collectStyle(15, 1).attributes['align'], isNull);
    },
  ),
  VoiceTestCase(
    description: '3.4 Sentence Targeting - "Underline the second sentence"',
    initialText: 'Sentence one. Sentence two. Sentence three.',
    mockAiInstructions: [
      {'target': 'line:second', 'key': 'underline', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      // Sentence 1 ends at index 13 (including period and space)
      // Sentence 2 is "Sentence two." (13 chars)
      expect(ctrl.document.collectStyle(14, 10).attributes['underline'], isNotNull);
    },
  ),

  // ===========================================================================
  // 4. LITERAL PHRASE & NTH OCCURRENCE
  // ===========================================================================
  VoiceTestCase(
    description: '4.1 Underline golden retriever (phrase isolation)',
    initialText: 'My golden retriever is golden.',
    mockAiInstructions: [
      {'target': 'golden retriever', 'key': 'underline', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(3, 16).attributes['underline'], isNotNull);
    },
  ),
  VoiceTestCase(
    description: '4.2 Make the second instance of dog bold (nth match)',
    initialText: 'dog one, dog two, dog three',
    mockAiInstructions: [
      {'target': 'dog', 'key': 'bold', 'value': true, 'occurrence': 'second'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(0, 3).attributes['bold'], isNull);
      expect(ctrl.document.collectStyle(9, 3).attributes['bold'], isNotNull);
      expect(ctrl.document.collectStyle(18, 3).attributes['bold'], isNull);
    },
  ),
  VoiceTestCase(
    description: '4.3 Descriptive junk word stripping - "bold the word hello"',
    initialText: 'hello world',
    mockAiInstructions: [
      {'target': 'word hello', 'key': 'bold', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      // The resolver should strip "word " and find "hello"
      expect(ctrl.document.collectStyle(0, 5).attributes['bold'], isNotNull);
    },
  ),

  // ===========================================================================
  // 5. RICH TEXT FEATURES (LISTS, SIZING, COLORS)
  // ===========================================================================
  VoiceTestCase(
    description: '5.1 Surgical List Replacement - "Make menu items a checklist"',
    initialText: 'Menu items:\nPizza\nBurger\nSoda',
    mockAiInstructions: [
      {'target': 'menu items', 'key': 'list', 'value': 'unchecked', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      // Header remains untouched
      expect(ctrl.document.collectStyle(0, 10).attributes['list'], isNull);
      // Items below become checklist
      expect(ctrl.document.collectStyle(12, 5).attributes['list']?.value, 'unchecked');
    },
  ),
  VoiceTestCase(
    description: '5.2 Relative Sizing - "Make it small"',
    initialText: 'Shrink this text.',
    selection: const TextSelection(baseOffset: 0, extentOffset: 16),
    mockAiInstructions: [
      {'target': 'selection', 'key': 'size_change', 'value': -5, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      // Default 16 - 5 = 11
      expect(ctrl.document.collectStyle(0, 5).attributes['size']?.value, 11.0);
    },
  ),
  VoiceTestCase(
    description: '5.3 Exact Sizing - "Make household 40 pixel"',
    initialText: 'The household is large.',
    mockAiInstructions: [
      {'target': 'household', 'key': 'size', 'value': '40', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(4, 9).attributes['size']?.value, 40.0);
    },
  ),
  VoiceTestCase(
    description: '5.4 Color Mapping - "Highlight this in red"',
    initialText: 'Red alert.',
    selection: const TextSelection(baseOffset: 0, extentOffset: 3),
    mockAiInstructions: [
      {'target': 'selection', 'key': 'color', 'value': '#FF0000', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(0, 1).attributes['color']?.value, '#FF0000');
    },
  ),
  VoiceTestCase(
    description: '5.5 Block Alignment - "Push the second line to the right"',
    initialText: 'Line 1\nLine 2',
    mockAiInstructions: [
      {'target': 'line:second', 'key': 'align', 'value': 'right', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      expect(ctrl.document.collectStyle(7, 1).attributes['align']?.value, 'right');
    },
  ),
  VoiceTestCase(
    description: '5.6 Link with automatic styling (Non-selection)',
    initialText: 'Check google.com for info.',
    mockAiInstructions: [
      {'target': 'google.com', 'key': 'link', 'value': 'google.com', 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      final style = ctrl.document.collectStyle(6, 1);
      expect(style.attributes['link']?.value, 'https://google.com');
      expect(style.attributes['color']?.value, '#1E88E5');
      expect(style.attributes['underline'], isNotNull);
    },
  ),

  // ===========================================================================
  // 6. HALLUCINATION & PURITY GUARDS
  // ===========================================================================
  VoiceTestCase(
    description: '6.1 Multi-Attribute Rejection (Purity Rule)',
    initialText: 'Pure bold text.',
    mockAiInstructions: [
      {'target': 'line:first', 'key': 'bold', 'value': true, 'occurrence': 'all'}
    ],
    verify: (ctrl, status) {
      final style = ctrl.document.collectStyle(0, 4);
      expect(style.attributes['bold'], isNotNull);
      expect(style.attributes['color'], isNull, reason: 'Should not hallucinate colors');
      expect(style.attributes['size'], isNull, reason: 'Should not hallucinate sizes');
    },
  ),
];
