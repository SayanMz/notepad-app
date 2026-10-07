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

  test('buildHtmlDocument renders ordered lists, checklists, subheaders, and text styles', () {
    final html = HtmlExporter.buildHtmlDocument(
      title: 'Full Style Note',
      richContent: [
        {
          'insert': 'Header 2\n',
          'attributes': {'header': 2},
        },
        {
          'insert': 'Header 3\n',
          'attributes': {'header': 3},
        },
        {
          'insert': 'Ordered step\n',
          'attributes': {'list': 'ordered'},
        },
        {
          'insert': 'Done task\n',
          'attributes': {'list': 'checked'},
        },
        {
          'insert': 'Pending task\n',
          'attributes': {'list': 'unchecked'},
        },
        {
          'insert': 'Formatted run\n',
          'attributes': {
            'bold': true,
            'italic': true,
            'underline': true,
            'strike': true,
            'color': '#123456',
            'background': '#FFEE00',
            'size': 18,
            'align': 'center',
          },
        },
      ],
    );

    expect(html, contains('<h3>Header 2</h3>'));
    expect(html, contains('<h4>Header 3</h4>'));
    expect(html, contains('<ol>'));
    expect(html, contains('[x]'));
    expect(html, contains('[ ]'));
    expect(html, contains('<em><strong>Formatted run</strong></em>'));
    expect(html, contains('font-size: 18px'));
  });
}
