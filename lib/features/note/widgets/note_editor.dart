// The editor wraps the Quill surface and its layout constraints.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:url_launcher/url_launcher.dart';

// The editor view wraps the Quill surface and its layout constraints.
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
  ScrollController? _internalScrollController;

  ScrollController get _effectiveScrollController {
    return widget.scrollController ??
        (_internalScrollController ??= ScrollController());
  }

  late final baseTextStyle = GoogleFonts.sourceSans3(
    fontSize: NoteConstants.editorFontSize,
    fontWeight: FontWeight.w400,
    height: NoteConstants.editorLineHeight,
    color: isDark ? const Color(0xFF94A3B8) : NoteConstants.editorTextColor,
  );

  @override
  void dispose() {
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
    return QuillEditor(
      controller: widget.controller,
      focusNode: widget.focusNode,
      scrollController: _effectiveScrollController,
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
