// Voice formatting maps parsed instructions onto Quill document ranges.
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
      final normalized = _normalizeInstruction(inst);
      String k = normalized['key'];
      dynamic v = normalized['value'];
      String target = normalized['target'];
      String occ = normalized['occurrence'];

      if (k.isEmpty || (target.isEmpty && k != 'unformat_all')) continue;

      if (k == 'unformat_all') {
        _applyClearAll(controller, pt.length);
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

      skippedInlineOnEmpty =
          skippedInlineOnEmpty || resolution.skippedInlineOnEmpty;

      for (var range in resolution.ranges.reversed) {
        int s = range['start']!;
        int l = range['len']!;

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
          if (!applied && s >= pt.length && !resolution.hasSelection) {
            skippedInlineOnEmpty = true;
          }
        }
      }
    }

    if (!didApplyFormat && skippedInlineOnEmpty) {
      return 'Line is empty; cannot apply style.';
    }
    return didApplyFormat ? 'Formatting applied!' : 'No matches found.';
  }

  static Map<String, dynamic> _normalizeInstruction(Map<String, dynamic> inst) {
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
      k = 'list';
      if (v == null || v == true || v.toString() == 'true') v = 'bullet';
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
      k = 'align';

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

    if (['bold', 'italic', 'underline', 'strike'].contains(k)) {
      v = (v.toString().toLowerCase() == 'true') ? 1 : null;
    }

    return {'key': k, 'value': v, 'target': target, 'occurrence': occ};
  }

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
    for (var key in keys) {
      controller.formatText(0, length, Attribute.fromKeyValue(key, null));
    }
  }

  static void _applySurgicalList({
    required QuillController controller,
    required String plainText,
    required int start,
    required int length,
    required String key,
    required dynamic value,
    required bool isSelectionTarget,
  }) {
    int lineEnd = plainText.indexOf('\n', start);
    if (lineEnd == -1) lineEnd = plainText.length;
    String lineText = plainText.substring(start, lineEnd).trim();

    bool isHeader =
        lineText.endsWith(':') ||
        lineText.toLowerCase().contains('list') ||
        lineText.toLowerCase().contains('items');

    int startPos = isHeader ? (lineEnd + 1).clamp(0, plainText.length) : start;
    int endPos = isSelectionTarget
        ? (start + length).clamp(0, plainText.length)
        : plainText.indexOf('\n\n', startPos);

    if (endPos == -1) endPos = plainText.length;

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

    if (startPos < endPos && startPos < plainText.length) {
      controller.formatText(
        startPos,
        endPos - startPos,
        Attribute.fromKeyValue(key, val),
      );
    } else {
      controller.formatText(start, length, Attribute.fromKeyValue(key, val));
    }
  }

  static void _applyBlockFormat({
    required QuillController controller,
    required String plainText,
    required int start,
    required int length,
    required String key,
    required dynamic value,
  }) {
    dynamic val = value;
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

    int blockLen = length;
    if (blockLen > 0 &&
        start + blockLen <= plainText.length &&
        plainText.substring(start, start + blockLen).endsWith('\n')) {
      blockLen -= 1;
    }

    if (key == 'align' && val == 'left') {
      val = null;
    }

    controller.formatText(start, blockLen, Attribute.fromKeyValue(key, val));
  }

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
    if (start >= plainText.length && !hasSelection) return false;

    if (key == 'size_change' ||
        (key == 'size' &&
            value.toString().toLowerCase().contains(
              RegExp(r'big|small|large|tiny'),
            ))) {
      final currentStyle = controller.document.collectStyle(start, 1);
      final sAttr = currentStyle.attributes['size'];
      double cur = (sAttr != null && sAttr.value is num)
          ? (sAttr.value as num).toDouble()
          : 16.0;
      double change =
          value.toString().contains('small') || value.toString().startsWith('-')
          ? -5.0
          : 5.0;
      value = (cur + change).clamp(8.0, 100.0);
      key = 'size';
    } else if (key == 'size') {
      final cleanNumberStr = value.toString().replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      value = (double.tryParse(cleanNumberStr) ?? 16.0).clamp(8.0, 100.0);
    }

    if (hasSelection && isSelectionTarget) {
      controller.formatSelection(Attribute.fromKeyValue(key, value));
    } else {
      if (key == 'link') {
        String finalUrl = value.toString().trim();
        if (!finalUrl.toLowerCase().startsWith('http')) {
          finalUrl = 'https://$finalUrl';
        }
        controller.formatText(
          start,
          length,
          Attribute.fromKeyValue('link', finalUrl),
        );
        controller.formatText(
          start,
          length,
          Attribute.fromKeyValue('color', '#1E88E5'),
        );
        controller.formatText(start, length, Attribute.underline);
      } else {
        int inlineLen = length;
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
