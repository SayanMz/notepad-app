import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.scrollController, // ⚡ FIX: Made optional!
    this.scrollable = true,
    this.expands = true,
    this.showCursor = true,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final ScrollController? scrollController; // ⚡ Optional reference
  final bool scrollable;
  final bool expands;
  final bool showCursor;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  // ⚡ Internal standalone backup controller for normal editing mode
  ScrollController? _internalScrollController;

  // Helper getter to determine which controller has execution authority
  ScrollController get _effectiveScrollController {
    return widget.scrollController ??
        (_internalScrollController ??= ScrollController());
  }

  @override
  void dispose() {
    // Clean up our internal controller allocation safely if it was instantiated
    _internalScrollController?.dispose();
    super.dispose();
  }

  Future<LinkMenuAction> _handleLinkActionPicker(
    BuildContext context,
    String link,
    Node node,
  ) async {
    final normalizedLink = link.trim();
    final uri = Uri.tryParse(normalizedLink);

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return LinkMenuAction.none;
    }

    return LinkMenuAction.launch;
  }

  @override
  Widget build(BuildContext context) {
    final baseTextStyle = GoogleFonts.sourceSans3(
      fontSize: NoteConstants.editorFontSize,
      fontWeight: FontWeight.w400,
      height: NoteConstants.editorLineHeight,
      color: NoteConstants.editorTextColor,
    );

    return QuillEditor(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController:
          _effectiveScrollController, // ⚡ Resolves to the correct controller instantly
      config: QuillEditorConfig(
        scrollable: widget.scrollable,
        expands: widget.expands,
        showCursor: widget.showCursor,
        onLaunchUrl: (String url) async {
          final uri = Uri.tryParse(url);
          if (uri != null && await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
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
            baseTextStyle.copyWith(color: Colors.grey),
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
