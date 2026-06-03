// Global snackbars need a stable messenger outside the widget tree.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/constants/editor_constants.dart';
import 'package:notepad/core/theme/app_colors.dart';

abstract class UiNotifier {
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey;
  void showSnackBar(SnackBar snackBar, {Duration? autoHideAfter});
  void clearSnackBars();
  void hideCurrentSnackBar();
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Central scaffold messenger access for snackbars shown outside widget scope.
class ScaffoldMessengerUiNotifier implements UiNotifier {
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
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);

    final dismissDuration = autoHideAfter ?? snackBar.duration;

    _snackBarTimer = Timer(dismissDuration, () {
      messenger.hideCurrentSnackBar();
    });
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


void showRestorationSnackBar({
  required String message,
  required VoidCallback onUndo,
  String undoLabel = 'Undo',
  Duration? duration,
}) {
  final snackDuration = duration ?? AnimationConstants.saveIndicator;

  uiNotifier.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: snackDuration,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 90.0),
      content: Row(
        children: [
          Expanded(child: Text(message)),
          _buildElevatedAction(undoLabel, onUndo),
        ],
      ),
    ),
    autoHideAfter: snackDuration,
  );
}

Widget _buildElevatedAction(String label, VoidCallback onTap) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        uiNotifier.hideCurrentSnackBar();
        onTap();
      },
      borderRadius: BorderRadius.circular(EditorConstants.snackbarActionRadius),
      splashColor: Colors.white.withValues(
        alpha: EditorConstants.snackbarActionSplashAlpha,
      ),
      child: Ink(
        padding: const EdgeInsets.symmetric(
          horizontal: EditorConstants.snackbarActionPaddingH,
          vertical: EditorConstants.snackbarActionPaddingV,
        ),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent,
          borderRadius: BorderRadius.circular(
            EditorConstants.snackbarActionRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: EditorConstants.snackbarActionShadowAlpha,
              ),
              blurRadius: EditorConstants.snackbarActionShadowBlur,
              offset: Offset(0, EditorConstants.snackbarActionShadowOffsetY),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: EditorConstants.snackbarActionFontSize,
          ),
        ),
      ),
    ),
  );
}

void showSuccessSnackBar(String message, {Duration? duration}) {
  final d = duration ?? AnimationConstants.snackbarShort;
  uiNotifier.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.green.shade700,
      duration: d,
    ),
    autoHideAfter: d,
  );
}

void showErrorSnackBar(String message, {Duration? duration}) {
  final d = duration ?? AnimationConstants.snackbarLong;
  uiNotifier.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.deleteDarkIcon,
      duration: d,
    ),
    autoHideAfter: d,
  );
}

