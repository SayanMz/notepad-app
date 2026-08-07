import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:notepad/core/database/app_data.dart';
import 'package:notepad/features/note/services/document_delta_parser.dart'
    as doc_delta;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Handles HTML generation and file sharing for formatted note content.
class NoteHtmlExporter {
  /// Builds a complete, standalone HTML5 document string from note title and rich text delta maps.
  /// Includes full `<head>` meta tags, custom inline CSS typography, responsive layouts, and structural HTML wrappers.
  static String buildHtmlDocument({
    required String title,
    required List<Map<String, dynamic>> richContent,
  }) {
    // Parse raw Delta JSON structures into structured line blocks
    final lines = doc_delta.parseDocumentDelta(richContent);
    final buffer = StringBuffer()
      ..writeln('<!DOCTYPE html><html><head><meta charset="utf-8">')
      ..writeln(
        '<title>${_escapeHtml(title.trim().isEmpty ? 'Untitled note' : title.trim())}</title>',
      )
      // Inject cross-platform system font fallbacks and default container spacing
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
      // Render body contents from parsed line structures
      ..write(_buildHtmlBody(lines))
      ..writeln('</body></html>');

    return buffer.toString();
  }

  /// Exports the note as an `.html` file directly to the user's local file system
  /// using the platform file picker dialog.
  static Future<String?> saveNoteAsHtml({
    required String title,
    required List<Map<String, dynamic>> richContent,
  }) {
    // Encode generated HTML string into standard UTF-8 byte streams
    final bytes = Uint8List.fromList(
      utf8.encode(buildHtmlDocument(title: title, richContent: richContent)),
    );

    // Invoke native file picker save dialog with predefined extensions
    return FilePicker.saveFile(
      dialogTitle: 'Save note as HTML',
      fileName: '${doc_delta.safeFileTitle(title)}.html',
      type: FileType.custom,
      allowedExtensions: const ['html', 'htm'],
      bytes: bytes,
    );
  }

  /// Saves a single HTML document to a temporary file location and invokes
  /// the native system share sheet (iOS/Android/Desktop).
  static Future<ShareResult> shareNoteAsHtml({
    required String title,
    required String htmlContent,
  }) async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeTitle = doc_delta.safeFileTitle(title);

    // Create unique temporary file path to prevent collision during concurrent shares
    final file = File('${directory.path}/${safeTitle}_$timestamp.html');

