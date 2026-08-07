import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/widgets/controls/toolbar_items/hyperlink_title_dialog.dart';

// Hyperlink handler validates URLs, prompts for display text, and applies link formatting.
class HyperlinkHandler {
  static Future<void> convertToHyperlink({
    required BuildContext context,
    required QuillController controller,
  }) async {
    final selection = controller.selection;
    int startIndex = selection.baseOffset;
    int textLength = selection.extentOffset - startIndex;

    String targetUrl = '';

    if (textLength > 0) {
      targetUrl = controller.document.getPlainText(startIndex, textLength);
    } else {
      final fullText = controller.document.toPlainText();
      final int cursor = selection.baseOffset;

      int start = cursor;
      while (start > 0 && fullText[start - 1].trim().isNotEmpty) {
        start--;
      }

      int end = cursor;
      while (end < fullText.length && fullText[end].trim().isNotEmpty) {
        end++;
      }

      startIndex = start;
      textLength = end - start;

      if (textLength <= 0) return;
      targetUrl = fullText.substring(start, end);
    }

    if (!_isValidLink(targetUrl)) {
      showErrorSnackBar('Please enter a valid link');
      return;
    }

    String finalUrl = targetUrl.trim().toLowerCase();

    // 1. Smart TLD: "facebook" -> "facebook.com"
    if (!finalUrl.contains('.') && !finalUrl.contains(':')) {
      finalUrl = '$finalUrl.com';
    }

    // 2. Protocol: Ensure https prefix
    if (!finalUrl.startsWith('http://') &&
        !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final displayTitle = await showHyperlinkTitleDialog(context);

    if (displayTitle != null && displayTitle.isNotEmpty) {
      const trailingSpace = ' ';
      final insertedText = '$displayTitle$trailingSpace';

      controller.replaceText(startIndex, textLength, insertedText, null);

      controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.fromKeyValue('link', finalUrl),
      );
      controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.fromKeyValue('color', AppColors.hyperlinkHex),
      );
      controller.formatText(
        startIndex,
        displayTitle.length,
        Attribute.underline,
      );

      controller.updateSelection(
        TextSelection.collapsed(offset: startIndex + insertedText.length),
        ChangeSource.local,
      );
      controller.forceToggledStyle(const Style());
    }
  }

  static bool _isValidLink(String text) {
    return RegExp(
      r'^(https?://)?([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)?$',
    ).hasMatch(text.trim());
  }
}
