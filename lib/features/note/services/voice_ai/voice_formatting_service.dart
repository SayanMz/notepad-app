// Voice formatting service applies parsed AI instructions to Quill document ranges.
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_target_resolver.dart';

/// Core service responsible for taking parsed AI voice instructions and applying
/// the corresponding rich-text formatting directly to a [QuillController].
class VoiceFormattingService {
  /// Main entry point. Iterates through a list of raw formatting [instructions],
  /// normalizes them, resolves the exact text ranges they apply to, and executes
  /// the formatting changes on the [controller].
  static String applyInstructions({
    required List<Map<String, dynamic>> instructions,
    required QuillController controller,
    required String commandText,
  }) {
    bool didApplyFormat = false;
    bool skippedInlineOnEmpty = false;
    // Extract the raw text from the document to search for target phrases
    final pt = controller.document.toPlainText();

    for (var inst in instructions) {
      // 1. Clean and standardize the raw instruction map
      final normalized = _normalizeInstruction(inst);
      String k = normalized['key'];
      dynamic v = normalized['value'];
      String target = normalized['target'];
      String occ = normalized['occurrence'];

      // Skip invalid instructions (empty key) or instructions with no target
      // (unless the instruction is specifically to unformat the entire document)
      if (k.isEmpty || (target.isEmpty && k != 'unformat_all')) continue;

      // 2. Fast-path for clearing all formatting globally
      if (k == 'unformat_all') {
        _applyClearAll(controller, pt.length);
        didApplyFormat = true;
        continue;
      }

      // 3. Determine the exact start and length index of the target text
      final resolution = VoiceFormattingTargetResolver.resolve(
        controller: controller,
        plainText: pt,
        target: target,
        occurrence: occ,
        commandText: commandText,
        key: k,
      );

      // Track if we attempted to apply inline formatting to an empty space/line
      skippedInlineOnEmpty =
          skippedInlineOnEmpty || resolution.skippedInlineOnEmpty;

      // 4. Apply the formatting to all resolved ranges (iterating in reverse
      // is a standard practice in rich text to avoid index shifting issues)
      for (var range in resolution.ranges.reversed) {
        int s = range['start']!;
        int l = range['len']!;

        // Block Formatting: Surgical List Logic
        // Applies a list specifically when targeting a phrase (and not the global document).
        // The ':' check ensures we don't accidentally surgical-list a specific time or ratio.
        if (k == 'list' && !resolution.isGlobal && !target.contains(':')) {
          _applySurgicalList(
            controller: controller,
            plainText: pt,
            start: s,
            length: l,
            key: k,
            value: v,
            isSelectionTarget: resolution.isSelectionTarget,
          );
          didApplyFormat = true;

          // Block Formatting: Standard Alignment or Global Lists
        } else if (['align', 'list'].contains(k)) {
          _applyBlockFormat(
            controller: controller,
            plainText: pt,
            start: s,
            length: l,
            key: k,
            value: v,
          );
          didApplyFormat = true;

          // Inline Formatting: Bold, Italic, Color, Size, Links, etc.
        } else {
          bool applied = _applyInlineFormat(
            controller: controller,
            plainText: pt,
            start: s,
            length: l,
            key: k,
            value: v,
            hasSelection: resolution.hasSelection,
            isSelectionTarget: resolution.isSelectionTarget,
          );
          if (applied) didApplyFormat = true;

          // If formatting failed because the target was at the end of the text
          // and nothing was selected, mark it as skipped on empty.
          if (!applied && s >= pt.length && !resolution.hasSelection) {
            skippedInlineOnEmpty = true;
          }
        }
      }
    }

    // 5. Return user-friendly status feedback based on what happened
    if (!didApplyFormat && skippedInlineOnEmpty) {
      return 'Line is empty; cannot apply style.';
    }
    return didApplyFormat ? 'Formatting applied!' : 'No matches found.';
  }

