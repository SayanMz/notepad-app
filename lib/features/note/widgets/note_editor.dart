import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for Clipboard
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/note_constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

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

  // 🌟 The Samsung Notes Overlay States
  String? _activeLink;
  OverlayEntry? _linkPopup;

  late final baseTextStyle = GoogleFonts.sourceSans3(
    fontSize: NoteConstants.editorFontSize,
    fontWeight: FontWeight.w400,
    height: NoteConstants.editorLineHeight,
    color: isDark ? const Color(0xFF94A3B8) : NoteConstants.editorTextColor,
  );

  @override
  void initState() {
    super.initState();
    // 🌟 Bind the cursor tracker exactly when the editor boots up
    widget.controller.addListener(_checkCursorForLink);
  }

  @override
  void dispose() {
    // 🌟 Safely clean up memory and popups
    widget.controller.removeListener(_checkCursorForLink);
    _removeLinkPopup();
    _internalScrollController?.dispose();
    super.dispose();
  }

  // 🌟 Core Tracking Logic: Reads cursor position continuously
  void _checkCursorForLink() {
    if (!widget.focusNode.hasFocus) {
      _removeLinkPopup();
      return;
    }

    final selection = widget.controller.selection;
    if (!selection.isCollapsed) {
      _removeLinkPopup();
      return;
    }

    final style = widget.controller.getSelectionStyle();
    final linkAttr = style.attributes[Attribute.link.key];

    if (linkAttr != null && linkAttr.value != null) {
      final currentLink = linkAttr.value.toString();
      if (_activeLink != currentLink) {
        _showHorizontalLinkMenu(context, currentLink);
      }
    } else {
      _removeLinkPopup();
    }
  }

  void _removeLinkPopup() {
    _linkPopup?.remove();
    _linkPopup = null;
    _activeLink = null;
  }

  void _showHorizontalLinkMenu(BuildContext context, String actualLink) {
    _removeLinkPopup();
    _activeLink = actualLink;

    // 🌟 1. Unpack the payload if it's a date
    bool isDate = actualLink.startsWith('cal:');
    String actionCode = actualLink;
    String rawTextForCopy = '';

    if (isDate) {
      final parts = actualLink.split('|');
      actionCode = parts[0].replaceFirst('cal:', ''); // Yields: 20260412
      if (parts.length > 1) rawTextForCopy = parts[1]; // Yields: April 12, 2026
    }

    String primaryLabel = 'Open';
    IconData primaryIcon = Icons.language;

    if (actualLink.startsWith('tel:')) {
      primaryLabel = 'Call';
      primaryIcon = Icons.phone;
    } else if (actualLink.startsWith('mailto:')) {
      primaryLabel = 'Gmail';
      primaryIcon = Icons.mail;
    } else if (isDate) {
      primaryLabel = 'Add Event';
      primaryIcon = Icons.edit_calendar; // 🌟 Triggers Date UI
    }

    _linkPopup = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- OPTION 1: OPEN APP ---
                      TextButton.icon(
                        onPressed: () async {
                          _removeLinkPopup();
                          if (actualLink.startsWith('tel:')) {
                            final number = actualLink.replaceFirst('tel:', '');
                            await launchUrl(Uri.parse('tel:$number'));
                          } else if (actualLink.startsWith('mailto:')) {
                            final email = actualLink.replaceFirst(
                              'mailto:',
                              '',
                            );
                            final androidIntent =
                                'intent://co?to=$email#Intent;scheme=googlegmail;package=com.google.android.gm;end';
                            final iosScheme = 'googlegmail:///co?to=$email';
                            if (await canLaunchUrl(Uri.parse(androidIntent))) {
                              await launchUrl(Uri.parse(androidIntent));
                            } else if (await canLaunchUrl(
                              Uri.parse(iosScheme),
                            )) {
                              await launchUrl(Uri.parse(iosScheme));
                            } else {
                              await launchUrl(
                                Uri.parse('mailto:$email'),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } else if (isDate) {
                            // 1. Extract the exact date properties
                            final year = int.parse(actionCode.substring(0, 4));
                            final month = int.parse(actionCode.substring(4, 6));
                            final day = int.parse(actionCode.substring(6, 8));

                            final eventDate = DateTime(year, month, day);
                            final epochMs = eventDate.millisecondsSinceEpoch;

                            _removeLinkPopup();

                            if (Platform.isAndroid) {
                              // 2. Direct Hardware Intent Pipeline for Android
                              final AndroidIntent intent = AndroidIntent(
                                action: 'android.intent.action.INSERT',
                                data: 'content://com.android.calendar/events',
                                type: 'vnd.android.cursor.dir/event',
                                arguments: <String, dynamic>{
                                  'title': 'New Event',
                                  'beginTime': epochMs,
                                  'endTime':
                                      epochMs +
                                      3600000, // +1 hour duration default
                                },
                              );
                              await intent.launch();
                            } else if (Platform.isIOS) {
                              // 3. Official System Calendar Deep Link for iOS
                              final epochSecs = epochMs ~/ 1000;
                              final iosUri = 'calshow:$epochSecs';
                              await launchUrl(
                                Uri.parse(iosUri),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          } else {
                            await launchUrl(
                              Uri.parse(actualLink),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: Icon(primaryIcon, size: 18, color: Colors.blue),
                        label: Text(
                          primaryLabel,
                          style: const TextStyle(color: Colors.blue),
                        ),
                      ),

                      // --- OPTION 2: COPY ---
                      TextButton.icon(
                        onPressed: () async {
                          _removeLinkPopup();
                          // 🌟 Ensures they copy "April 12" and not the hidden machine code
                          final cleanText = isDate
                              ? rawTextForCopy
                              : actualLink
                                    .replaceFirst('tel:', '')
                                    .replaceFirst('mailto:', '');
                          await Clipboard.setData(
                            ClipboardData(text: cleanText),
                          );
                        },
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: Colors.grey,
                        ),
                        label: const Text(
                          'Copy',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),

                      // --- OPTION 3: SHARE ---
                      TextButton.icon(
                        onPressed: () async {
                          _removeLinkPopup();
                          final cleanText = isDate
                              ? rawTextForCopy
                              : actualLink
                                    .replaceFirst('tel:', '')
                                    .replaceFirst('mailto:', '');
                          await SharePlus.instance.share(
                            ShareParams(text: cleanText),
                          );
                        },
                        icon: const Icon(
                          Icons.share,
                          size: 18,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Share',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_linkPopup!);
  }

  // 🌟 Modify linkActionPickerDelegate to swallow native taps so our Overlay handles everything
  Future<LinkMenuAction> _handleLinkActionPicker(
    BuildContext context,
    String link,
    Node node,
  ) async {
    return LinkMenuAction.none;
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

        // 🌟 Your original custom style builder to format links properly
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

        // 🌟 Your original text block typographies
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