    // Force flush to hardware storage before passing file descriptor to native share sheet
    await file.writeAsString(htmlContent, flush: true);

    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'Sharing: $title',
        text: 'Check out this note!',
      ),
    );
  }

  /// Bulk-exports and shares multiple selected database notes as individual `.html` files in a single intent.
  static Future<ShareResult> shareNotesAsHTML(
    Iterable<NotesSection> notes, {
    String? text,
  }) async {
    final files = <XFile>[];

    for (final note in notes) {
      // Decode raw JSON string/object rich content into standard Map representations
      final richContent = doc_delta
          .decodeRichContent(note.richContent, note.content)
          .cast<Map<String, dynamic>>();

      final file = await _createHtmlShareFile(
        fileNameBase: doc_delta.safeFileTitle(note.title),
        title: note.title,
        richContent: richContent,
      );
      files.add(XFile(file.path));
    }

    return SharePlus.instance.share(
      ShareParams(files: files, text: text, subject: 'Shared Notes'),
    );
  }

  /// Creates a localized isolate folder on disk containing an HTML export file.
  static Future<File> _createHtmlShareFile({
    required String fileNameBase,
    required String title,
    required List<Map<String, dynamic>> richContent,
  }) async {
    final baseDir = await _shareDirectory();

    // Use microsecond precision folders to guarantee unique file namespace isolation
    final uniqueDir = await Directory(
      '${baseDir.path}/${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);

    final file = File('${uniqueDir.path}/$fileNameBase.html');

    await file.writeAsString(
      buildHtmlDocument(title: title, richContent: richContent),
      flush: true,
    );

    return file;
  }

  /// Resolves platform-specific temporary storage locations for cross-platform sharing capabilities.
  static Future<Directory> _shareDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) return getTemporaryDirectory();
    // Desktop OS platforms require application-prefixed temp folders
    return Directory.systemTemp.createTemp('notepad_share_');
  }

  /// Converts a sequence of document delta lines into semantic HTML blocks (paragraphs, lists, blockquotes).
  /// Manages state transitions for nested/ordered/unordered list tree construction.
  static String _buildHtmlBody(List<doc_delta.DocumentDeltaLine> lines) {
    final buffer = StringBuffer();
    var currentListType = '';

    // Closes parent list containers when transitioning out of a list structure
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

      // Handle opening tag insertion when transitioning into new list modes
      if (listType != currentListType) {
        closeListIfNeeded();
        if (isBullet) {
          buffer.writeln('<ul>');
        } else if (isChecked || isUnchecked) {
          buffer.writeln(
            '<ul style="list-style-type: none;">',
          ); // Hide bullets for checklist items
        } else if (isOrdered) {
          buffer.writeln('<ol>');
        }
        currentListType = listType ?? '';
      }

      // Format inline character segments into normalized text runs
      final normalizedRuns = doc_delta.normalizeRunsForListLine(
        line.runs,
        isBullet: isBullet || isChecked || isUnchecked,
        isOrdered: isOrdered,
      );

      // Render line contents or fallback to non-breaking space for empty lines
      final htmlLine = normalizedRuns.isEmpty
          ? '&nbsp;'
          : normalizedRuns.map(_htmlSpan).join();

      if (isList) {
        // Render checkbox state prefixes for interactive list formats
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
    // Ensure terminal closing tags are written for lists ending at document boundary
    closeListIfNeeded();
    return buffer.toString();
  }

  /// Maps internal Delta block-level attributes to corresponding HTML structural tags.
  static String _htmlBlockTag(Map<String, dynamic> blockAttributes) {
    if (blockAttributes.containsKey('blockquote')) return 'blockquote';
    if (blockAttributes.containsKey('code-block')) return 'pre';

    final header = blockAttributes['header'];
    switch (header) {
      case 1:
        return 'h2'; // Level 1 header maps to H2 (H1 reserved for document title)
      case 2:
        return 'h3';
      case 3:
        return 'h4';
      default:
        return 'p'; // Default standard block tag
    }
  }

  /// Generates inline CSS style attributes for block elements based on delta formatting properties.
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

  /// Converts inline text runs into escaped HTML elements wrapped with styling tags (`<strong>`, `<em>`, `<span>`, `<a>`).
  static String _htmlSpan(doc_delta.DocumentInlineRun run) {
    final attributes = run.attributes;
    // Sanitize raw plain text string before adding HTML markups
    var text = _escapeHtml(run.text).replaceAll('\n', '<br>');
    final styles = <String>[];
    final link = attributes['link'] as String?;

    // Apply semantic text formatting elements
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

    // Apply custom font colors (suppressed if run is styled as a hyperlink)
    if (attributes['color'] != null && link == null) {
      styles.add('color: ${attributes['color']};');
    }

    // Wrap with CSS style attributes if non-semantic styling exists
    if (styles.isNotEmpty) {
      text = '<span style="${styles.join(' ')}">$text</span>';
    }

    // Wrap with anchor tag if run is a valid hyperlink
    if (link != null && link.isNotEmpty) {
      final finalLink = _normalizeLink(link);
      if (finalLink != null) {
        text = '<a href="${_escapeHtml(finalLink)}" target="_blank">$text</a>';
      }
    }

    return text;
  }

  /// Normalizes user-entered URL links by ensuring proper `http://` or `https://` schemes.
  static String? _normalizeLink(String link) {
    final trimmed = link.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.toLowerCase().startsWith('http://') ||
        trimmed.toLowerCase().startsWith('https://')) {
      return trimmed;
    }

    return 'https://$trimmed';
  }

  /// Escapes dangerous HTML entity characters to prevent XSS vulnerability vectors during file parsing.
  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
