import 'dart:async';

import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// UI NOTIFIER CONTRACT
/// ---------------------------------------------------------------------------
///
/// Defines an abstraction for app-wide UI notifications.
///
/// Responsibilities:
/// - Provide a consistent interface for showing SnackBars
/// - Decouple UI feedback from feature/business logic
/// - Allow cross-layer communication without BuildContext
///
/// Design:
/// - Interface-based (enables alternate implementations)
/// - Used across repositories, controllers, and UI layers
abstract class UiNotifier {
  /// Key used by MaterialApp to attach ScaffoldMessenger
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey;

  /// Displays a SnackBar
  ///
  /// Optional:
  /// - autoHideAfter → overrides default dismissal timing
  void showSnackBar(SnackBar snackBar, {Duration? autoHideAfter});

  /// Clears all active SnackBars
  void clearSnackBars();

  /// Hides currently visible SnackBar
  void hideCurrentSnackBar();
}

/// ---------------------------------------------------------------------------
/// GLOBAL SCAFFOLD MESSENGER KEY
/// ---------------------------------------------------------------------------
///
/// Shared key used by MaterialApp to enable global SnackBar access.
///
/// Purpose:
/// - Allows UI notifications without passing BuildContext
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// ---------------------------------------------------------------------------
/// DEFAULT UI NOTIFIER IMPLEMENTATION
/// ---------------------------------------------------------------------------
///
/// Concrete implementation using ScaffoldMessenger.
///
/// Responsibilities:
/// - Manage SnackBar lifecycle
/// - Prevent stacking of SnackBars
/// - Handle optional auto-dismiss behavior
///
/// Design:
/// - Uses internal timer for controlled dismissal
/// - Centralizes all SnackBar interactions
class ScaffoldMessengerUiNotifier implements UiNotifier {
  ScaffoldMessengerUiNotifier();

  /// Timer used for auto-hiding SnackBar
  Timer? _snackBarTimer;

  /// Provides global ScaffoldMessenger key
  @override
  GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey =>
      rootScaffoldMessengerKey;

  /// Accessor for current ScaffoldMessengerState
  ScaffoldMessengerState? get _messenger =>
      rootScaffoldMessengerKey.currentState;

  /// Cancels any active auto-hide timer
  void _cancelTimer() {
    _snackBarTimer?.cancel();
    _snackBarTimer = null;
  }

  /// Displays a SnackBar with optional auto-dismiss behavior
  ///
  /// Behavior:
  /// - Cancels previous timers
  /// - Clears existing SnackBars (prevents stacking)
  /// - Shows new SnackBar
  /// - Optionally schedules auto-hide
  @override
  void showSnackBar(SnackBar snackBar, {Duration? autoHideAfter}) {
    final messenger = _messenger;

    /// If messenger not ready, silently ignore
    if (messenger == null) return;

    _cancelTimer();

    messenger
      ..clearSnackBars()
      ..showSnackBar(snackBar);

    /// Schedule auto-hide if duration provided
    if (autoHideAfter != null) {
      _snackBarTimer = Timer(autoHideAfter, messenger.hideCurrentSnackBar);
    }
  }

  /// Clears all SnackBars and cancels timers
  @override
  void clearSnackBars() {
    _cancelTimer();
    _messenger?.clearSnackBars();
  }

  /// Hides current SnackBar and cancels timers
  @override
  void hideCurrentSnackBar() {
    _cancelTimer();
    _messenger?.hideCurrentSnackBar();
  }
}

/// ---------------------------------------------------------------------------
/// SHARED INSTANCE
/// ---------------------------------------------------------------------------
///
/// Default UiNotifier used across the application.
///
/// Note:
/// - Acts as a singleton-like instance
/// - Injected via AppDependencies
final UiNotifier uiNotifier = ScaffoldMessengerUiNotifier();

/// ---------------------------------------------------------------------------
/// HELPER FUNCTION (BACKWARD COMPATIBILITY)
/// ---------------------------------------------------------------------------
///
/// Convenience wrapper for showing SnackBars.
///
/// Purpose:
/// - Maintains compatibility with older code using global access
/// - Delegates internally to UiNotifier
void showRootSnackBar(SnackBar snackBar, {Duration? autoHideAfter}) {
  uiNotifier.showSnackBar(snackBar, autoHideAfter: autoHideAfter);
}
