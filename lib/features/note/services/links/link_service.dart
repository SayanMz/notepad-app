import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum NoteLinkType { phone, mail, calendar, web }

// Parses detected note link targets and executes platform actions for phone, email, calendar, and web URIs.
class NoteLinkActionData {
  final String actualLink;
  final String actionCode;
  final String rawTextForCopy;
  final NoteLinkType type;

  const NoteLinkActionData({
    required this.actualLink,
    required this.actionCode,
    required this.rawTextForCopy,
    required this.type,
  });
}

class NoteLinkService {
  const NoteLinkService();

  NoteLinkActionData parse(String rawLink) {
    final isDate = rawLink.startsWith('cal:');
    var actionCode = rawLink;
    var rawTextForCopy = '';

    if (isDate) {
      final parts = rawLink.split('|');
      actionCode = parts[0].replaceFirst('cal:', '');
      if (parts.length > 1) rawTextForCopy = parts[1];
      return NoteLinkActionData(
        actualLink: rawLink,
        actionCode: actionCode,
        rawTextForCopy: rawTextForCopy,
        type: NoteLinkType.calendar,
      );
    }

    if (rawLink.startsWith('tel:')) {
      return NoteLinkActionData(
        actualLink: rawLink,
        actionCode: actionCode,
        rawTextForCopy: rawTextForCopy,
        type: NoteLinkType.phone,
      );
    }

    if (rawLink.startsWith('mailto:')) {
      return NoteLinkActionData(
        actualLink: rawLink,
        actionCode: actionCode,
        rawTextForCopy: rawTextForCopy,
        type: NoteLinkType.mail,
      );
    }

    return NoteLinkActionData(
      actualLink: rawLink,
      actionCode: actionCode,
      rawTextForCopy: rawTextForCopy,
      type: NoteLinkType.web,
    );
  }

  String extractCleanText(NoteLinkActionData data) {
    if (data.type == NoteLinkType.calendar) {
      return data.rawTextForCopy.isNotEmpty
          ? data.rawTextForCopy
          : data.actualLink;
    }
    return data.actualLink.replaceFirst('tel:', '').replaceFirst('mailto:', '');
  }

  Future<void> openLink(NoteLinkActionData data) async {
    switch (data.type) {
      case NoteLinkType.phone:
        final number = data.actualLink.replaceFirst('tel:', '');
        await _launchUri(
          Uri(scheme: 'tel', path: number),
          errorMessage: 'Could not open the phone app.',
        );
        break;

      case NoteLinkType.mail:
        final email = data.actualLink.replaceFirst('mailto:', '');
        await _openMailLink(email);
        break;

      case NoteLinkType.calendar:
        await _openCalendarLink(data.actionCode);
        break;

      case NoteLinkType.web:
        String normalized = data.actualLink.trim();
        if (!normalized.contains('://') &&
            !normalized.startsWith('mailto:') &&
            !normalized.startsWith('tel:')) {
          normalized = 'https://$normalized';
        }

        final uri = Uri.tryParse(normalized);
        if (uri == null || !uri.hasScheme) {
          showErrorSnackBar('This link is invalid.');
          return;
        }

        await _launchUri(
          uri,
          mode: LaunchMode.externalApplication,
          errorMessage: 'Could not open this link.',
        );
        break;
    }
  }

  Future<void> copyText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      showErrorSnackBar('Could not copy this link.');
    }
  }

  Future<void> shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      showErrorSnackBar('Could not share this link.');
    }
  }

  Future<void> _launchUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.platformDefault,
    required String errorMessage,
  }) async {
    try {
      final launched = await launchUrl(uri, mode: mode);
      if (!launched) showErrorSnackBar(errorMessage);
    } catch (_) {
      showErrorSnackBar(errorMessage);
    }
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
      showErrorSnackBar('Could not open the mail app.');
    }
  }

  Future<void> _openCalendarLink(String actionCode) async {
    final eventDate = _parseCalendarDate(actionCode);
    if (eventDate == null) {
      showErrorSnackBar('This calendar link is invalid.');
      return;
    }

    final epochMs = eventDate.millisecondsSinceEpoch;

    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.INSERT',
          data: 'content://com.android.calendar/events',
          type: 'vnd.android.cursor.dir/event',
          arguments: <String, dynamic>{
            'title': 'New Event',
            'beginTime': epochMs,
            'endTime': epochMs + 3600000,
          },
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        final epochSecs = epochMs ~/ 1000;
        await _launchUri(
          Uri.parse('calshow:$epochSecs'),
          mode: LaunchMode.externalApplication,
          errorMessage: 'Could not open the Calendar app.',
        );
      } else {
        showErrorSnackBar('Calendar links are not supported on this device.');
      }
    } catch (_) {
      showErrorSnackBar('Could not open the Calendar app.');
    }
  }

  DateTime? _parseCalendarDate(String actionCode) {
    if (!RegExp(r'^\d{8}$').hasMatch(actionCode)) return null;

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
}
