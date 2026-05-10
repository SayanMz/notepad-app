import 'dart:async';

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// UI NOTIFIER CONTRACT
/// ---------------------------------------------------------------------------
abstract class UiNotifier {
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey;
  void showSnackBar(SnackBar snackBar, {Duration? autoHideAfter});
  void clearSnackBars();
  void hideCurrentSnackBar();
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class ScaffoldMessengerUiNotifier implements UiNotifier {
  ScaffoldMessengerUiNotifier();

  Timer? _snackBarTimer;

  @override
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey =>
      rootScaffoldMessengerKey;

  ScaffoldMessengerState? get _messenger =>
      rootScaffoldMessengerKey.currentState;

  void _cancelTimer() {
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
  }

  @override
  void showSnackBar(SnackBar snackBar, {Duration? autoHideAfter}) {
    final messenger = _messenger;
    if (messenger == null) return;

    _cancelTimer();
    messenger
      ..clearSnackBars()
      ..showSnackBar(snackBar);

    if (autoHideAfter != null) {
      _snackBarTimer = Timer(autoHideAfter, messenger.hideCurrentSnackBar);
    }
  }

  @override
  void clearSnackBars() {
    _cancelTimer();
    _messenger?.clearSnackBars();
  }

  @override
  void hideCurrentSnackBar() {
    _cancelTimer();
    _messenger?.hideCurrentSnackBar();
  }
}

final UiNotifier uiNotifier = ScaffoldMessengerUiNotifier();

void showSuccessSnackBar(String message, {Duration? autoHideAfter}) {
  uiNotifier.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green.shade700,
      duration: autoHideAfter ?? const Duration(seconds: 2),
    ),
    autoHideAfter: autoHideAfter,
  );
}

void showErrorSnackBar(String message, {Duration? autoHideAfter}) {
  uiNotifier.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red.shade700,
      duration: autoHideAfter ?? const Duration(seconds: 2),
    ),
    autoHideAfter: autoHideAfter,
  );
}

void showRootSnackBar(SnackBar snackBar, {Duration? autoHideAfter}) {
  uiNotifier.showSnackBar(snackBar, autoHideAfter: autoHideAfter);
}
