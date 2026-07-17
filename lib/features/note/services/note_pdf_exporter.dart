// PDF export translates note structure into a printable layout.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart'
    as doc_delta;

class NotePdfExporter {
  static pw.Document buildPdfDocument({
    required String title,
    required List<dynamic> richContent,
    required pw.Font fontReg,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontBoldItalic,
    required pw.Font? emojiFont,
  }) {
    final stopwatch = Stopwatch()..start();

    final lines = doc_delta.parseDocumentDelta(richContent);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Container(
            width: double.infinity,
            alignment: pw.Alignment.center,
            child: pw.Text(
              title.trim().isEmpty ? 'Untitled note' : title.trim(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: fontBold,
                fontFallback: emojiFont != null ? [emojiFont] : const [],
                fontSize: 24,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          ..._buildPdfBlocks(
            lines,
            fontReg,
            fontBold,
            fontItalic,
            fontBoldItalic,
            emojiFont,
          ),
        ],
      ),
    );

    stopwatch.stop();
    debugPrint('PDF Rendering Time: ${stopwatch.elapsedMilliseconds}ms');

    return pdf;
  }

  static Future<String?> saveNoteAsPdf({
    required String title,
    required List<dynamic> richContent,
  }) async {
    final fontReg = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    final fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();
    final emojiFont = await PdfGoogleFonts.notoColorEmoji();

    final bytes = Uint8List.fromList(
      await buildPdfDocument(
        title: title,
        richContent: richContent,
        fontReg: fontReg,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
        emojiFont: emojiFont,
      ).save(),
    );

    return FilePicker.saveFile(
      dialogTitle: 'Save note as PDF',
      fileName: '${doc_delta.safeFileTitle(title)}.pdf',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
  }

  static Future<ShareResult> shareSingleNoteAsPdf({
    required String title,
    required List<dynamic> richContent,
  }) async {
    final fontReg = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    final fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();
    final emojiFont = await PdfGoogleFonts.notoColorEmoji();

    final file = await _createPdfShareFile(
      fileNameBase: doc_delta.safeFileTitle(title),
      title: title,
      richContent: richContent,
      fontReg: fontReg,
      fontBold: fontBold,
      fontItalic: fontItalic,
      fontBoldItalic: fontBoldItalic,
      emojiFont: emojiFont,
    );

    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text:
            'Check out my note: $title'
            '.pdf',
        subject: title.trim().isEmpty ? 'Shared note' : 'Note: $title',
      ),
    );
  }

  static Future<ShareResult> shareNotesAsPdf(
    Iterable<NotesSection> notes, {
    String? text,
  }) async {
    final files = <XFile>[];

    final fontReg = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    final fontBoldItalic = await PdfGoogleFonts.robotoBoldItalic();
    final emojiFont = await PdfGoogleFonts.notoColorEmoji();

    for (final note in notes) {
      final file = await _createPdfShareFile(
        fileNameBase: doc_delta.safeFileTitle(note.title),
        title: note.title,
        richContent: doc_delta.decodeRichContent(
          note.richContent,
          note.content,
        ),
        fontReg: fontReg,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
        emojiFont: emojiFont,
      );
      files.add(XFile(file.path));
    }

    return SharePlus.instance.share(
      ShareParams(files: files, text: text, subject: 'Shared Notes'),
    );
  }

  static Future<File> _createPdfShareFile({
    required String fileNameBase,
    required String title,
    required List<dynamic> richContent,
    required pw.Font fontReg,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontBoldItalic,
    required pw.Font? emojiFont,
  }) async {
    final baseDir = await _shareDirectory();

    final uniqueDir = await Directory(
      '${baseDir.path}/${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    final file = File('${uniqueDir.path}/$fileNameBase.pdf');

    await file.writeAsBytes(
      await buildPdfDocument(
        title: title,
        richContent: richContent,
        fontReg: fontReg,
        fontBold: fontBold,
        fontItalic: fontItalic,
        fontBoldItalic: fontBoldItalic,
        emojiFont: emojiFont,
      ).save(),
      flush: true,
    );
    return file;
  }

  static Future<Directory> _shareDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) return getTemporaryDirectory();
    return Directory.systemTemp.createTemp('notepad_share_');
  }

  static List<pw.Widget> _buildPdfBlocks(
    List<doc_delta.DocumentDeltaLine> lines,
    pw.Font fontReg,
    pw.Font fontBold,
    pw.Font fontItalic,
    pw.Font fontBoldItalic,
    pw.Font? emojiFont,
  ) {
    final widgets = <pw.Widget>[];
    var orderedListIndex = 1;

    for (final line in lines) {
      final listType = line.blockAttributes['list'] as String?;
      if (listType != 'ordered') orderedListIndex = 1;

      widgets.add(
        _buildPdfLine(
          line,
          orderedListIndex,
          fontReg,
          fontBold,
          fontItalic,
          fontBoldItalic,
          emojiFont,
        ),
      );

      if (listType == 'ordered') orderedListIndex++;
    }
    return widgets;
  }

  static pw.Widget _buildPdfLine(
    doc_delta.DocumentDeltaLine line,
    int orderedListIndex,
    pw.Font fontReg,
    pw.Font fontBold,
    pw.Font fontItalic,
    pw.Font fontBoldItalic,
    pw.Font? emojiFont,
  ) {
    final textAlign = _pdfTextAlign(line.blockAttributes['align'] as String?);
    final fontSize = _headerFontSize(line.blockAttributes['header']);
    final isBullet = line.blockAttributes['list'] == 'bullet';
    final isOrdered = line.blockAttributes['list'] == 'ordered';
    final isBlockquote = line.blockAttributes.containsKey('blockquote');
    final isCodeBlock = line.blockAttributes.containsKey('code-block');
    final isChecked = line.blockAttributes['list'] == 'checked';
    final isUnchecked = line.blockAttributes['list'] == 'unchecked';

    final normalizedRuns = doc_delta.normalizeRunsForListLine(
      line.runs,
      isBullet: isBullet,
      isOrdered: isOrdered,
    );

    final spanChildren = normalizedRuns.isEmpty
        ? [
            pw.TextSpan(
              text: '',
              style: pw.TextStyle(font: fontReg),
            ),
          ]
        : normalizedRuns
              .map(
                (run) => _pdfTextSpan(
                  run,
                  fontSize,
                  fontReg: fontReg,
                  fontBold: fontBold,
                  fontItalic: fontItalic,
                  fontBoldItalic: fontBoldItalic,
                  emojiFont: emojiFont,
                ),
              )
              .toList();

    final textChildren = <pw.InlineSpan>[
      if (isOrdered)
        pw.TextSpan(
          text: '$orderedListIndex. ',
          style: pw.TextStyle(
            font: fontReg,
            fontSize: fontSize,
            fontFallback: emojiFont != null ? [emojiFont] : const [],
          ),
        ),
      if (isChecked || isUnchecked)
        pw.TextSpan(
          text: isChecked ? '[x] ' : '[ ] ',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: fontSize,
            fontFallback: emojiFont != null ? [emojiFont] : const [],
          ),
        ),
      ...spanChildren,
    ];

    final textBlock = pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: pw.EdgeInsets.only(
        left: (isBullet || isOrdered || isBlockquote)
            ? 12
            : (isCodeBlock ? 8 : 0),
        top: isCodeBlock ? 6 : 0,
        bottom: isCodeBlock ? 6 : 0,
        right: isCodeBlock ? 8 : 0,
      ),
      decoration: isBlockquote
          ? const pw.BoxDecoration(
              border: pw.Border(
                left: pw.BorderSide(color: PdfColors.grey400, width: 3),
              ),
            )
          : isCodeBlock
          ? const pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
            )
          : null,
      child: pw.RichText(
        text: pw.TextSpan(
          style: pw.TextStyle(
            fontFallback: emojiFont != null ? [emojiFont] : const [],
          ),
          children: textChildren,
        ),
        textAlign: textAlign,
        overflow: pw.TextOverflow.span,
      ),
    );

    if (!isBullet) return textBlock;

    return pw.Stack(
      children: [
        textBlock,
        pw.Positioned(
          left: 0,
          top: fontSize * 0.55,
          child: pw.Container(
            width: 4,
            height: 4,
            decoration: const pw.BoxDecoration(
              color: PdfColors.black,
              shape: pw.BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  static pw.TextSpan _pdfTextSpan(
    doc_delta.DocumentInlineRun run,
    double defaultFontSize, {
    required pw.Font fontReg,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontBoldItalic,
    pw.Font? emojiFont,
  }) {
    final attributes = run.attributes;
    final link = attributes['link'] as String?;
    final isLink = link != null;

    pw.Font selectedFont = fontReg;
    if (attributes['bold'] == true && attributes['italic'] == true) {
      selectedFont = fontBoldItalic;
    } else if (attributes['bold'] == true) {
      selectedFont = fontBold;
    } else if (attributes['italic'] == true) {
      selectedFont = fontItalic;
    }

    final bgColor = _pdfColor(attributes['background'] as String?);

    return pw.TextSpan(
      text: run.text,
      style: pw.TextStyle(
        font: selectedFont,
        fontFallback: emojiFont != null ? [emojiFont] : const [],
        fontSize: _fontSizeFromAttributes(attributes) ?? defaultFontSize,
        color: isLink
            ? PdfColors.blue700
            : _pdfColor(attributes['color'] as String?),
        decoration: isLink
            ? pw.TextDecoration.underline
            : _pdfDecoration(attributes),
        background: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      ),
      annotation: link == null ? null : pw.AnnotationUrl(link),
    );
  }

  static pw.TextDecoration? _pdfDecoration(Map<String, dynamic> attributes) {
    final underlined = attributes['underline'] == true;
    final struck = attributes['strike'] == true;
    if (underlined && struck) {
      return pw.TextDecoration.combine([
        pw.TextDecoration.underline,
        pw.TextDecoration.lineThrough,
      ]);
    }
    if (underlined) return pw.TextDecoration.underline;
    if (struck) return pw.TextDecoration.lineThrough;
    return null;
  }

  static pw.TextAlign _pdfTextAlign(String? align) {
    switch (align) {
      case 'center':
        return pw.TextAlign.center;
      case 'right':
        return pw.TextAlign.right;
      case 'justify':
        return pw.TextAlign.justify;
      default:
        return pw.TextAlign.left;
    }
  }

  static double _headerFontSize(Object? header) {
    switch (header) {
      case 1:
        return 28;
      case 2:
        return 24;
      case 3:
        return 20;
      default:
        return 16;
    }
  }

  static double? _fontSizeFromAttributes(Map<String, dynamic> attributes) {
    final size = attributes['size'];
    return size == null ? null : double.tryParse(size.toString());
  }

  static PdfColor? _pdfColor(String? hexColor) {
    if (hexColor == null) return null;
    final normalized = hexColor.replaceFirst('#', '');
    if (normalized.length != 6 && normalized.length != 8) return null;
    final value = int.tryParse(normalized, radix: 16);
    if (value == null) return null;
    final colorValue = normalized.length == 6 ? value | 0xFF000000 : value;
    final color = Color(colorValue);
    return PdfColor.fromInt(color.toARGB32());
  }
}
