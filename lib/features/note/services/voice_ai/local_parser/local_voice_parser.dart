import 'base_voice_parser.dart';

/// A deterministic, lightweight local regex engine acting as the first line of defense for voice formatting.
/// It intercepts and resolves common, straightforward commands (like clearing styles, basic formatting, and selection targeting)
/// entirely offline, bypassing network round-trips.
class LocalVoiceParser implements BaseVoiceParser {
  @override
  List<VoiceInstruction>? parse(
      String voiceText, [
        String currentEditorText = '',
      ]) {
    final text = voiceText.toLowerCase().trim();
    if (text.isEmpty) return null;

    // 1. Direct Pass-Through Guard: Global Clear/Reset
    if (_isGlobalClearCommand(text)) {
      return [
        const VoiceInstruction(
          key: 'unformat_all',
          value: true,
          target: 'all',
          occurrence: 'all',
        ),
      ];
    }

    // 2. Extract Formatting Operation
    final formatTuple = _extractFormattingKeyAndValue(text);
    if (formatTuple == null) return null;
    final String key = formatTuple.$1;
    final dynamic value = formatTuple.$2;

    // 3. Extract Occurrence Modifier (nth instance)
    final String occurrence = _extractOccurrence(text);

    // 4. Extract Spatial Target
    final String target = _extractTarget(text, occurrence, currentEditorText);

    return [
      VoiceInstruction(
        key: key,
        value: value,
        target: target,
        occurrence: occurrence,
      ),
    ];
  }

  /// Short-circuits global clearing commands instantly.
  bool _isGlobalClearCommand(String text) {
    return [
      'clear formatting',
      'clear all formatting',
      'remove styles',
      'remove all styles',
      'reset everything',
      'nuke it',
      'wipe formatting',
      'clear document',
      'start over',
    ].any((phrase) => text.contains(phrase));
  }

  /// Determines the formatting key (e.g., 'color', 'bold', 'align') and its associated value.
  (String, dynamic)? _extractFormattingKeyAndValue(String text) {
    // Styles (Expanded vocabulary with word boundaries to prevent false positives)
    if (RegExp(r'\b(bold|bolder|embolden|thicken)\b').hasMatch(text)) {
      return ('bold', true);
    }
    if (RegExp(r'\b(italic|italics|italicize|slant)\b').hasMatch(text)) {
      return ('italic', true);
    }
    if (RegExp(r'\b(underline|underlined)\b').hasMatch(text)) {
      return ('underline', true);
    }
    if (RegExp(r'\b(strike|strikethrough|cross out|line through)\b').hasMatch(text)) {
      return ('strike', true);
    }

    // Alignment
    if (RegExp(r'\b(center|centre|middle)\b').hasMatch(text)) {
      return ('align', 'center');
    }
    if (RegExp(r'\b(right|right align)\b').hasMatch(text)) {
      return ('align', 'right');
    }
    if (RegExp(r'\b(left|left align)\b').hasMatch(text)) {
      return ('align', 'left');
    }
    if (RegExp(r'\b(justify|justified)\b').hasMatch(text)) {
      return ('align', 'justify');
    }

    // Colors (Expanded comprehensive palette)
    final Map<String, String> colorMap = {
      'red': '#F44336',
      'green': '#4CAF50',
      'blue': '#2196F3',
      'yellow': '#FFEB3B',
      'orange': '#FF9800',
      'purple': '#9C27B0',
      'black': '#000000',
      'white': '#FFFFFF',
      'gray': '#9E9E9E',
      'grey': '#9E9E9E',
      'pink': '#E91E63',
      'teal': '#009688',
      'cyan': '#00BCD4',
      'indigo': '#3F51B5',
      'brown': '#795548',
      'amber': '#FFC107',
      'lime': '#CDDC39',
      'magenta': '#E040FB',
      'navy': '#000080',
      'gold': '#FFD700',
      'silver': '#C0C0C0',
      'maroon': '#800000',
    };
    for (final color in colorMap.entries) {
      if (RegExp(r'\b' + color.key + r'\b').hasMatch(text)) {
        return ('color', color.value);
      }
    }

    // Lists (Expanded vocabulary)
    if (RegExp(r'\b(check|to-do|todo|checklist|checkboxes)\b').hasMatch(text)) {
      return ('list', 'unchecked');
    }
    if (RegExp(r'\b(number|order|numbered list|ordered list)\b').hasMatch(text)) {
      return ('list', 'ordered');
    }
    if (RegExp(r'\b(bullet|bullets|bullet points|unordered list|list)\b').hasMatch(text)) {
      return ('list', 'bullet');
    }

    // Relative Sizing
    if (RegExp(r'\b(massive|huge|giant|big|bigger|larger|increase|enlarge|grow)\b').hasMatch(text)) {
      return ('size_change', 5.0);
    }
    if (RegExp(r'\b(tiny|small|smaller|decrease|shrink|reduce)\b').hasMatch(text)) {
      return ('size_change', -5.0);
    }

    // Exact Sizing (e.g. "40 pixel" or "size 40")
    final sizeRegex = RegExp(r'(\d+)\s*(pixel|px|pt|point|size)');
    final sizeMatch = sizeRegex.firstMatch(text);
    if (sizeMatch != null) {
      final val = double.tryParse(sizeMatch.group(1) ?? '');
      if (val != null) return ('size', val);
    }
    final sizeRegex2 = RegExp(r'size\s*(\d+)');
    final sizeMatch2 = sizeRegex2.firstMatch(text);
    if (sizeMatch2 != null) {
      final val = double.tryParse(sizeMatch2.group(1) ?? '');
      if (val != null) return ('size', val);
    }

    // Links (Very basic local link extraction: "link this to google.com")
    final linkRegex = RegExp(
      r'(?:link|direct|point).*?to\s+([a-zA-Z0-9.-]+\.[a-zA-Z]{2,})',
    );
    final linkMatch = linkRegex.firstMatch(text);
    if (linkMatch != null) {
      return ('link', linkMatch.group(1));
    }

    return null;
  }

