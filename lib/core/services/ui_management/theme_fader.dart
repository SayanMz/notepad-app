// Theme swaps capture the current frame so the transition can fade cleanly.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/animation_constants.dart';

class ThemeFader {
  static final GlobalKey appBoundaryKey = GlobalKey();

  static final ValueNotifier<bool> isTransitioning = ValueNotifier<bool>(false);

  static Future<void> captureAndFade({
    required BuildContext context,
    required VoidCallback executeThemeSwap,
  }) async {
    // Prevent overlapping theme transitions from stacking multiple overlays.
    if (isTransitioning.value) return;
    isTransitioning.value = true;

    RenderObject? renderObject = appBoundaryKey.currentContext
        ?.findRenderObject();

    while (renderObject != null && renderObject is! RenderRepaintBoundary) {
      if (renderObject is RenderProxyBox) {
        renderObject = renderObject.child;
      } else {
        break;
      }
    }
    final boundary = renderObject as RenderRepaintBoundary?;
    if (boundary == null) {
      // If the boundary is unavailable, swap immediately instead of hanging the UI.
      debugPrint(
        'ThemeFader: Could not locate RenderRepaintBoundary. Swapping instantly.',
      );
      executeThemeSwap();
      return;
    }

    final navigator = Navigator.of(context);
    final overlay = Overlay.of(context);
    final pixelRatio = View.of(context).devicePixelRatio;

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

    late OverlayEntry overlayEntry;
    final animationController = AnimationController(
      vsync: navigator,
      duration: AnimationConstants.slow,
    );

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: IgnorePointer(
          child: FadeTransition(
            opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
              CurvedAnimation(
                parent: animationController,
                curve: Curves.easeOut,
              ),
            ),
            child: RawImage(image: image, fit: BoxFit.cover),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Defer the actual theme swap until the overlay is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      executeThemeSwap();

      await Future.delayed(AnimationConstants.fast);

      await animationController.forward();

      overlayEntry.remove();
      animationController.dispose();
      image.dispose();

      isTransitioning.value = false;
    });
  }
}
