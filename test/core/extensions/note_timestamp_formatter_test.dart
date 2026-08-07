import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/core/extensions/note_timestamp_formatter.dart';

void main() {
  test('NoteDateFormatter renders date and time in a consistent format', () {
    final date = DateTime(2026, 7, 16, 14, 5);

    expect(date.format(showTime: false), 'Jul 16, 2026');
    expect(date.format(showDate: false), '2:05 PM');
    expect(date.format(), contains('Jul 16, 2026'));
    expect(date.format(), contains('2:05 PM'));
  });
}
