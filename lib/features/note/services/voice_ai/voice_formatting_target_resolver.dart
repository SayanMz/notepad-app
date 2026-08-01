// Resolves spoken formatting targets into Quill document ranges.
import 'package:flutter_quill/flutter_quill.dart';

/// A data class that encapsulates the final results of the target resolution process.
/// It tells the formatting service exactly where and how to apply the styles.
class VoiceFormattingResolution {
  const VoiceFormattingResolution({
    required this.ranges,
    required this.skippedInlineOnEmpty,
    required this.isGlobal,
    required this.isSelectionTarget,
    required this.hasSelection,
  });

  /// List of map objects containing 'start' and 'len' keys for the target text.
  final List<Map<String, int>> ranges;

  /// Flag indicating if formatting was skipped because the targeted line was empty.
  final bool skippedInlineOnEmpty;

  /// Flag indicating if the user targeted the entire document (e.g., "all").
  final bool isGlobal;

  /// Flag indicating if the user specifically targeted their active text selection.
  final bool isSelectionTarget;

  /// Flag indicating if there is currently an active text selection in the editor.
  final bool hasSelection;
}

/// Core engine for translating natural language targets (e.g., "first paragraph",
/// "the word hello") into mathematical text ranges within the Quill editor.
class VoiceFormattingTargetResolver {
  /// Main orchestrator method. It cascades through different targeting strategies
  /// (Selection -> Global -> Positional -> Literal) to find the correct text bounds.
  static VoiceFormattingResolution resolve({
    required QuillController controller,
    required String plainText,
    required String target,
    required String occurrence,
    required String commandText,
    required String key,
  }) {
    // Read current cursor/selection state from the editor.
    final selection = controller.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;
    final normalizedTarget = target.toLowerCase();

    // Categorize the type of target request.
    final isGlobal = _checkIfGlobal(normalizedTarget);
    final isSelectionTarget = _checkIfSelectionTarget(normalizedTarget);

    List<Map<String, int>> ranges = [];
    bool skippedInlineOnEmpty = false;

    // Strategy 1: The user wants to format the text they currently have highlighted.
    if (isSelectionTarget && hasSelection) {
      ranges.add({
        'start': selection.start,
        'len': selection.end - selection.start,
      });
    }
    // Strategy 2: The user wants to format the entire document.
    else if (isGlobal) {
      ranges.add({'start': 0, 'len': plainText.length});
    }
    // Strategy 3: The user is targeting a structural position (e.g. "line:2" or "paragraph:first").
    else if (_isPositionalTarget(normalizedTarget)) {
      final result = _resolvePositionalTarget(
        plainText: plainText,
        target: normalizedTarget,
        key: key,
      );
      ranges = result.ranges;
      skippedInlineOnEmpty = result.skippedInlineOnEmpty;
    }
    // Strategy 4: The user is looking for a specific literal word or phrase (e.g., "bold 'apple'").
    else {
      ranges = _resolveLiteralPhraseTarget(
        plainText: plainText,
        target: normalizedTarget,
        occurrence: occurrence.toLowerCase(),
      );
    }

    // Package and return the final resolved metadata.
    return VoiceFormattingResolution(
      ranges: ranges,
      skippedInlineOnEmpty: skippedInlineOnEmpty,
      isGlobal: isGlobal,
      isSelectionTarget: isSelectionTarget,
      hasSelection: hasSelection,
    );
  }

  /// Checks if the spoken target implies the entire document.
  static bool _checkIfGlobal(String normalizedTarget) {
    return (normalizedTarget == 'all' ||
        normalizedTarget == 'everything' ||
        normalizedTarget == 'document');
  }

  /// Checks if the spoken target refers to the currently highlighted text,
  /// mapping common natural language pronouns and phrases.
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

  /// Determines if the target string is formatted as a structural position request.
  static bool _isPositionalTarget(String target) {
    return target.startsWith('line:') ||
        target.startsWith('sentence:') ||
        target.startsWith('paragraph:');
  }

