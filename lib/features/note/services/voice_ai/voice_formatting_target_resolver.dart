// Target resolution figures out which note text a spoken command should affect.
import 'package:flutter_quill/flutter_quill.dart';

class VoiceFormattingResolution {
  const VoiceFormattingResolution({
    required this.ranges,
    required this.skippedInlineOnEmpty,
    required this.isGlobal,
    required this.isSelectionTarget,
    required this.hasSelection,
  });

  final List<Map<String, int>> ranges;
  final bool skippedInlineOnEmpty;
  final bool isGlobal;
  final bool isSelectionTarget;
  final bool hasSelection;
}

class VoiceFormattingTargetResolver {
  static VoiceFormattingResolution resolve({
    required QuillController controller,
    required String plainText,
    required String target,
    required String occurrence,
    required String commandText,
    required String key,
  }) {
    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final normalizedTarget = target.toLowerCase();

    final isGlobal = _checkIfGlobal(normalizedTarget);
    final isSelectionTarget = _checkIfSelectionTarget(normalizedTarget);

    List<Map<String, int>> ranges = [];
    bool skippedInlineOnEmpty = false;

    if (isSelectionTarget && hasSelection) {
      ranges.add({
        'start': selection.start,
        'len': selection.end - selection.start,
      });
    }
    else if (isGlobal) {
      ranges.add({'start': 0, 'len': plainText.length});
    }
    else if (_isPositionalTarget(normalizedTarget)) {
      final result = _resolvePositionalTarget(
        plainText: plainText,
        target: normalizedTarget,
        key: key,
      );
      ranges = result.ranges;
      skippedInlineOnEmpty = result.skippedInlineOnEmpty;
    }
    else {
      ranges = _resolveLiteralPhraseTarget(
        plainText: plainText,
        target: normalizedTarget,
        occurrence: occurrence.toLowerCase(),
      );
    }

    return VoiceFormattingResolution(
      ranges: ranges,
      skippedInlineOnEmpty: skippedInlineOnEmpty,
      isGlobal: isGlobal,
      isSelectionTarget: isSelectionTarget,
      hasSelection: hasSelection,
    );
  }


  static bool _checkIfGlobal(String normalizedTarget) {
    return (normalizedTarget == 'all' ||
        normalizedTarget == 'everything' ||
        normalizedTarget == 'document');
  }

  static bool _checkIfSelectionTarget(String normalizedTarget) {
    return [
          'selection',
          'this',
          'these',
          'those',
          'it',
          'this line',
          'these lines',
          'this paragraph',
          'this sentence',
          'that',
          'selected text',
          'paragraph:this',
          'line:this',
          'all this',
          'all of this',
        ].contains(normalizedTarget) ||
        normalizedTarget.contains('this text') ||
        normalizedTarget.contains('selected');
  }

  static bool _isPositionalTarget(String target) {
    return target.startsWith('line:') ||
        target.startsWith('sentence:') ||
        target.startsWith('paragraph:');
  }

  static _PositionalResult _resolvePositionalTarget({
    required String plainText,
    required String target,
    required String key,
  }) {
    final type = target.split(':')[0];
    final idxStr = target.split(':')[1];
    List<String> segments;

    if (type == 'paragraph') {
      segments = plainText.split(RegExp(r'(?<=\n\n)'));
    } else {
      segments = plainText.split(RegExp(r'(?<=[.\n])'));
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

    var targetIdx = -1;
    if (['last', 'bottom', 'end', 'ending'].contains(idxStr)) {
      for (var i = segments.length - 1; i >= 0; i--) {
        if (segments[i].trim().isNotEmpty) {
          targetIdx = i;
          break;
        }
      }
    } else {
      final rawNum = int.tryParse(idxStr);
      if (rawNum != null) {
        targetIdx = rawNum - 1;
      } else {
        targetIdx = ordinals[idxStr] ?? -1;
      }
    }

    List<Map<String, int>> ranges = [];
    bool skipped = false;

    if (targetIdx >= 0 && targetIdx < segments.length) {
      if (segments[targetIdx].trim().isEmpty &&
          targetIdx + 1 < segments.length) {
        targetIdx++;
      }

      var startOffset = 0;
      for (var i = 0; i < targetIdx; i++) {
        startOffset += segments[i].length;
      }

      final len = segments[targetIdx].length;
      if (len > 0) {
        ranges.add({'start': startOffset, 'len': len});
      } else if (['align', 'list'].contains(key)) {
        ranges.add({'start': startOffset, 'len': 1});
      } else {
        skipped = true;
      }
    }

    return _PositionalResult(ranges, skipped);
  }

  static List<Map<String, int>> _resolveLiteralPhraseTarget({
    required String plainText,
    required String target,
    required String occurrence,
  }) {
    final lowPt = plainText.toLowerCase();
    final pattern = RegExp.escape(target);

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

    if (occurrence != 'all' && matches.isNotEmpty) {
      const ords = {
        'first': 0,
        '1st': 0,
        'second': 1,
        '2nd': 1,
        'third': 2,
        '3rd': 2,
        'last': -1,
      };

      final i = (occurrence == 'last') ? matches.length - 1 : ords[occurrence];
      if (i != null && matches.length > i) {
        matches = [matches[i]];
      } else if (occurrence != 'all') {
        matches = [];
      }
    }

    return matches
        .map((m) => {'start': m.start, 'len': m.end - m.start})
        .toList();
  }
}

class _PositionalResult {
  final List<Map<String, int>> ranges;
  final bool skippedInlineOnEmpty;
  _PositionalResult(this.ranges, this.skippedInlineOnEmpty);
}

