import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/features/note/services/voice_ai/voice_formatting_target_resolver.dart';

class VoiceFormattingService {
  static String applyInstructions({
    required List<Map<String, dynamic>> instructions,
    required QuillController controller,
    required String commandText,
  }) {
    bool didApplyFormat = false;
    bool skippedInlineOnEmpty = false;
    final pt = controller.document.toPlainText();

    for (var inst in instructions) {
      String k = inst['key']?.toString().toLowerCase() ?? '';
      String target = inst['target']?.toString().trim() ?? '';
      dynamic v = inst['value'];
      String occ = inst['occurrence']?.toString().toLowerCase().trim() ?? 'all';

      if (k.contains('number') || k.contains('order') || k == 'ol') {
        k = 'list';
        v = 'ordered';
      } else if (k.contains('check')) {
        k = 'list';
        v = 'unchecked';
      } else if (k.contains('bullet') || k == 'ul') {
        k = 'list';
        v = 'bullet';
      } else if (k.contains('list')) {
        // 🌟 FIX: Catch "list item" or "make a list" and force it to work!
        k = 'list';
        if (v == null || v == true || v.toString() == 'true') {
          v = 'bullet';
        }
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
        k = 'align'; // Force the key to be align

        if (combinedStr.contains('right')) {
          v = 'right'; // Force the value to strictly be right
        } else if (combinedStr.contains('center') ||
            combinedStr.contains('middle')) {
          v = 'center';
        } else if (combinedStr.contains('justify')) {
          v = 'justify';
        } else {
          v = 'left'; // Default fallback
        }
      }

      if (k.isEmpty) continue;
      if (target.isEmpty && k != 'unformat_all') continue;

      if (['bold', 'italic', 'underline', 'strike'].contains(k)) {
        v = (v.toString().toLowerCase() == 'true');
      }

      // --- 1. Clear formatting first ---
      if (k == 'unformat_all') {
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
        for (var key in keys) {
          controller.formatText(
            0,
            pt.length,
            Attribute.fromKeyValue(key, null),
          );
        }
        didApplyFormat = true;
        continue;
      }
      final resolution = VoiceFormattingTargetResolver.resolve(
        controller: controller,
        plainText: pt,
        target: target,
        occurrence: occ,
        commandText: commandText,
        key: k,
      );
      final ranges = resolution.ranges;
      final isGlobal = resolution.isGlobal;
      final isSelectionTarget = resolution.isSelectionTarget;
      final hasSelection = resolution.hasSelection;
      skippedInlineOnEmpty =
          skippedInlineOnEmpty || resolution.skippedInlineOnEmpty;

      // --- 3. Execute formatting ---
      for (var range in ranges.reversed) {
        int s = range['start']!;
        int l = range['len']!;

        if (k == 'list' && !isGlobal && !target.contains(':')) {
          int lineEnd = pt.indexOf('\n', s);
          if (lineEnd == -1) lineEnd = pt.length;
          String lineText = pt.substring(s, lineEnd).trim();
          bool isHeader =
              lineText.endsWith(':') ||
              lineText.toLowerCase().contains('list') ||
              lineText.toLowerCase().contains('items');

          // unconditionally skip the line the word was found on, applying to the row of items below
          int startPos = isHeader ? (lineEnd + 1).clamp(0, pt.length) : s;
          int endPos = isSelectionTarget
              ? (s + l).clamp(0, pt.length)
              : pt.indexOf('\n\n', startPos);
          if (endPos == -1) endPos = pt.length;

          dynamic val = 'bullet';
          if (v != null) {
            String vStr = v.toString().toLowerCase();
            if (vStr.contains('check')) {
              val = 'unchecked';
            } else if (vStr.contains('order') ||
                vStr.contains('number') ||
                vStr.contains('num') ||
                vStr == '1') {
              val = 'ordered';
            }
          }

          if (startPos < endPos && startPos < pt.length) {
            controller.formatText(
              startPos,
              endPos - startPos,
              Attribute.fromKeyValue(k, val),
            );
          } else {
            controller.formatText(s, l, Attribute.fromKeyValue(k, val));
          }
        } else if (['align', 'list'].contains(k)) {
          // --- Paragraph block modifier ---
          dynamic val = v;
          if (k == 'list') {
            String vStr = (v ?? '').toString().toLowerCase();
            if (vStr.contains('check')) {
              val = 'unchecked';
            } else if (vStr.contains('order') || vStr.contains('number')) {
              val = 'ordered';
            } else {
              val = 'bullet';
            }
          }

          int startPos = s;
          int blockLen = l;

          // Strip the trailing newline character if the range contains one.
          // This keeps the block format completely isolated and stops ALL bleeding.
          if (blockLen > 0 &&
              startPos + blockLen <= pt.length &&
              pt.substring(startPos, startPos + blockLen).endsWith('\n')) {
            blockLen -= 1;
          }

          // 🌟 THE ALIGNMENT CORE FIX:
          // 1. Left alignment in Quill is applied by clearing the attribute (passing null).
          // 2. Right/Center are block attributes, which work perfectly now because blockLen
          //    targets the text inside the block boundaries precisely.
          if (k == 'align' && val == 'left') {
            val = null;
          }

          // Apply the formatting directly on the resolver's range
          controller.formatText(
            startPos,
            blockLen,
            Attribute.fromKeyValue(k, val),
          );
          // 📍 Location: voice_formatting_service.dart -> Inside applyInstructions()
        } else {
          // --- Inline block modifier (Bold, Italic, Color, Size, Links) ---
          if (s >= pt.length && !hasSelection) {
            skippedInlineOnEmpty = true;
            continue;
          }

          // 🌟 STEP 1: Process size changes using index 's' to find current size
          if (k == 'size_change' ||
              (k == 'size' &&
                  v.toString().toLowerCase().contains(
                    RegExp(r'big|small|large|tiny'),
                  ))) {
            // Query style from exactly position 's' (length 1) to avoid mixed style null values
            final currentStyle = controller.document.collectStyle(s, 1);
            final sAttr = currentStyle.attributes['size'];

            double cur = (sAttr != null && sAttr.value is num)
                ? (sAttr.value as num).toDouble()
                : 16.0;

            double change =
                v.toString().contains('small') || v.toString().startsWith('-')
                ? -5.0
                : 5.0;

            v = (cur + change).clamp(8.0, 100.0);
            k = 'size';
          } else if (k == 'size') {
            v = (double.tryParse(v.toString()) ?? 16.0).clamp(8.0, 100.0);
          }

          // 🌟 STEP 2: Apply directly to active selection or text range
          if (hasSelection && isSelectionTarget) {
            controller.formatSelection(Attribute.fromKeyValue(k, v));
          } else {
            if (k == 'link') {
              String finalUrl = v.toString().trim();
              if (!finalUrl.toLowerCase().startsWith('http')) {
                finalUrl = 'https://$finalUrl';
              }
              controller.formatText(
                s,
                l,
                Attribute.fromKeyValue('link', finalUrl),
              );
              controller.formatText(
                s,
                l,
                Attribute.fromKeyValue('color', '#1E88E5'),
              );
              controller.formatText(s, l, Attribute.underline);
            } else {
              controller.formatText(s, l, Attribute.fromKeyValue(k, v));
            }
          }
        }
        if (l > 0 || hasSelection || ['list', 'align'].contains(k)) {
          didApplyFormat = true;
        }
      }
    }

    if (!didApplyFormat && skippedInlineOnEmpty) {
      return 'Line is empty; cannot apply style.';
    }
    return didApplyFormat ? 'Formatting applied!' : 'No matches found.';
  }
}
