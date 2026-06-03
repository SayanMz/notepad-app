// Document service converts stored note content into editor-ready documents.
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart'
    as doc_delta;
import 'package:notepad/features/home/services/note_html_exporter.dart';
import 'package:notepad/features/note/services/note_pdf_exporter.dart';

// Converts stored note content into the document shapes the editor needs.
class NoteDocumentService {
  static pw.Document buildPdfDocument({
    required String title,
    required List<dynamic> richContent,
    required pw.Font fontReg,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontBoldItalic,
    required pw.Font? emojiFont,
  }) {
    return NotePdfExporter.buildPdfDocument(
      title: title,
      richContent: richContent,
      fontReg: fontReg,
      fontBold: fontBold,
      fontItalic: fontItalic,
      fontBoldItalic: fontBoldItalic,
      emojiFont: emojiFont,
    );
  }

  static Future<String?> saveNoteAsPdf({
    required String title,
    required List<dynamic> richContent,
  }) {
    return NotePdfExporter.saveNoteAsPdf(
      title: title,
      richContent: richContent,
    );
  }

  static Future<ShareResult> shareSingleNoteAsPdf({
    required String title,
    required List<dynamic> richContent,
  }) {
    return NotePdfExporter.shareSingleNoteAsPdf(
      title: title,
      richContent: richContent,
    );
  }

  static Future<ShareResult> shareNotesAsPdf(
    Iterable<NotesSection> notes, {
    String? text,
    required String title,
  }) {
    return NotePdfExporter.shareNotesAsPdf(notes, text: text);
  }

  static List<dynamic> decodeRichContent(
    String richContent,
    String fallbackText,
  ) {
    return doc_delta.decodeRichContent(richContent, fallbackText);
  }

  static String buildHtmlDocument({
    required String title,
    required List<dynamic> richContent,
  }) {
    return NoteHtmlExporter.buildHtmlDocument(
      title: title,
      richContent: richContent,
    );
  }

  static Future<String?> saveNoteAsHtml({
    required String title,
    required List<dynamic> richContent,
  }) {
    return NoteHtmlExporter.saveNoteAsHtml(
      title: title,
      richContent: richContent,
    );
  }

  static Future<ShareResult> shareNotesAsHTML(
    Iterable<NotesSection> notes, {
    String? text,
  }) {
    return NoteHtmlExporter.shareNotesAsHTML(notes, text: text);
  }

  static Future<void> shareNoteAsHtml({
    required String title,
    required String htmlContent,
  }) {
    return NoteHtmlExporter.shareNoteAsHtml(
      title: title,
      htmlContent: htmlContent,
    );
  }
}
