import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart';

void main() {
  test('parseDocumentDelta captures block attributes and inline runs', () {
    final lines = parseDocumentDelta([
      {
        'insert': 'Heading\n',
        'attributes': {'header': 1},
      },
      {
        'insert': '- Bullet item\n',
        'attributes': {'list': 'bullet'},
      },
      {
        'insert': 'Plain body\n',
      },
    ]);

    expect(lines, hasLength(3));
    expect(lines[0].blockAttributes['header'], 1);
    expect(lines[1].blockAttributes['list'], 'bullet');
    expect(lines[2].runs.first.text, 'Plain body');
  });

  test('normalizeRunsForListLine strips list markers from the first run', () {
    final runs = [
      DocumentInlineRun(text: '- First item', attributes: const {}),
      DocumentInlineRun(text: ' keeps text', attributes: const {}),
    ];

    final normalized = normalizeRunsForListLine(
      runs,
      isBullet: true,
      isOrdered: false,
    );

    expect(normalized.first.text, 'First item');
    expect(normalized.last.text, ' keeps text');
  });

  test('safeFileTitle removes invalid filename characters', () {
    expect(safeFileTitle('My:Note/2026?'), 'MyNote2026');
    expect(safeFileTitle('   '), 'Note');
  });

  test('decodeRichContent falls back to plain text when needed', () {
    expect(
      decodeRichContent('', 'Fallback body'),
      [
        {'insert': 'Fallback body'},
        {'insert': '\n'},
      ],
    );
  });
}
