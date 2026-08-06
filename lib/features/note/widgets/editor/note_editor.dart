import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:notepad/features/note/services/link_handlers/note_link_handler.dart';

// Rich text note editor with link detection, link actions, and clipboard/share support.
class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.scrollController,
    this.scrollable = true,
    this.expands = true,
    this.showCursor = true,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController? scrollController;
  final bool scrollable;
  final bool expands;
  final bool showCursor;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  bool get isDark => context.isDark;
  ColorScheme get colorScheme => context.colorScheme;
  ScrollController? _internalScrollController;
  late final NoteLinkHandler _linkHandler;

  ScrollController get _effectiveScrollController {
    return widget.scrollController ??
        (_internalScrollController ??= ScrollController());
  }

  TextStyle get _baseTextStyle => GoogleFonts.sourceSans3(
    fontSize: NoteConstants.editorFontSize,
    fontWeight: FontWeight.w400,
    height: NoteConstants.editorLineHeight,
    color: isDark ? NoteConstants.editorTextColorDark : NoteConstants.editorTextColor,
  );

  // 🌟 Modify linkActionPickerDelegate to swallow native taps so our Overlay handles everything
  Future<LinkMenuAction> _handleLinkActionPicker(
    BuildContext context,
    String link,
    Node node,
  ) async {
    return LinkMenuAction.none;
  }

  @override
  void initState() {
    super.initState();
    _linkHandler = NoteLinkHandler();
    widget.controller.addListener(_checkCursorForLink);
  }

  @override
  void didUpdateWidget(covariant NoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_checkCursorForLink);
      widget.controller.addListener(_checkCursorForLink);
      _checkCursorForLink();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_checkCursorForLink);
    _linkHandler.removeLinkPopup();
    _internalScrollController?.dispose();
    super.dispose();
  }

  void _checkCursorForLink() {
    if (!mounted) return;

    if (!widget.focusNode.hasFocus) {
      _linkHandler.removeLinkPopup();
      return;
    }

    final selection = widget.controller.selection;
    // Dismisses menu if text is highlighted.
    if (!selection.isCollapsed) {
      _linkHandler.removeLinkPopup();
      return;
    }

    final style = widget.controller.getSelectionStyle();
    final linkAttr = style.attributes[Attribute.link.key];

    if (linkAttr != null && linkAttr.value != null) {
      final currentLink = linkAttr.value.toString();
      // Re-renders the link menu only if the cursor moves to a different URL.
      if (_linkHandler.activeLink != currentLink) {
        _linkHandler.showHorizontalLinkMenu(context, currentLink, isDark);
      }
    } else {
      _linkHandler.removeLinkPopup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = _baseTextStyle;

    return QuillEditor(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: _effectiveScrollController,
      config: QuillEditorConfig(
        scrollable: widget.scrollable,
        expands: widget.expands,
        showCursor: widget.showCursor,

        customStyleBuilder: (attribute) {
          if (attribute.key == Attribute.link.key && attribute.value != null) {
            return const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            );
          }
          return const TextStyle();
        },

        linkActionPickerDelegate: _handleLinkActionPicker,

        padding: const EdgeInsets.symmetric(
          horizontal: NoteConstants.editorHorizontalPadding,
        ),
        placeholder: 'Start typing your note...',

        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            baseTextStyle,
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
          placeHolder: DefaultTextBlockStyle(
            baseTextStyle.copyWith(color: colorScheme.onSurfaceVariant),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }
}
