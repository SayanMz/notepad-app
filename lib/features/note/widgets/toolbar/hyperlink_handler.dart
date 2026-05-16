import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/core/services/scaffold_messenger_notifier.dart';
import 'package:notepad/core/theme/app_colors.dart';
import 'package:notepad/features/note/widgets/toolbar/hyperlink_title_dialog.dart';

class HyperlinkHandler {
  /// The exact hyperlink logic from the monolithic file, now decoupled.
  static Future<void> convertToHyperlink({
    required BuildContext context,
    required QuillController controller,
    required FocusNode focusNode,
  }) async {
    final selection = controller.selection;
    int startIndex = selection.baseOffset;
    int textLength = selection.extentOffset - startIndex;

    String targetUrl = '';

    // 1. Extract selected text or nearby word if selection is collapsed
    if (textLength > 0) {
      targetUrl = controller.document.getPlainText(startIndex, textLength);
    } else {
      final textBefore = controller.document.getPlainText(0, startIndex);
      final lastSpace = textBefore.lastIndexOf(RegExp(r'\s'));
      startIndex = lastSpace == -1 ? 0 : lastSpace + 1;
      textLength = selection.baseOffset - startIndex;

      if (textLength <= 0) return;
      targetUrl = controller.document.getPlainText(startIndex, textLength);
    }

    // 2. Validate the extracted URL
    if (!_isValidLink(targetUrl)) {
      showErrorSnackBar('Please enter a valid link');
      return;
    }

    String finalUrl = targetUrl.trim();
    if (!finalUrl.toLowerCase().startsWith('http://') &&
        !finalUrl.toLowerCase().startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    // 3. Ask user for display title via the dialog
    final displayTitle = await showHyperlinkTitleDialog(context);

    if (displayTitle != null && displayTitle.isNotEmpty) {
      const trailingSpace = ' ';
      final insertedText = '$displayTitle$trailingSpace';

      // 4. Execute replacement
      controller.replaceText(startIndex, textLength, insertedText, null);

      // 5. Apply explicit instructions: Link, Hex Color, and Underline
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

      // 6. Move cursor position +1 index from the length to prevent style bleed
      controller.updateSelection(
        TextSelection.collapsed(offset: startIndex + insertedText.length),
        ChangeSource.local,
      );

      controller.forceToggledStyle(const Style());
      focusNode.requestFocus();
    }
  }

  static bool _isValidLink(String text) {
    return RegExp(
      r'^(https?://)?([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)?$',
    ).hasMatch(text.trim());
  }
}
