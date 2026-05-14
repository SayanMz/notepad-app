import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:notepad/core/data/app_data.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart'
    as doc_delta;

class NoteHtmlExporter {
  static String buildHtmlDocument({
    required String title,
    required List<dynamic> richContent,
  }) {
    final lines = doc_delta.parseDocumentDelta(richContent);
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln(
        '<title>${_escapeHtml(title.trim().isEmpty ? 'Untitled note' : title.trim())}</title>',
      )
      // CRITICAL UPDATE: The Universal Font Stack
      ..writeln(
        '<style>body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"; padding: 32px; line-height: 1.5; }',
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

  static Future<String?> saveNoteAsHtml({
    required String title,
    required List<dynamic> richContent,
  }) {
    final bytes = Uint8List.fromList(
      utf8.encode(buildHtmlDocument(title: title, richContent: richContent)),
    );
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save note as HTML',
      fileName: '${doc_delta.safeFileTitle(title)}.html',
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
      bytes: bytes,
    );
  }

  static Future<ShareResult> shareNoteAsHtml({
    required String title,
    required String htmlContent,
  }) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${directory.path}/${title.replaceAll(' ', '_')}_$timestamp.html',
    );

    await file.writeAsString(htmlContent, flush: true);

    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Sharing: $title',
        text: 'Check out this note!',
      ),
    );
  }

  static Future<ShareResult> shareNotesAsHTML(
    Iterable<NotesSection> notes, {
    String? text,
  }) async {
    final files = <XFile>[];

    for (final note in notes) {
      final file = await _createHtmlShareFile(
        fileNameBase: doc_delta.safeFileTitle(note.title),
        title: note.title,
        richContent: doc_delta.decodeRichContent(
          note.richContent,
          note.content,
        ),
      );
      files.add(XFile(file.path));
    }

    return SharePlus.instance.share(
      ShareParams(files: files, text: text, subject: 'Shared Notes'),
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

  static Future<Directory> _shareDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) return getTemporaryDirectory();
    return Directory.systemTemp.createTemp('notepad_share_');
  }

  static String _buildHtmlBody(List<doc_delta.DocumentDeltaLine> lines) {
    final buffer = StringBuffer();
    var currentListType = '';

    void closeListIfNeeded() {
      if (currentListType == 'bullet' ||
          currentListType == 'checked' ||
          currentListType == 'unchecked') {
        buffer.writeln('</ul>');
      } else if (currentListType == 'ordered') {
        buffer.writeln('</ol>');
      }
      currentListType = '';
    }

    for (final line in lines) {
      final listType = line.blockAttributes['list'] as String?;
      final isBullet = listType == 'bullet';
      final isOrdered = listType == 'ordered';
      final isChecked = listType == 'checked';
      final isUnchecked = listType == 'unchecked';
      final isList = isBullet || isOrdered || isChecked || isUnchecked;

      // Handle list grouping
      if (listType != currentListType) {
        closeListIfNeeded();
        if (isBullet) {
          buffer.writeln('<ul>');
        } else if (isChecked || isUnchecked) {
          // Remove default bullets for checklists to match PDF's [x] / [ ] format
          buffer.writeln('<ul style="list-style-type: none;">');
        } else if (isOrdered) {
          buffer.writeln('<ol>');
        }
        currentListType = listType ?? '';
      }

      // CRITICAL FIX: Normalize runs before rendering, exactly like PDF
      final normalizedRuns = doc_delta.normalizeRunsForListLine(
        line.runs,
        isBullet: isBullet || isChecked || isUnchecked,
        isOrdered: isOrdered,
      );

      final htmlLine = normalizedRuns.isEmpty
          ? '&nbsp;'
          : normalizedRuns.map(_htmlSpan).join();

      // Render line based on block type
      if (isList) {
        if (isChecked) {
          buffer.writeln('<li><strong>[x] </strong>$htmlLine</li>');
        } else if (isUnchecked) {
          buffer.writeln('<li><strong>[ ] </strong>$htmlLine</li>');
        } else {
          buffer.writeln('<li>$htmlLine</li>');
        }
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

  static String _htmlBlockTag(Map<String, dynamic> blockAttributes) {
    if (blockAttributes.containsKey('blockquote')) return 'blockquote';
    if (blockAttributes.containsKey('code-block')) return 'pre';

    final header = blockAttributes['header'];
    switch (header) {
      case 1:
        return 'h2'; // Matches PDF scale
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

    if (blockAttributes.containsKey('blockquote')) {
      styles.add('border-left: 3px solid #bdbdbd; padding-left: 12px;');
    }

    if (blockAttributes.containsKey('code-block')) {
      styles.add(
        'background: #f5f5f5; padding: 8px; border-radius: 4px; font-family: monospace;',
      );
    }

    return styles.isEmpty ? '' : ' style="${styles.join(' ')}"';
  }

  static String _htmlSpan(doc_delta.DocumentInlineRun run) {
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

    if (link != null && link.isNotEmpty) {
      var finalLink = link.trim();
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
}
