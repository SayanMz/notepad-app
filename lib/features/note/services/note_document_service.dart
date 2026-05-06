import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import 'package:notepad/core/data/app_data.dart';

/// Handles converting notes to PDF/HTML, sharing, and file exports.
class NoteDocumentService {
  // ----- PDF Generation Logic (Synchronous Rendering Chain) -----

  /// Entry point for PDF generation.
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

    final lines = _parseDelta(richContent);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // FIX: Added Container with center alignment
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

          /// Spread operator now works because rendering is synchronous
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
    debugPrint('📄 PDF Rendering Time: ${stopwatch.elapsedMilliseconds}ms');

    return pdf;
  }

  static List<pw.Widget> _buildPdfBlocks(
    List<_DeltaLine> lines,
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
    _DeltaLine line,
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

    final normalizedRuns = _normalizeRunsForListLine(
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
            fontFallback: emojiFont != null
                ? [emojiFont]
                : const [], // Added fallback
          ),
        ),
      if (isChecked || isUnchecked)
        pw.TextSpan(
          text: isChecked ? '[x] ' : '[ ] ',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: fontSize,
            fontFallback: emojiFont != null
                ? [emojiFont]
                : const [], // Added fallback
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
          // FIX: Provide the fallback to the root span!
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
    _InlineRun run,
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
      ),
      annotation: link == null ? null : pw.AnnotationUrl(link),
    );
  }

  // ----- Async Entry Points (Font Loading & User Actions) -----

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

    return FilePicker.platform.saveFile(
      dialogTitle: 'Save note as PDF',
      fileName: '${safeFileTitle(title)}.pdf',
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
      fileNameBase: safeFileTitle(title),
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
        text: 'Check out my note!',
        subject: title.trim().isEmpty ? 'Shared note' : title.trim(),
      ),
    );
  }

  /// Bulk exports and shares multiple notes as separate attachments.
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
        fileNameBase: safeFileTitle(note.title),
        title: note.title,
        richContent: decodeRichContent(note.richContent, note.content),
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

  /// Bulk exports and shares multiple notes as HTML.
  static Future<ShareResult> shareNotesAsHTML(
    Iterable<NotesSection> notes, {
    String? text,
  }) async {
    final files = <XFile>[];

    for (final note in notes) {
      final file = await _createHtmlShareFile(
        fileNameBase: safeFileTitle(note.title),
        title: note.title,
        richContent: decodeRichContent(note.richContent, note.content),
      );
      files.add(XFile(file.path));
    }

    return SharePlus.instance.share(
      ShareParams(files: files, text: text, subject: 'Shared Notes'),
    );
  }

  static Future<void> shareNoteAsHtml({
    required String title,
    required String htmlContent,
  }) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final file = File(
      '${directory.path}/${title.replaceAll(' ', '_')}_$timestamp.html',
    );

    await file.writeAsString(htmlContent, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Sharing: $title',
        text: 'Check out this note!',
      ),
    );
  }

  static Future<File> _createHtmlShareFile({
    required String fileNameBase,
    required String title,
    required List<dynamic> richContent,
  }) async {
    final directory = await _shareDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${fileNameBase}_$timestamp.html');

    await file.writeAsString(
      buildHtmlDocument(title: title, richContent: richContent),
      flush: true,
    );

    return file;
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
    final directory = await _shareDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${fileNameBase}_$timestamp.pdf');

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

  // ----- HTML Generation Logic -----

  static String buildHtmlDocument({
    required String title,
    required List<dynamic> richContent,
  }) {
    final lines = _parseDelta(richContent);
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln(
        '<title>${_escapeHtml(title.trim().isEmpty ? 'Untitled note' : title.trim())}</title>',
      )
      ..writeln(
        '<style>body { font-family: Segoe UI, Arial, sans-serif; padding: 32px; line-height: 1.5; }',
      )
      ..writeln(
        'h1 { margin-bottom: 24px; text-align: center; } p { margin: 0 0 10px; } ul, ol { margin: 0 0 10px 24px; }',
      )
      ..writeln(
        'a { color: #1565c0 !important; text-decoration: underline !important; }</style>',
      )
      ..writeln('</head><body>')
      ..writeln(
        '<h1 style="text-align: center;">${_escapeHtml(title.trim().isEmpty ? 'Untitled note' : title.trim())}</h1>',
      )
      ..write(_buildHtmlBody(lines))
      ..writeln('</body></html>');

    return buffer.toString();
  }

  static String _buildHtmlBody(List<_DeltaLine> lines) {
    final buffer = StringBuffer();
    var currentListType = '';

    void closeListIfNeeded() {
      if (currentListType == 'bullet') {
        buffer.writeln('</ul>');
      } else if (currentListType == 'ordered') {
        buffer.writeln('</ol>');
      }
      currentListType = '';
    }

    for (final line in lines) {
      final listType = line.blockAttributes['list'] as String?;
      if (listType != currentListType) {
        closeListIfNeeded();
        if (listType == 'bullet') {
          buffer.writeln('<ul>');
        } else if (listType == 'ordered') {
          buffer.writeln('<ol>');
        }
        currentListType = listType ?? '';
      }

      final htmlLine = line.runs.isEmpty
          ? '&nbsp;'
          : line.runs.map(_htmlSpan).join();

      if (listType == 'bullet' || listType == 'ordered') {
        buffer.writeln('<li>$htmlLine</li>');
      } else {
        closeListIfNeeded();
        final tag = _htmlBlockTag(line.blockAttributes);
        final style = _htmlBlockStyle(line.blockAttributes);
        buffer.writeln('<$tag$style>$htmlLine</$tag>');
      }
    }
    closeListIfNeeded();
    return buffer.toString();
  }

  static Future<String?> saveNoteAsHtml({
    required String title,
    required List<dynamic> richContent,
  }) {
    final bytes = Uint8List.fromList(
      utf8.encode(buildHtmlDocument(title: title, richContent: richContent)),
    );
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save note as HTML',
      fileName: '${safeFileTitle(title)}.html',
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
      bytes: bytes,
    );
  }

  static String _htmlBlockTag(Map<String, dynamic> blockAttributes) {
    if (blockAttributes.containsKey('blockquote')) return 'blockquote';
    if (blockAttributes.containsKey('code-block')) return 'pre';

    final header = blockAttributes['header'];
    switch (header) {
      case 1:
        return 'h2';
      case 2:
        return 'h3';
      case 3:
        return 'h4';
      default:
        return 'p';
    }
  }

  static String _htmlBlockStyle(Map<String, dynamic> blockAttributes) {
    final styles = <String>[];
    final align = blockAttributes['align'] as String?;

    if (align != null) styles.add('text-align: $align;');
    if (blockAttributes.containsKey('code-block')) {
      styles.add(
        'background: #f4f4f4; padding: 10px; border-radius: 4px; font-family: monospace;',
      );
    }

    return styles.isEmpty ? '' : ' style="${styles.join(' ')}"';
  }

  static String _htmlSpan(_InlineRun run) {
    final attributes = run.attributes;
    var text = _escapeHtml(run.text).replaceAll('\n', '<br>');
    final styles = <String>[];
    final link = attributes['link'] as String?;

    if (attributes['bold'] == true) text = '<strong>$text</strong>';
    if (attributes['italic'] == true) text = '<em>$text</em>';
    if (attributes['underline'] == true) {
      styles.add('text-decoration: underline;');
    }
    if (attributes['strike'] == true) {
      styles.add('text-decoration: line-through;');
    }
    if (attributes['size'] != null) {
      styles.add('font-size: ${attributes['size']}px;');
    }
    if (attributes['background'] != null) {
      styles.add('background-color: ${attributes['background']};');
    }

    if (attributes['color'] != null && link == null) {
      styles.add('color: ${attributes['color']};');
    }

    if (styles.isNotEmpty) {
      text = '<span style="${styles.join(' ')}">$text</span>';
    }

    // FIX: Ensure the link has a protocol so the browser treats it as a website, not a local file.
    if (link != null && link.isNotEmpty) {
      String finalLink = link.trim();

      // If it doesn't start with http:// or https://, inject https://
      if (!finalLink.toLowerCase().startsWith('http://') &&
          !finalLink.toLowerCase().startsWith('https://')) {
        finalLink = 'https://$finalLink';
      }

      text = '<a href="${_escapeHtml(finalLink)}" target="_blank">$text</a>';
    }

    return text;
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // ----- Utility Methods -----

  static List<_DeltaLine> _parseDelta(List<dynamic> delta) {
    final lines = <_DeltaLine>[];
    final runs = <_InlineRun>[];

    void pushLine([Map<String, dynamic>? blockAttributes]) {
      lines.add(
        _DeltaLine(
          runs: List<_InlineRun>.from(runs),
          blockAttributes: Map<String, dynamic>.from(
            blockAttributes ?? const {},
          ),
        ),
      );
      runs.clear();
    }

    for (final rawOperation in delta) {
      if (rawOperation is! Map) continue;
      final insert = rawOperation['insert'];
      final attributes = Map<String, dynamic>.from(
        rawOperation['attributes'] as Map? ?? const {},
      );

      if (insert is String) {
        final parts = insert.split('\n');
        for (var index = 0; index < parts.length; index++) {
          final part = parts[index];
          if (part.isNotEmpty) {
            runs.add(_InlineRun(text: part, attributes: attributes));
          }
          if (index < parts.length - 1) {
            pushLine(_blockAttributes(attributes));
          }
        }
      } else if (insert is Map) {
        runs.add(
          _InlineRun(
            text: insert.keys.first == 'image'
                ? '[Image]'
                : '[Embedded content]',
            attributes: attributes,
          ),
        );
      }
    }
    if (runs.isNotEmpty || lines.isEmpty) pushLine();
    return lines;
  }

  static Map<String, dynamic> _blockAttributes(
    Map<String, dynamic> attributes,
  ) {
    const blockKeys = {'align', 'list', 'header', 'blockquote', 'code-block'};
    return Map<String, dynamic>.fromEntries(
      attributes.entries.where((entry) => blockKeys.contains(entry.key)),
    );
  }

  static String safeFileTitle(String title) {
    final safe = title.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '');
    return safe.isEmpty ? 'Note' : safe;
  }

  static List<dynamic> decodeRichContent(
    String richContent,
    String fallbackText,
  ) {
    if (richContent.trim().isEmpty) {
      return [
        {'insert': fallbackText},
        {'insert': '\n'},
      ];
    }
    try {
      final decoded = jsonDecode(richContent);
      if (decoded is List) return decoded;
    } catch (e) {
      debugPrint("JSON Error: $e");
    }
    return [
      {'insert': fallbackText},
      {'insert': '\n'},
    ];
  }

  static Future<Directory> _shareDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) return getTemporaryDirectory();
    return Directory.systemTemp.createTemp('notepad_share_');
  }

  static List<_InlineRun> _normalizeRunsForListLine(
    List<_InlineRun> runs, {
    required bool isBullet,
    required bool isOrdered,
  }) {
    if ((!isBullet && !isOrdered) || runs.isEmpty) return runs;
    final normalizedRuns = List<_InlineRun>.from(runs);
    final firstRun = normalizedRuns.first;
    final strippedText = firstRun.text.replaceFirst(
      isOrdered ? RegExp(r'^\s*\d+[.)]\s+') : RegExp(r'^\s*([-*•])\s+'),
      '',
    );
    if (strippedText == firstRun.text) return normalizedRuns;
    normalizedRuns[0] = _InlineRun(
      text: strippedText,
      attributes: firstRun.attributes,
    );
    return normalizedRuns;
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

class _DeltaLine {
  const _DeltaLine({required this.runs, required this.blockAttributes});
  final List<_InlineRun> runs;
  final Map<String, dynamic> blockAttributes;
}

class _InlineRun {
  const _InlineRun({required this.text, required this.attributes});
  final String text;
  final Map<String, dynamic> attributes;
}
