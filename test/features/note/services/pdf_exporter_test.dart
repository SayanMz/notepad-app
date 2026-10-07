import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/pdf_exporter.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('buildPdfDocument produces a non-empty PDF payload', () async {
    final pdf = PdfExporter.buildPdfDocument(
      title: 'Meeting notes',
      richContent: [
        {'insert': 'Hello from PDF export\n'},
        {'insert': 'Second line\n'},
      ],
      fontReg: pw.Font.helvetica(),
      fontBold: pw.Font.helveticaBold(),
      fontItalic: pw.Font.helveticaOblique(),
      fontBoldItalic: pw.Font.helveticaBoldOblique(),
      emojiFont: null,
    );

    final bytes = await pdf.save();

    expect(bytes, isNotEmpty);
  });

  test(
    'buildPdfDocument handles lists, headers, links and formatting',
    () async {
      final pdf = PdfExporter.buildPdfDocument(
        title: 'Structured PDF',
        richContent: [
          {
            'insert': 'Heading 1\n',
            'attributes': {'header': 1},
          },
          {
            'insert': 'Checklist item\n',
            'attributes': {'list': 'checked'},
          },
          {
            'insert': 'Bold & Italic link\n',
            'attributes': {
              'bold': true,
              'italic': true,
              'link': 'https://example.com',
            },
          },
        ],
        fontReg: pw.Font.helvetica(),
        fontBold: pw.Font.helveticaBold(),
        fontItalic: pw.Font.helveticaOblique(),
        fontBoldItalic: pw.Font.helveticaBoldOblique(),
        emojiFont: null,
      );

      final bytes = await pdf.save();
      expect(bytes.length, greaterThan(100));
    },
  );

  test('buildPdfDocument handles ordered lists, blockquotes, code-blocks and text alignment', () async {
    final pdf = PdfExporter.buildPdfDocument(
      title: 'Advanced Formatting',
      richContent: [
        {
          'insert': 'First ordered item\n',
          'attributes': {'list': 'ordered'},
        },
        {
          'insert': 'Blockquote text\n',
          'attributes': {'blockquote': true},
        },
        {
          'insert': 'Code snippet\n',
          'attributes': {'code-block': true, 'align': 'center'},
        },
        {
          'insert': 'Custom styled run\n',
          'attributes': {
            'underline': true,
            'strike': true,
            'color': '#FF0000',
            'background': '#FFFF00',
            'size': '20',
          },
        },
      ],
      fontReg: pw.Font.helvetica(),
      fontBold: pw.Font.helveticaBold(),
      fontItalic: pw.Font.helveticaOblique(),
      fontBoldItalic: pw.Font.helveticaBoldOblique(),
      emojiFont: null,
    );

    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
  });
}
