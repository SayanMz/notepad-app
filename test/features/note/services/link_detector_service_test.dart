import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/link_handlers/link_detector_service.dart';

QuillController _controllerFor(String text) {
  return QuillController(
    document: Document()..insert(0, text),
    selection: const TextSelection.collapsed(offset: 0),
    keepStyleOnNewLine: false,
  );
}

void main() {
  test('scanAndLinkifyParagraph converts emails and websites into links', () {
    final controller = _controllerFor(
      'Reach me at test@example.com or https://example.com',
    );

    LinkDetectorService.scanAndLinkifyParagraph(controller);

    final emailStyle = controller.document.collectStyle(13, 1).attributes;
    final siteStyle = controller.document.collectStyle(34, 1).attributes;

    expect(emailStyle.containsKey(Attribute.link.key), isTrue);
    expect(emailStyle[Attribute.link.key]?.value, 'mailto:test@example.com');
    expect(siteStyle.containsKey(Attribute.link.key), isTrue);
    expect(siteStyle[Attribute.link.key]?.value, 'https://example.com');
  });

  test(
    'scanAndLinkifyParagraph converts date-like text into calendar links',
    () {
      final controller = _controllerFor('Meet on April 12, 2026 for lunch');

      LinkDetectorService.scanAndLinkifyParagraph(controller);

      final dateStyle = controller.document.collectStyle(8, 1).attributes;

      expect(dateStyle.containsKey(Attribute.link.key), isTrue);
      expect(
        dateStyle[Attribute.link.key]?.value,
        'cal:20260412|April 12, 2026',
      );
    },
  );
}
