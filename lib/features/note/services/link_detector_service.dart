import 'package:flutter_quill/flutter_quill.dart';

class LinkDetectorService {
  // --- PHONE REGEXES ---
  static final RegExp _standardPhoneRegex = RegExp(
    r'(?<!\d)(?:(?:\(\+?\d{1,4}\)|\+\d{1,4})[\s-]*)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}(?!\d)',
  );
  static final RegExp _countryCodePrefixRegex = RegExp(
    r'(?:\(\+?\d{1,4}\)|\+\d{1,4})[\s-]*$',
  );

  // --- EMAIL & WEBSITE REGEXES ---
  static final RegExp _emailValidator = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );
  static final RegExp _websiteValidator = RegExp(
    r'^(?:(?:https?:\/\/|www\.)[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+|[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,14})(?::\d+)?(?:\/[^\s]*)?$',
  );

  // 🌟 --- NEW: INDUSTRIAL DATE REGEXES (Using Named Capture Groups) ---
  static final List<RegExp> _dateValidators = [
    // 1. YYYY-MM-DD or YYYY/MM/DD
    RegExp(
      r'\b(?<year>(?:19|20)\d\d)[-/.](?<month>0?[1-9]|1[012])[-/.](?<day>0?[1-9]|[12][0-9]|3[01])\b',
    ),
    // 2. DD/MM/YYYY or DD-MM-YYYY (Assumes global standard over US MM/DD for ambiguity)
    RegExp(
      r'\b(?<day>0?[1-9]|[12][0-9]|3[01])[-/.](?<month>0?[1-9]|1[012])[-/.](?<year>(?:19|20)\d\d)\b',
    ),
    // 3. Month DD, YYYY (e.g., April 12, 2026)
    RegExp(
      r'\b(?<month>Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(?<day>0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?(?:,)?\s+(?<year>(?:19|20)\d\d)\b',
      caseSensitive: false,
    ),
    // 4. DD Month YYYY (e.g., 12th of April 2026)
    RegExp(
      r'\b(?<day>0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?\s+(?:of\s+)?(?<month>Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(?<year>(?:19|20)\d\d)\b',
      caseSensitive: false,
    ),
  ];

  static final Map<String, String> _monthMap = {
    'jan': '01',
    'january': '01',
    'feb': '02',
    'february': '02',
    'mar': '03',
    'march': '03',
    'apr': '04',
    'april': '04',
    'may': '05',
    'jun': '06',
    'june': '06',
    'jul': '07',
    'july': '07',
    'aug': '08',
    'august': '08',
    'sep': '09',
    'september': '09',
    'oct': '10',
    'october': '10',
    'nov': '11',
    'november': '11',
    'dec': '12',
    'december': '12',
  };

  static void scanAndLinkifyParagraph(QuillController controller) {
    final wholeText = controller.document.toPlainText();
    if (wholeText.isEmpty) return;

    final currentSelection = controller.selection;
    bool didFormat = false;

    void applyLink(int start, int length, String url) {
      final styleAtChar = controller.document.collectStyle(start, 1);
      if (!styleAtChar.containsKey(Attribute.link.key)) {
        controller.formatText(start, length, LinkAttribute(url));
        didFormat = true;
      }
    }

    // 1. HARDCODED 5-5 PHONE SPLIT SCANNER
    if (wholeText.length >= 11) {
      for (int i = 5; i < wholeText.length - 5; i++) {
        if (wholeText[i] == '-' || wholeText[i] == ' ') {
          final before = wholeText.substring(i - 5, i);
          final after = wholeText.substring(i + 1, i + 6);
          if (_isPureDigits(before) && _isPureDigits(after)) {
            int start = i - 5;
            int length = 11;
            int prefixSearchStart = start >= 10 ? start - 10 : 0;
            String precedingText = wholeText.substring(
              prefixSearchStart,
              start,
            );
            final prefixMatch = _countryCodePrefixRegex.firstMatch(
              precedingText,
            );
            if (prefixMatch != null) {
              start -= prefixMatch.group(0)!.length;
              length += prefixMatch.group(0)!.length;
            }
            final matchedText = wholeText.substring(start, start + length);
            final cleanUrl = matchedText.replaceAll(RegExp(r'[\s\-]'), '');
            applyLink(start, length, 'tel:$cleanUrl');
          }
        }
      }
    }

    // 2. SMART SPACED NUMBER SCANNER
    int seqStart = -1;
    int digitCount = 0;
    int lastDigitIndex = -1;

    for (int i = 0; i <= wholeText.length; i++) {
      bool isEnd = i == wholeText.length;
      if (isEnd) {
        if (seqStart != -1 && digitCount >= 9 && digitCount <= 15) {
          int length = lastDigitIndex - seqStart + 1;
          String matchedText = wholeText.substring(seqStart, seqStart + length);
          String cleanUrl = matchedText.replaceAll(RegExp(r'[\s\-\(\)]'), '');
          applyLink(seqStart, length, 'tel:$cleanUrl');
        }
        break;
      }

      int code = wholeText.codeUnitAt(i);
      bool isDigit = code >= 48 && code <= 57;
      bool isAllowedSeparator =
          code == 32 ||
          code == 45 ||
          code == 40 ||
          code == 41 ||
          code == 0x200B;

      if (isDigit) {
        if (seqStart == -1) seqStart = i;
        digitCount++;
        lastDigitIndex = i;
      } else if (!isAllowedSeparator) {
        if (seqStart != -1) {
          if (digitCount >= 9 && digitCount <= 15) {
            int length = lastDigitIndex - seqStart + 1;
            String matchedText = wholeText.substring(
              seqStart,
              seqStart + length,
            );
            String cleanUrl = matchedText.replaceAll(RegExp(r'[\s\-\(\)]'), '');
            applyLink(seqStart, length, 'tel:$cleanUrl');
          }
          seqStart = -1;
          digitCount = 0;
          lastDigitIndex = -1;
        }
      }
    }

    // 3. REGEX PHONE FALLBACK
    final phoneMatches = _standardPhoneRegex.allMatches(wholeText);
    for (final match in phoneMatches) {
      final matchedText = match.group(0) ?? '';
      final digitCount = matchedText.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount >= 9 && digitCount <= 14) {
        final cleanUrl = matchedText.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        applyLink(match.start, match.end - match.start, 'tel:$cleanUrl');
      }
    }

    // 4. EMAIL & WEBSITE SCANNER
    int indexTracker = 0;
    final tokens = wholeText.split(RegExp(r'[\s\n]+'));
    for (final token in tokens) {
      if (token.isEmpty) {
        indexTracker++;
        continue;
      }
      int startOffset = wholeText.indexOf(token, indexTracker);
      if (startOffset == -1) startOffset = indexTracker;
      indexTracker = startOffset + token.length;

      String cleanToken = token;
      while (cleanToken.isNotEmpty &&
          (cleanToken.endsWith('.') ||
              cleanToken.endsWith(',') ||
              cleanToken.endsWith(')') ||
              cleanToken.endsWith('!'))) {
        cleanToken = cleanToken.substring(0, cleanToken.length - 1);
      }
      if (cleanToken.isEmpty) continue;

      if (cleanToken.contains('@') && _emailValidator.hasMatch(cleanToken)) {
        applyLink(startOffset, cleanToken.length, 'mailto:$cleanToken');
      } else if (cleanToken.contains('.') &&
          _websiteValidator.hasMatch(cleanToken)) {
        final prefix =
            (cleanToken.startsWith('http://') ||
                cleanToken.startsWith('https://'))
            ? ''
            : 'https://';
        applyLink(startOffset, cleanToken.length, '$prefix$cleanToken');
      }
    }

    // 🌟 5. DYNAMIC DATE SCANNER
    for (final regex in _dateValidators) {
      final matches = regex.allMatches(wholeText);
      for (final match in matches) {
        final start = match.start;
        final length = match.end - match.start;

        final styleAtChar = controller.document.collectStyle(start, 1);
        if (styleAtChar.containsKey(Attribute.link.key)) continue;

        // Extract raw groupings
        String year = match.namedGroup('year')!;
        String monthRaw = match.namedGroup('month')!.toLowerCase();
        String day = match.namedGroup('day')!;

        // Convert word months (April) to numbers (04)
        String month = _monthMap[monthRaw] ?? monthRaw;

        // Pad single digits natively
        if (month.length == 1) month = '0$month';
        if (day.length == 1) day = '0$day';

        // Construct standard OS Date Code
        final dateCode = '$year$month$day';
        final rawText = wholeText.substring(start, start + length);

        // Payload syntax: cal:20260412|April 12, 2026
        applyLink(start, length, 'cal:$dateCode|$rawText');
      }
    }

    if (didFormat) {
      controller.toggledStyle = Style();
      controller.updateSelection(currentSelection, ChangeSource.local);
    }
  }

  static bool _isPureDigits(String str) {
    for (int i = 0; i < str.length; i++) {
      final code = str.codeUnitAt(i);
      if (code < 48 || code > 57) return false;
    }
    return true;
  }
}
