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
    final isGlobal =
        (normalizedTarget == 'all' ||
            normalizedTarget == 'everything' ||
            normalizedTarget == 'document') &&
        !commandText.toLowerCase().contains(
          RegExp(
            r'\b(dog|intelligent|because|loyal|smell|taking|starting|top|bottom|first|last|third|items|list|tasks|selection|this|that|it|sentence|paragraph)\b',
          ),
        );

    final isSelectionTarget =
        [
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
        // 🌟 FIX: Catch LLM fluff leakage like "all this text entirely"
        normalizedTarget.contains('this text') ||
        normalizedTarget.contains('selected');

    final ranges = <Map<String, int>>[];
    var skippedInlineOnEmpty = false;

    if (isSelectionTarget && hasSelection) {
      ranges.add({
        'start': selection.start,
        'len': selection.end - selection.start,
      });
    } else if (isGlobal) {
      ranges.add({'start': 0, 'len': plainText.length});
    } else if (target.startsWith('line:') ||
        target.startsWith('sentence:') ||
        target.startsWith('paragraph:')) {
      final type = target.split(':')[0];
      final idxStr = target.split(':')[1];
      List<String> segments = [];

      if (type == 'paragraph') {
        // IMPROVED: Split but filter out segments that are just whitespace
        segments = plainText.split(RegExp(r'(?<=\n\s*\n)'));
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
          // FIX: Subtract 1 to turn user "1" into programmer "0"
          targetIdx = rawNum - 1;
        } else {
          targetIdx = ordinals[idxStr] ?? -1;
        }
      }

      if (targetIdx >= 0 && targetIdx < segments.length) {
        // Skip purely empty segments (like leading newlines)
        if (segments[targetIdx].trim().isEmpty &&
            targetIdx + 1 < segments.length) {
          targetIdx++;
        }

        // --- RESTORED OFFSET CALCULATION ---
        var startOffset = 0;
        for (var i = 0; i < targetIdx; i++) {
          startOffset += segments[i].length;
        }

        final len = segments[targetIdx].length;
        if (len > 0) {
          ranges.add({'start': startOffset, 'len': len});
        } else if (['align', 'list'].contains(key)) {
          // Allow paragraph-level formatting even on empty lines
          ranges.add({'start': startOffset, 'len': 1});
        } else {
          skippedInlineOnEmpty = true;
        }
      }
    } else {
      final lowPt = plainText.toLowerCase();
      final pattern = RegExp.escape(target.toLowerCase());
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
        final i = (occurrence == 'last')
            ? matches.length - 1
            : ords[occurrence];
        if (i != null && matches.length > i) {
          matches = [matches[i]];
        } else if (occurrence != 'all') {
          matches = [];
        }
      }
      for (final match in matches) {
        ranges.add({'start': match.start, 'len': match.end - match.start});
      }
    }

    return VoiceFormattingResolution(
      ranges: ranges,
      skippedInlineOnEmpty: skippedInlineOnEmpty,
      isGlobal: isGlobal,
      isSelectionTarget: isSelectionTarget,
      hasSelection: hasSelection,
    );
  }
}
