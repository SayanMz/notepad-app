import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/features/home/home_constants.dart';

/// Presentation helper managing scroll-driven collapse, alignment shifts,
/// and drag gestures for the Home Floating Action Button.
class HomeFabController {
  final ValueNotifier<bool> isExtended = ValueNotifier(true);
  final ValueNotifier<double> alignX = ValueNotifier(
    HomeConstants.fabAlignExpandedX,
  );

  /// Accumulates scroll distance across frames to prevent micro-scroll jitter.
  double _accumulatedDelta = 0.0;

  /// Synchronizes expansion state with horizontal alignment.
  void updateState({required bool extend}) {
    if (isExtended.value == extend) return;

    isExtended.value = extend;
    alignX.value = extend
        ? HomeConstants.fabAlignExpandedX
        : HomeConstants.fabAlignCollapsedX;
  }

  /// Processes viewport scroll notifications to expand/collapse the FAB.
  bool handleScroll(
    Notification notification, {
    required bool isSelectionMode,
  }) {
    if (isSelectionMode) return false;

    // Reset distance on scroll end
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.idle) {
      _accumulatedDelta = 0.0;
      return true;
    }

    if (notification is ScrollUpdateNotification) {
      // Force expand when scrolled near the top
      if (notification.metrics.pixels <= HomeConstants.homeTopSnapThreshold) {
        updateState(extend: true);
        _accumulatedDelta = 0.0;
        return true;
      }

      if (notification.metrics.outOfRange) return false;

      final double delta = notification.scrollDelta ?? 0.0;

      // Reset accumulator on direction change
      if ((delta > 0 && _accumulatedDelta < 0) ||
          (delta < 0 && _accumulatedDelta > 0)) {
        _accumulatedDelta = 0.0;
      }

      _accumulatedDelta += delta;

      const double threshold = HomeConstants.homeBulkDeleteThreshold;

      // Toggle state when accumulated scroll exceeds threshold distance
      if (_accumulatedDelta > threshold) {
        updateState(extend: false);
        _accumulatedDelta = 0.0;
      } else if (_accumulatedDelta < -threshold) {
        updateState(extend: true);
        _accumulatedDelta = 0.0;
      }
    }

    return true;
  }

  void dispose() {
    isExtended.dispose();
    alignX.dispose();
  }
}