  /// Cleans up raw AI JSON outputs. Maps natural language variations (e.g., "number",
  /// "bullet", "center") into strict formatting keys and values expected by Flutter Quill.
  static Map<String, dynamic> _normalizeInstruction(Map<String, dynamic> inst) {
    String k = inst['key']?.toString().toLowerCase() ?? '';
    String target = inst['target']?.toString().trim() ?? '';
    dynamic v = inst['value'];
    String occ = inst['occurrence']?.toString().toLowerCase().trim() ?? 'all';

    // Normalize List commands (Ordered / Numbered)
    if (k.contains('number') || k.contains('order') || k == 'ol') {
      k = 'list';
      v = 'ordered';

      // Normalize List commands (Checkboxes / Todo lists)
    } else if (k.contains('check')) {
      k = 'list';
      v = 'unchecked';

      // Normalize List commands (Bullet points)
    } else if (k.contains('bullet') || k == 'ul') {
      k = 'list';
      v = 'bullet';

      // Catch-all for generic "list" commands (defaults to bullet)
    } else if (k.contains('list')) {
      k = 'list';
      if (v == null || v == true || v.toString() == 'true') v = 'bullet';

      // Normalize Alignment commands (Left, Right, Center, Justify)
    } else if (k.contains('align') ||
        ['left', 'right', 'center', 'middle', 'justify'].contains(k) ||
        [
          'left',
          'right',
          'center',
          'middle',
          'justify',
        ].contains(v?.toString().toLowerCase())) {
      final combinedStr = '${k}_$v'.toLowerCase();
      k = 'align'; // Force key to 'align'

      // Route the value to the correct alignment identifier
      if (combinedStr.contains('right')) {
        v = 'right';
      } else if (combinedStr.contains('center') ||
          combinedStr.contains('middle')) {
        v = 'center';
      } else if (combinedStr.contains('justify')) {
        v = 'justify';
      } else {
        v = 'left';
      }
    }

    // Normalize basic boolean toggle styles (Bold, Italic, Underline, Strike)
    // Quill expects 'null' to remove a style, or an integer/true equivalent to apply it.
    if (['bold', 'italic', 'underline', 'strike'].contains(k)) {
      v = (v.toString().toLowerCase() == 'true') ? 1 : null;
    }

    return {'key': k, 'value': v, 'target': target, 'occurrence': occ};
  }

  /// Strips all supported rich-text formatting attributes from the entire document.
  static void _applyClearAll(QuillController controller, int length) {
    final keys = [
      'bold',
      'italic',
      'underline',
      'strike',
      'color',
      'size',
      'list',
      'align',
      'link',
    ];
    // Iterating through all known keys and setting their value to `null` clears them.
    for (var key in keys) {
      controller.formatText(0, length, Attribute.fromKeyValue(key, null));
    }
  }

  /// Intelligently applies list formatting around a specific target word/phrase.
  /// If the target phrase is a "Header" (e.g. "Shopping List:"), this logic
  /// ensures the items *below* the header become the list, not the header itself.
  static void _applySurgicalList({
    required QuillController controller,
    required String plainText,
    required int start,
    required int length,
    required String key,
    required dynamic value,
    required bool isSelectionTarget,
  }) {
    // Find the boundaries of the specific line containing the target
    int lineEnd = plainText.indexOf('\n', start);
    if (lineEnd == -1) lineEnd = plainText.length;
    String lineText = plainText.substring(start, lineEnd).trim();

    // Heuristic: Does this line look like a list title/header?
    bool isHeader =
        lineText.endsWith(':') ||
        lineText.toLowerCase().contains('list') ||
        lineText.toLowerCase().contains('items');

    // If it's a header, start formatting on the *next* line. Otherwise, start at the target.
    int startPos = isHeader ? (lineEnd + 1).clamp(0, plainText.length) : start;

    // Determine where the list should stop. If the user had text manually selected,
    // stop at the end of their selection. Otherwise, stop at the next double-newline (paragraph break).
    int endPos = isSelectionTarget
        ? (start + length).clamp(0, plainText.length)
        : plainText.indexOf('\n\n', startPos);

    if (endPos == -1) endPos = plainText.length;

    // Resolve the specific list style type from the normalized value
    dynamic val = 'bullet';
    if (value != null) {
      String vStr = value.toString().toLowerCase();
      if (vStr.contains('check')) {
        val = 'unchecked';
      } else if (vStr.contains('order') ||
          vStr.contains('number') ||
          vStr.contains('num') ||
          vStr == '1') {
        val = 'ordered';
      }
    }

    // Apply the formatting to the calculated list block
    if (startPos < endPos && startPos < plainText.length) {
      controller.formatText(
        startPos,
        endPos - startPos,
        Attribute.fromKeyValue(key, val),
      );
    } else {
      // Fallback: Just format the exact target range if block calculation fails
      controller.formatText(start, length, Attribute.fromKeyValue(key, val));
    }
  }

