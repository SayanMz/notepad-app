import 'package:flutter/material.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/note/widgets/editor/link_menu_bar.dart';
import 'package:notepad/features/note/services/links/link_service.dart';

// Manages overlay state and popup lifecycle for interactive link action menus in note views.
class NoteLinkHandler {
  final NoteLinkService _linkService;

  NoteLinkHandler({NoteLinkService? linkService})
    : _linkService = linkService ?? const NoteLinkService();

  String? _activeLink;
  OverlayEntry? _linkPopup;

  String? get activeLink => _activeLink;
  bool get isPopupActive => _linkPopup != null;

  void removeLinkPopup() {
    final entry = _linkPopup;
    if (entry != null && entry.mounted) {
      entry.remove();
    }
    _linkPopup = null;
    _activeLink = null;
  }

  void showHorizontalLinkMenu(
    BuildContext context,
    String actualLink,
    bool isDark,
  ) {
    removeLinkPopup();
    _activeLink = actualLink;

    final data = _linkService.parse(actualLink);
    final cleanText = _linkService.extractCleanText(data);
    final overlay = Overlay.of(context, rootOverlay: true);

    _linkPopup = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            top: context.topPadding + 80,
            left: 20,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: LinkMenuBar(
                type: data.type,
                isDark: isDark,
                onOpen: () async {
                  removeLinkPopup();
                  await _linkService.openLink(data);
                },
                onCopy: () async {
                  removeLinkPopup();
                  await _linkService.copyText(cleanText);
                },
                onShare: () async {
                  removeLinkPopup();
                  await _linkService.shareText(cleanText);
                },
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_linkPopup!);
  }
}
