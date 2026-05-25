import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/constants/animation_constants.dart';

class ThemeFader {
  /// The global key that wraps your entire app
  static final GlobalKey appBoundaryKey = GlobalKey();

  /// ⚡ THE LOCK INDICATOR: True when the GPU snapshot fade is active
  static final ValueNotifier<bool> isTransitioning = ValueNotifier<bool>(false);

  /// Orchestrates the GPU snapshot and crossfade
  static Future<void> captureAndFade({
    required BuildContext context,
    required VoidCallback executeThemeSwap,
  }) async {
    if (isTransitioning.value) return; // Prevent double-clicks
    isTransitioning.value = true;

    // 1. Grab whatever RenderObject the key is currently pointing to
    RenderObject? renderObject = appBoundaryKey.currentContext
        ?.findRenderObject();

    // 2. THE BULLETPROOF UNWRAPPER: Dig through hidden Semantics/Proxy layers
    // RenderSemanticsAnnotations inherits from RenderProxyBox, so we just ask for its child!
    while (renderObject != null && renderObject is! RenderRepaintBoundary) {
      if (renderObject is RenderProxyBox) {
        renderObject = renderObject.child;
      } else {
        break;
      }
    }
    // 1. TALK TO THE RENDER ENGINE: Find the physical screen bounds
    final boundary = renderObject as RenderRepaintBoundary?;
    if (boundary == null) {
      debugPrint(
        "ThemeFader: Could not locate RenderRepaintBoundary. Swapping instantly.",
      );
      executeThemeSwap();
      return;
    }

    final navigator = Navigator.of(context);
    final overlay = Overlay.of(context);
    final pixelRatio = View.of(context).devicePixelRatio;

    // 2. THE SNAPSHOT: Command the GPU to rasterize the current UI into a raw image
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

    // 3. THE MASK: Create a temporary full-screen overlay holding our photograph
    late OverlayEntry overlayEntry;
    final animationController = AnimationController(
      vsync: navigator, // Ties animation to the routing ticker
      duration: AnimationConstants.slow,
    );

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        // IgnorePointer ensures the user can't accidentally click the photograph
        child: IgnorePointer(
          child: FadeTransition(
            // Fade from 1.0 (Opaque) down to 0.0 (Transparent)
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

    // 4. INJECT THE MASK
    overlay.insert(overlayEntry);

    // 5. SWAP THE THEME: This calculations happen instantly underneath the mask
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Now that the photograph is safely covering the screen, we swap the theme underneath it!
      executeThemeSwap();

      // Brief pause to let the new dark theme build its layout
      await Future.delayed(AnimationConstants.fast);

      // Fade out the photograph
      await animationController.forward();

      // Garbage Collection: Prevent memory leaks
      overlayEntry.remove();
      animationController.dispose();
      image.dispose(); // CRITICAL: Free the heavy GPU texture from RAM

      isTransitioning.value = false;
    });
  }
}
