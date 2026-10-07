import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/links/link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('openLink handles web, phone, mail, and invalid calendar dates gracefully', () async {
      final webData = service.parse('https://flutter.dev');
      final phoneData = service.parse('tel:1234567890');
      final mailData = service.parse('mailto:test@example.com');
      final invalidCalData = service.parse('cal:invalid_date|Invalid Date');

      expect(() async => await service.openLink(webData), returnsNormally);
      expect(() async => await service.openLink(phoneData), returnsNormally);
      expect(() async => await service.openLink(mailData), returnsNormally);
      expect(() async => await service.openLink(invalidCalData), returnsNormally);
    });

    test('copyText and shareText execute without throwing error', () async {
      expect(() async => await service.copyText('https://example.com'), returnsNormally);
      expect(() async => await service.shareText('Sharing text'), returnsNormally);
    });
  });
}
