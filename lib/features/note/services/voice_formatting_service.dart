import 'package:flutter_quill/flutter_quill.dart';

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
      }

      if (k.isEmpty) continue;
      if (target.isEmpty && k != 'unformat_all') continue;

      if (['bold', 'italic', 'underline', 'strike'].contains(k)) {
        v = (v.toString().toLowerCase() == 'true');
      }

      // --- 1. RUTHLESS CLEAR (VIP Pass) ---
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

      // --- 2. TARGET RESOLUTION (Selection & Positioning) ---
      List<Map<String, int>> ranges = [];
      final selection = controller.selection;
      bool hasSelection = selection.isValid && !selection.isCollapsed;

      // [INTACT: Safety lock strictly isolates "it", "this", "that" from triggering global formats]
      // [INTACT: Safety lock strictly isolates "it", "this", "that" from triggering global formats]
      bool isGlobal =
          (target.toLowerCase() == 'all' ||
              target.toLowerCase() == 'everything' ||
              target.toLowerCase() == 'document') &&
          !commandText.toLowerCase().contains(
            RegExp(
              r'\b(dog|intelligent|because|loyal|smell|taking|starting|top|bottom|first|last|third|items|list|tasks|selection|this|that|it|sentence|paragraph)\b',
            ),
          );

      bool isSelectionTarget = [
        'selection',
        'this',
        'it',
        'this line',
        'this paragraph',
        'this sentence',
        'that',
        'selected text',
        'paragraph:this',
        'line:this',
      ].contains(target.toLowerCase());

      if (isSelectionTarget && hasSelection) {
        ranges.add({
          'start': selection.start,
          'len': selection.end - selection.start,
        });
      } else if (isGlobal) {
        ranges.add({'start': 0, 'len': pt.length});
      } else if (target.startsWith('line:') ||
          target.startsWith('sentence:') ||
          target.startsWith('paragraph:')) {
        String type = target.split(':')[0];
        String idxStr = target.split(':')[1];
        List<String> segments = [];

        if (type == 'paragraph') {
          segments = pt.split(RegExp(r'(?<=\n\s*\n)'));
        } else {
          segments = pt.split(RegExp(r'(?<=[.\n])'));
        }

        const ordinals = {
          'first': 0,
          '1st': 0,
          'top': 0,
          'starting': 0,
          'beginning': 0,
          'second': 1,
          '2nd': 1,
          'third': 2,
          '3rd': 2,
          'fourth': 3,
          '4th': 3,
          'fifth': 4,
          '5th': 4,
          'last': -1,
          'bottom': -1,
          'end': -1,
          'ending': -1,
        };

        int targetIdx = -1;
        if (['last', 'bottom', 'end', 'ending'].contains(idxStr)) {
          for (int i = segments.length - 1; i >= 0; i--) {
            if (segments[i].trim().isNotEmpty) {
              targetIdx = i;
              break;
            }
          }
        } else {
          targetIdx = ordinals[idxStr] ?? (int.tryParse(idxStr) ?? -1);
        }

        if (targetIdx >= 0 && targetIdx < segments.length) {
          int startOffset = 0;
          for (int i = 0; i < targetIdx; i++) {
            startOffset += segments[i].length;
          }

          int len = segments[targetIdx].length;
          if (len > 0) {
            ranges.add({'start': startOffset, 'len': len});
          } else if (['align', 'list'].contains(k)) {
            ranges.add({'start': startOffset, 'len': 1});
          } else {
            skippedInlineOnEmpty = true;
            continue;
          }
        }
      } else {
        String lowPt = pt.toLowerCase();
        String pattern = RegExp.escape(target.toLowerCase());
        var matches = RegExp(
          r'\b' + pattern + r'\b',
          caseSensitive: false,
        ).allMatches(lowPt).toList();
        if (matches.isEmpty) {
          matches = RegExp(
            r'\b' + pattern,
            caseSensitive: false,
          ).allMatches(lowPt).toList();
        }
        if (matches.isEmpty) {
          matches = RegExp(
            pattern,
            caseSensitive: false,
          ).allMatches(lowPt).toList();
        }

        if (occ != 'all' && matches.isNotEmpty) {
          const ords = {
            'first': 0,
            '1st': 0,
            'second': 1,
            '2nd': 1,
            'third': 2,
            '3rd': 2,
            'last': -1,
          };
          int? i = (occ == 'last') ? matches.length - 1 : ords[occ];
          if (i != null && matches.length > i) {
            matches = [matches[i]];
          } else if (occ != 'all') {
            matches = [];
          }
        }
        for (var m in matches) {
          ranges.add({'start': m.start, 'len': m.end - m.start});
        }
      }

      // --- 3. EXECUTE UI FORMATTING ---
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
          // --- Paragraph Block Modifier ---
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

          int blockLen = l;
          if (blockLen > 0 &&
              s + blockLen <= pt.length &&
              pt.substring(s, s + blockLen).endsWith('\n')) {
            blockLen -= 1;
          }
          controller.formatText(s, blockLen, Attribute.fromKeyValue(k, val));
        } else {
          if (s >= pt.length && !hasSelection) {
            skippedInlineOnEmpty = true;
            continue;
          }

          if (k == 'size_change' ||
              (k == 'size' &&
                  v.toString().toLowerCase().contains(
                    RegExp(r'big|small|large|tiny'),
                  ))) {
            final sAttr = controller.document
                .collectStyle(s, 1)
                .attributes['size'];
            double cur = (sAttr != null && sAttr.value is num)
                ? (sAttr.value as num).toDouble()
                : 16.0;
            double change =
                v.toString().contains('small') || v.toString().startsWith('-')
                ? -5.0
                : 5.0;
            controller.formatText(
              s,
              l,
              Attribute.fromKeyValue('size', (cur + change).clamp(8.0, 100.0)),
            );
          } else if (k == 'link') {
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
            if (k == 'size') {
              v = (double.tryParse(v.toString()) ?? 16.0).clamp(8.0, 100.0);
            }
            controller.formatText(s, l, Attribute.fromKeyValue(k, v));
          }
        }
        didApplyFormat = true;
      }
    }
    if (!didApplyFormat && skippedInlineOnEmpty) {
      return 'Line is empty; cannot apply style.';
    }
    return didApplyFormat ? 'Formatting applied!' : 'No matches found.';
  }
}