  /// Calculates the exact start/length indices for structural commands like "last paragraph".
  static _PositionalResult _resolvePositionalTarget({
    required String plainText,
    required String target,
    required String key,
  }) {
    final type = target.split(':')[0]; // e.g., 'paragraph'
    final idxStr = target.split(':')[1]; // e.g., 'first' or '2'
    List<String> segments;

    // Split the document into an array of chunks based on the requested structure.
    if (type == 'paragraph') {
      // Split by double newline to isolate paragraphs.
      segments = plainText.split(RegExp(r'(?<=\n\n)'));
    } else {
      // Split by periods or single newlines to isolate sentences/lines.
      segments = plainText.split(RegExp(r'(?<=[.\n])'));
    }

    // Map spoken ordinal words to array indices.
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

    // Handle requests for the very end of the document.
    if (['last', 'bottom', 'end', 'ending'].contains(idxStr)) {
      // Iterate backwards to find the last segment that actually contains text (ignoring trailing whitespace).
      for (var i = segments.length - 1; i >= 0; i--) {
        if (segments[i].trim().isNotEmpty) {
          targetIdx = i;
          break;
        }
      }
    } else {
      // Parse absolute numbers (e.g., '3') or mapped ordinals (e.g., 'third').
      final rawNum = int.tryParse(idxStr);
      if (rawNum != null) {
        targetIdx = rawNum - 1; // Convert 1-based human logic to 0-based index
      } else {
        targetIdx = ordinals[idxStr] ?? -1;
      }
    }

    List<Map<String, int>> ranges = [];
    bool skipped = false;

    if (targetIdx >= 0 && targetIdx < segments.length) {
      // Heuristic: If the exact requested line is completely empty but the next line isn't,
      // assume the user meant the next valid line of text.
      if (segments[targetIdx].trim().isEmpty &&
          targetIdx + 1 < segments.length) {
        targetIdx++;
      }

      // Calculate the absolute character offset in the entire document by summing previous segment lengths.
      var startOffset = 0;
      for (var i = 0; i < targetIdx; i++) {
        startOffset += segments[i].length;
      }

      final len = segments[targetIdx].length;
      if (len > 0) {
        // Valid segment found, add to ranges.
        ranges.add({'start': startOffset, 'len': len});
      } else if (['align', 'list'].contains(key)) {
        // Edge case: Allow block-level formatting (lists/alignment) on an empty line.
        ranges.add({'start': startOffset, 'len': 1});
      } else {
        // Inline formatting (bold/color) cannot be applied to an empty line.
        skipped = true;
      }
    }

    return _PositionalResult(ranges, skipped);
  }

  /// Finds exact text indices when the user targets a specific word or phrase.
  static List<Map<String, int>> _resolveLiteralPhraseTarget({
    required String plainText,
    required String target,
    required String occurrence,
  }) {
    final lowPt = plainText.toLowerCase();
    final pattern = RegExp.escape(target);

    // Fallback Strategy 1: Try to match the exact phrase with strict word boundaries.
    var matches = RegExp(
      r'\b' + pattern + r'\b',
      caseSensitive: false,
    ).allMatches(lowPt).toList();

    // Fallback Strategy 2: Try to match as a prefix (e.g. "run" matches "running").
    if (matches.isEmpty) {
      matches = RegExp(
        r'\b' + pattern,
        caseSensitive: false,
      ).allMatches(lowPt).toList();
    }

    // Fallback Strategy 3: Loose match anywhere in the text.
    if (matches.isEmpty) {
      matches = RegExp(
        pattern,
        caseSensitive: false,
      ).allMatches(lowPt).toList();
    }

    // If the user specified an occurrence (e.g., "bold the *second* 'hello'"), filter the results.
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

      // Find requested occurrence index.
      final i = (occurrence == 'last') ? matches.length - 1 : ords[occurrence];

      if (i != null && matches.length > i) {
        matches = [matches[i]]; // Keep only the specific matched instance.
      } else if (occurrence != 'all') {
        matches = []; // Requested occurrence out of bounds, return empty.
      }
    }

    // Convert Regex Match objects into our standard range map format.
    return matches
        .map((m) => {'start': m.start, 'len': m.end - m.start})
        .toList();
  }
}

/// Internal private data class used to return multiple values from _resolvePositionalTarget.
class _PositionalResult {
  final List<Map<String, int>> ranges;
  final bool skippedInlineOnEmpty;
  _PositionalResult(this.ranges, this.skippedInlineOnEmpty);
}