  /// Extracts the spatial target (e.g., 'selection', 'line:first', 'paragraph:2nd', or a literal word).
  String _extractTarget(
      String text,
      String occurrence,
      String currentEditorText,
      ) {
    // 1. Global
    if (text.contains('everything') ||
        text.contains('all text') ||
        text.contains('entire document') ||
        text.contains('whole thing')) {
      return 'all';
    }

    // 2. Selection Interceptor
    final selectionPhrases = [
      'this',
      'these',
      'those',
      'it',
      'selected text',
      'highlighted text',
      'selection',
      'current selection',
    ];
    // Check if the command is "make it bold" or "make this red"
    // We must ensure "this" isn't part of another phrase, though this is a fuzzy heuristic locally.
    for (final phrase in selectionPhrases) {
      // Very naive check for selection phrases standing alone.
      if (RegExp(r'\b' + RegExp.escape(phrase) + r'\b').hasMatch(text)) {
        // Exclude structural this (e.g., "this paragraph" is handled below)
        if (!text.contains('$phrase paragraph') &&
            !text.contains('$phrase line') &&
            !text.contains('$phrase block') &&
            !text.contains('$phrase sentence')) {
          return 'selection';
        }
      }
    }

    // 3. Structural Positional Targets
    // Maps ordinals
    final ordinals = {
      'first': 'first',
      '1st': '1st',
      'top': 'first',
      'starting': 'first',
      'beginning': 'first',
      'second': 'second',
      '2nd': '2nd',
      'third': 'third',
      '3rd': '3rd',
      'fourth': '4th',
      '4th': '4th',
      'last': 'last',
      'bottom': 'last',
      'ending': 'last',
      'end': 'last',
      'final': 'last',
    };

    // Regex to find structural commands: [ordinal] (line|sentence|paragraph)
    for (final entry in ordinals.entries) {
      final word = entry.key;
      final val = entry.value;

      if (text.contains('$word line')) return 'line:$val';
      if (text.contains('$word sentence')) {
        return 'line:$val'; // Sentences map to lines
      }
      if (text.contains('$word paragraph')) return 'paragraph:$val';
      if (text.contains('$word block')) return 'paragraph:$val';
    }

    // Check for "this line/paragraph"
    if (text.contains('this line') || text.contains('this sentence') || text.contains('current line')) {
      return 'line:this';
    }
    if (text.contains('this paragraph') || text.contains('this block') || text.contains('current paragraph')) {
      return 'paragraph:this';
    }

    // 4. Fallback: Literal Phrase via Action-Boundary Sandwich Eraser
    final extractedLiteral = _parseLiteralPhraseWithBoundaries(text);
    if (extractedLiteral != null && extractedLiteral.isNotEmpty) {
      // If we find a literal phrase, we MUST resolve it against the editor text here.
      // If the word doesn't exist, we return empty so Groq can handle complex synonym resolution.
      final resolvedLiteral = _resolveNthOccurrenceMath(
        extractedLiteral,
        occurrence,
        currentEditorText,
      );
      if (resolvedLiteral.startsWith('literal:')) {
        return resolvedLiteral;
      }
    }

    // If we reach here, local parsing failed to find a definitive target mapping.
    // Return empty to force a fallback to Groq.
    return '';
  }

  /// Extracts the specific occurrence with broader fuzzy matching.
  String _extractOccurrence(String text) {
    if (text.contains('first') || text.contains('1st') || text.contains('top')) {
      return 'first';
    }
    if (text.contains('second') || text.contains('2nd')) {
      return 'second';
    }
    if (text.contains('third') || text.contains('3rd')) {
      return 'third';
    }
    if (text.contains('last') || text.contains('bottom') || text.contains('final')) {
      return 'last';
    }
    return 'all';
  }

