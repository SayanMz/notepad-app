import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/links/link_service.dart';

void main() {
  const service = NoteLinkService();

  group('NoteLinkService parsing', () {
    test('parses calendar link with date code and raw text', () {
      final data = service.parse('cal:20260412|April 12, 2026');

      expect(data.type, NoteLinkType.calendar);
      expect(data.actionCode, '20260412');
      expect(data.rawTextForCopy, 'April 12, 2026');
      expect(service.extractCleanText(data), 'April 12, 2026');
    });

    test('parses phone link', () {
      final data = service.parse('tel:1234567890');

      expect(data.type, NoteLinkType.phone);
      expect(service.extractCleanText(data), '1234567890');
    });

    test('parses mail link', () {
      final data = service.parse('mailto:test@example.com');

      expect(data.type, NoteLinkType.mail);
      expect(service.extractCleanText(data), 'test@example.com');
    });

    test('parses web link', () {
      final data = service.parse('https://example.com');

      expect(data.type, NoteLinkType.web);
      expect(service.extractCleanText(data), 'https://example.com');
    });
  });
}
