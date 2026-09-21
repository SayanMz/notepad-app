import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/services/html_exporter.dart';

void main() {
  test('buildHtmlDocument wraps the note in a valid HTML shell', () {
    final html = HtmlExporter.buildHtmlDocument(
      title: 'My <Note>',
      richContent: const [
        <String, dynamic>{'insert': 'Hello world\n'},
      ],
    );

    expect(html, contains('<title>My &lt;Note&gt;</title>'));
    expect(
      html,
      contains('<h1 style="text-align: center;">My &lt;Note&gt;</h1>'),
    );
    expect(html, contains('Hello world'));
  });

  test('buildHtmlDocument falls back to Untitled note for blank titles', () {
    final html = HtmlExporter.buildHtmlDocument(
      title: '   ',
      richContent: const [
        <String, dynamic>{'insert': 'Body\n'},
      ],
    );

    expect(html, contains('<title>Untitled note</title>'));
    expect(
      html,
      contains('<h1 style="text-align: center;">Untitled note</h1>'),
    );
  });

  test(
    'buildHtmlDocument handles headers, lists, blockquotes and code blocks',
    () {
      final html = HtmlExporter.buildHtmlDocument(
        title: 'Rich Note',
        richContent: [
          {
            'insert': 'Header 1\n',
            'attributes': {'header': 1},
          },
          {
            'insert': 'Bullet item\n',
            'attributes': {'list': 'bullet'},
          },
          {
            'insert': 'Quote line\n',
            'attributes': {'blockquote': true},
          },
          {
            'insert': 'Code line\n',
            'attributes': {'code-block': true},
          },
          {
            'insert': 'Linked text\n',
            'attributes': {'link': 'example.com'},
          },
        ],
      );

      expect(html, contains('<h2>Header 1</h2>'));
      expect(html, contains('<ul>'));
      expect(html, contains('<li>Bullet item</li>'));
      expect(html, contains('<blockquote'));
      expect(html, contains('<pre'));
      expect(html, contains('<a href="https://example.com"'));
    },
  );
}
