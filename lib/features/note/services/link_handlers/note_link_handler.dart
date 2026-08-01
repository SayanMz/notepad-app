import 'dart:io';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Needed for Clipboard
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Handles note link actions, including popup display, open, copy, share, and calendar/phone launching.
class NoteLinkHandler {
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

    final isDate = actualLink.startsWith('cal:');
    var actionCode = actualLink;
    var rawTextForCopy = '';

    if (isDate) {
      final parts = actualLink.split('|'); //eg: cal:20260412|April 12, 2026
      actionCode = parts[0].replaceFirst('cal:', ''); // Yields: 20260412
      if (parts.length > 1) rawTextForCopy = parts[1]; // Yields: April 12, 2026
    }

    var primaryLabel = 'Open';
    var primaryIcon = Icons.language;

    if (actualLink.startsWith('tel:')) {
      primaryLabel = 'Call';
      primaryIcon = Icons.phone;
    } else if (actualLink.startsWith('mailto:')) {
      primaryLabel = 'Gmail';
      primaryIcon = Icons.mail;
    } else if (isDate) {
      primaryLabel = 'Add Event';
      primaryIcon = Icons.edit_calendar;
    }

    final overlay = Overlay.of(context, rootOverlay: true);

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
                          removeLinkPopup();
                          await _openLink(actualLink, isDate, actionCode);
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
                          removeLinkPopup();
                          // 🌟 Ensures they copy "April 12" and not the hidden machine code
                          final cleanText = _extractCleanLinkText(
                            actualLink,
                            isDate: isDate,
                            rawTextForCopy: rawTextForCopy,
                          );
                          await _copyLinkText(cleanText);
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
                          removeLinkPopup();
                          final cleanText = _extractCleanLinkText(
                            actualLink,
                            isDate: isDate,
                            rawTextForCopy: rawTextForCopy,
                          );
                          await _shareLinkText(cleanText);
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
    overlay.insert(_linkPopup!);
  }

  String _extractCleanLinkText(
    String actualLink, {
    required bool isDate,
    required String rawTextForCopy,
  }) {
    if (isDate) {
      return rawTextForCopy.isNotEmpty ? rawTextForCopy : actualLink;
    }
    return actualLink.replaceFirst('tel:', '').replaceFirst('mailto:', '');
  }

  void _showLinkActionError(String message) {
    showErrorSnackBar(message);
  }

  Future<void> _launchUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    required String errorMessage,
  }) async {
    try {
      final launched = await launchUrl(uri, mode: mode);
      if (!launched) _showLinkActionError(errorMessage);
    } catch (_) {
      _showLinkActionError(errorMessage);
    }
  }

  Future<void> _openLink(
    String actualLink,
    bool isDate,
    String actionCode,
  ) async {
    if (actualLink.startsWith('tel:')) {
      final number = actualLink.replaceFirst('tel:', '');
      await _launchUri(
        Uri(scheme: 'tel', path: number),
        errorMessage: 'Could not open the phone app.',
      );
      return;
    }

    if (actualLink.startsWith('mailto:')) {
      final email = actualLink.replaceFirst('mailto:', '');
      await _openMailLink(email);
      return;
    }

    if (isDate) {
      // Extract the exact date properties
      await _openCalendarLink(actionCode);
      return;
    }

    final uri = Uri.tryParse(actualLink);
    if (uri == null || !uri.hasScheme) {
      _showLinkActionError('This link is invalid.');
      return;
    }

    await _launchUri(
      uri,
      mode: LaunchMode.externalApplication,
      errorMessage: 'Could not open this link.',
    );
  }

  Future<void> _openMailLink(String email) async {
    final encodedEmail = Uri.encodeComponent(email);
    final androidIntent = Uri.parse(
      'intent://co?to=$encodedEmail#Intent;scheme=googlegmail;package=com.google.android.gm;end',
    );
    final iosScheme = Uri.parse('googlegmail:///co?to=$encodedEmail');
    final mailtoUri = Uri(scheme: 'mailto', path: email);

    try {
      if (await canLaunchUrl(androidIntent)) {
        await _launchUri(androidIntent, errorMessage: 'Could not open Gmail.');
      } else if (await canLaunchUrl(iosScheme)) {
        await _launchUri(iosScheme, errorMessage: 'Could not open Gmail.');
      } else {
        await _launchUri(
          mailtoUri,
          mode: LaunchMode.externalApplication,
          errorMessage: 'Could not open the mail app.',
        );
      }
    } catch (_) {
      _showLinkActionError('Could not open the mail app.');
    }
  }

  Future<void> _openCalendarLink(String actionCode) async {
    final eventDate = _parseCalendarDate(actionCode);
    if (eventDate == null) {
      _showLinkActionError('This calendar link is invalid.');
      return;
    }

    final epochMs = eventDate.millisecondsSinceEpoch;

    try {
      if (Platform.isAndroid) {
        // Direct Hardware Intent Pipeline for Android
        final AndroidIntent intent = AndroidIntent(
          action: 'android.intent.action.INSERT',
          data: 'content://com.android.calendar/events',
          type: 'vnd.android.cursor.dir/event',
          arguments: <String, dynamic>{
            'title': 'New Event',
            'beginTime': epochMs,
            'endTime': epochMs + 3600000, // +1 hour duration default
          },
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        // Official System Calendar Deep Link for iOS
        final epochSecs = epochMs ~/ 1000;
        final iosUri = Uri.parse('calshow:$epochSecs');
        await _launchUri(
          iosUri,
          mode: LaunchMode.externalApplication,
          errorMessage: 'Could not open the Calendar app.',
        );
      } else {
        _showLinkActionError(
          'Calendar links are not supported on this device.',
        );
      }
    } catch (_) {
      _showLinkActionError('Could not open the Calendar app.');
    }
  }

  DateTime? _parseCalendarDate(String actionCode) {
    final calendarCodePattern = RegExp(r'^\d{8}$');
    if (!calendarCodePattern.hasMatch(actionCode)) return null;

    final year = int.tryParse(actionCode.substring(0, 4));
    final month = int.tryParse(actionCode.substring(4, 6));
    final day = int.tryParse(actionCode.substring(6, 8));

    if (year == null || month == null || day == null) return null;

    final eventDate = DateTime(year, month, day);
    if (eventDate.year != year ||
        eventDate.month != month ||
        eventDate.day != day) {
      return null;
    }
    return eventDate;
  }

  Future<void> _copyLinkText(String cleanText) async {
    try {
      await Clipboard.setData(ClipboardData(text: cleanText));
    } catch (_) {
      _showLinkActionError('Could not copy this link.');
    }
  }

  Future<void> _shareLinkText(String cleanText) async {
    try {
      await SharePlus.instance.share(ShareParams(text: cleanText));
    } catch (_) {
      _showLinkActionError('Could not share this link.');
    }
  }
}