  /// Looks up nth-occurrence of a literal target word directly in the current editor text.
  /// If it finds the match, it returns an absolute index mapping string (e.g. `literal:150:8`),
  /// otherwise it falls back to the verbal string.
  String _resolveNthOccurrenceMath(
      String targetPhrase,
      String occurrence,
      String editorText,
      ) {
    if (targetPhrase.isEmpty || editorText.isEmpty) return targetPhrase;

    final lowText = editorText.toLowerCase();
    // Safely escape the target phrase
    final pattern = RegExp.escape(targetPhrase);

    // Find all exact word boundaries matching the target phrase
    final matches = RegExp(
      r'\b' + pattern + r'\b',
      caseSensitive: false,
    ).allMatches(lowText).toList();
    if (matches.isEmpty) return targetPhrase;

    int matchIndex = 0; // Default to first match if occurrence is 'all'
    if (occurrence == 'first') matchIndex = 0;
    if (occurrence == 'second') matchIndex = 1;
    if (occurrence == 'third') matchIndex = 2;
    if (occurrence == 'last') matchIndex = matches.length - 1;

    // If the requested occurrence exists, format the absolute coordinate string
    if (matchIndex >= 0 && matchIndex < matches.length) {
      final match = matches[matchIndex];
      // Format: literal:{start_index}:{length}
      return 'literal:${match.start}:${match.end - match.start}';
    }

    return targetPhrase;
  }

  /// Evaluates and cleans literal words/phrases, allowing asymmetric commands.
  String? _parseLiteralPhraseWithBoundaries(String text) {
    // 1. Strip conversational occurrence noise first
    var cleanText = text
        .replaceAll(RegExp(r'\b(the first time i said|the second time i said|the last time i said)\b'), '')
        .replaceAll(RegExp(r'\b(instance of|time i said|occurrence of|time i wrote)\b'), '')
        .replaceAll(RegExp(r'\b(instance|time)\b'), '')
        .trim();

    // 2. Prefix Hooks (Actions - Expanded)
    final prefixes = [
      'make the word', 'make the phrase', 'make', 'turn', 'highlight',
      'underline', 'strike through', 'strikethrough', 'strike', 'cross out',
      'bold', 'embolden', 'italicize', 'slant', 'link', 'direct', 'point',
      'format the word', 'style the word'
    ];

    // 3. Suffix Hooks (Styles - Expanded to match new colors and list synonyms)
    final suffixes = [
      'bold', 'italic', 'italics', 'red', 'green', 'blue', 'yellow', 'orange', 'purple',
      'black', 'white', 'gray', 'grey', 'pink', 'teal', 'cyan', 'indigo', 'brown', 'amber',
      'lime', 'magenta', 'navy', 'gold', 'silver', 'maroon',
      'a checklist', 'bullet points', 'bullets', 'numbered list', 'ordered list',
      'massive', 'huge', 'giant', 'big', 'bigger', 'larger', 'tiny',
      'small', 'smaller', 'pixel', 'px', 'pt', 'point', 'to google.com'
    ];

    String? matchedPrefix;
    for (final p in prefixes) {
      if (cleanText.startsWith('$p ') &&
          (matchedPrefix == null || p.length > matchedPrefix.length)) {
        matchedPrefix = p;
      }
    }

    String? matchedSuffix;
    for (final s in suffixes) {
      if (cleanText.endsWith(' $s') &&
          (matchedSuffix == null || s.length > matchedSuffix.length)) {
        matchedSuffix = s;
      }
    }

    // 4. Flexible Extraction (Sandwich, Prefix-only, or Suffix-only)
    String literalPhrase = cleanText;

    if (matchedPrefix != null && matchedSuffix != null) {
      literalPhrase = cleanText.substring(matchedPrefix.length, cleanText.length - matchedSuffix.length);
    } else if (matchedPrefix != null) {
      literalPhrase = cleanText.substring(matchedPrefix.length);
    } else if (matchedSuffix != null) {
      literalPhrase = cleanText.substring(0, cleanText.length - matchedSuffix.length);
    } else {
      // 5. Fallback for directional scaling verbs
      final sizingPrefixes = [
        'increase the size of', 'make bigger', 'enlarge', 'grow',
        'decrease the size of', 'make smaller', 'shrink', 'reduce the size of'
      ];
      for (final p in sizingPrefixes) {
        if (cleanText.startsWith('$p ')) {
          literalPhrase = cleanText.substring(p.length);
          break;
        }
      }
      if (literalPhrase == cleanText) return null; // No anchors found
    }

    return _cleanExtractedPhrase(literalPhrase);
  }

  /// Strips remaining structural articles and ordinals from the isolated phrase.
  String _cleanExtractedPhrase(String phrase) {
    var cleaned = phrase.trim();
    cleaned = cleaned.replaceAll(RegExp(r'^(the|a|an)\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'^(first|second|third|last|final|1st|2nd|3rd)\s+'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+to$'), ''); // cleanup dangling links
    return cleaned.trim();
  }
}