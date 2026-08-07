import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/note/services/note_pdf_exporter.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('buildPdfDocument produces a non-empty PDF payload', () async {
    final pdf = NotePdfExporter.buildPdfDocument(
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
}
