import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/home/services/note_html_exporter.dart';

void main() {
  test('buildHtmlDocument wraps the note in a valid HTML shell', () {
    final html = NoteHtmlExporter.buildHtmlDocument(
      title: 'My <Note>',
      richContent: const [
        <String, dynamic>{'insert': 'Hello world\n'},
      ],
    );

    expect(html, contains('<title>My &lt;Note&gt;</title>'));
    expect(html, contains('<h1 style="text-align: center;">My &lt;Note&gt;</h1>'));
    expect(html, contains('Hello world'));
  });

  test('buildHtmlDocument falls back to Untitled note for blank titles', () {
    final html = NoteHtmlExporter.buildHtmlDocument(
      title: '   ',
      richContent: const [
        <String, dynamic>{'insert': 'Body\n'},
      ],
    );

    expect(html, contains('<title>Untitled note</title>'));
    expect(html, contains('<h1 style="text-align: center;">Untitled note</h1>'));
  });
}