  /// Handles standard block-level formatting (like Text Alignment or Global Lists).
  static void _applyBlockFormat({
    required QuillController controller,
    required String plainText,
    required int start,
    required int length,
    required String key,
    required dynamic value,
  }) {
    dynamic val = value;

    // Final safety check for list types before applying
    if (key == 'list') {
      String vStr = (value ?? '').toString().toLowerCase();
      if (vStr.contains('check')) {
        val = 'unchecked';
      } else if (vStr.contains('order') || vStr.contains('number')) {
        val = 'ordered';
      } else {
        val = 'bullet';
      }
    }

    // Prevent formatting from bleeding onto trailing newline characters.
    // This stops block styles from accidentally applying to the next empty paragraph.
    int blockLen = length;
    if (blockLen > 0 &&
        start + blockLen <= plainText.length &&
        plainText.substring(start, start + blockLen).endsWith('\n')) {
      blockLen -= 1;
    }

    // In Quill, default text alignment is left. To "left align" something,
    // you actually remove the alignment attribute by setting it to null.
    if (key == 'align' && val == 'left') {
      val = null;
    }

    controller.formatText(start, blockLen, Attribute.fromKeyValue(key, val));
  }

  /// Handles inline character formatting like Bold, Colors, Links, and Text Sizes.
  static bool _applyInlineFormat({
    required QuillController controller,
    required String plainText,
    required int start,
    required int length,
    required String key,
    required dynamic value,
    required bool hasSelection,
    required bool isSelectionTarget,
  }) {
    // Failsafe: Cannot format beyond document bounds unless modifying an active cursor selection
    if (start >= plainText.length && !hasSelection) return false;

    // Relative Size Adjustment Logic (e.g. "make it bigger")
    if (key == 'size_change' ||
        (key == 'size' &&
            value.toString().toLowerCase().contains(
              RegExp(r'big|small|large|tiny'),
            ))) {
      // Read the current text size at the cursor/target
      final currentStyle = controller.document.collectStyle(start, 1);
      final sAttr = currentStyle.attributes['size'];

      double cur = (sAttr != null && sAttr.value is num)
          ? (sAttr.value as num).toDouble()
          : 16.0; // Default fallback size

      // Increment or decrement by 5.0 points based on the voice command
      double change =
          value.toString().contains('small') || value.toString().startsWith('-')
          ? -5.0
          : 5.0;

      // Ensure the text size doesn't become invisibly small or massively huge
      value = (cur + change).clamp(8.0, 100.0);
      key = 'size';

      // Absolute Size Adjustment Logic (e.g. "make text size 24")
    } else if (key == 'size') {
      // Strip out words to find the raw integer/double requested
      final cleanNumberStr = value.toString().replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      value = (double.tryParse(cleanNumberStr) ?? 16.0).clamp(8.0, 100.0);
    }

    // Apply directly to the user's active manual selection
    if (hasSelection && isSelectionTarget) {
      controller.formatSelection(Attribute.fromKeyValue(key, value));
    } else {
      // Hyperlink Injection Logic
      if (key == 'link') {
        String finalUrl = value.toString().trim();
        // Ensure URLs are properly protocol-prefixed for clickability
        if (!finalUrl.toLowerCase().startsWith('http')) {
          finalUrl = 'https://$finalUrl';
        }

        // When applying a link via voice, automatically style it to look like a standard link
        // 1. Add the actual link data
        controller.formatText(
          start,
          length,
          Attribute.fromKeyValue('link', finalUrl),
        );
        // 2. Turn the text blue
        controller.formatText(
          start,
          length,
          Attribute.fromKeyValue('color', '#1E88E5'),
        );
        // 3. Underline the text
        controller.formatText(start, length, Attribute.underline);

        // Standard Inline Formatting (Bold, Italic, Color, etc.)
      } else {
        int inlineLen = length;

        // Strip out trailing whitespace, newlines, or periods from the target length.
        // E.g., if targeting "Hello.", this prevents the period from becoming bold.
        while (inlineLen > 0 && start + inlineLen <= plainText.length) {
          final lastChar = plainText.substring(
            start + inlineLen - 1,
            start + inlineLen,
          );
          if (lastChar == '\n' || lastChar == '.') {
            inlineLen--;
          } else {
            break;
          }

          controller.formatText(
            start,
            length,
            Attribute.fromKeyValue(key, value),
          );
        }
      }
    }
    return true;
  }
}
