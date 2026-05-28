import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notepad/core/services/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/controllers/selection_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/widgets/selection_tools/selection_toolbar.dart';

// Location: selection_overlay.dart

class SelectionOverlay extends StatelessWidget {
  final HomeController controller;
  final SelectionController selectionController;
  const SelectionOverlay({
    super.key,
    required this.controller,
    required this.selectionController,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final radius = BorderRadius.circular(HomeConstants.selectionOverlayRadius);
    final surfaceColor = isDark
        ? Colors.black.withValues(
            alpha: HomeConstants.selectionOverlayDarkAlpha,
          )
        : Colors.white.withValues(
            alpha: HomeConstants.selectionOverlayLightAlpha,
          );
    final borderColor = Colors.white.withValues(
      alpha: HomeConstants.selectionOverlayBorderAlpha,
    );

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final isActive = selectionController.isSelectionMode;

        return Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            ignoring: !isActive,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(
                begin: isActive ? 0.0 : 1.0,
                end: isActive ? 0.0 : 1.0,
              ),
              builder: (context, hideFactor, child) {
                // 🌟 THE FIX: Removed the Opacity wrapper completely.
                // Now it just translates. The container remains at its native
                // opacity level instantly from frame 1, killing the glass fade effect!
                return FractionalTranslation(
                  translation: Offset(0, hideFactor * 1.2),
                  child: child,
                );
              },
              child: SafeArea(
                key: const ValueKey('selection_toolbar_active'),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: HomeConstants.selectionOverlayPaddingL,
                    right: HomeConstants.selectionOverlayPaddingR,
                    bottom: HomeConstants.selectionOverlayPaddingB,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: HomeConstants.selectionOverlayShadowAlpha,
                          ),
                          blurRadius: HomeConstants.selectionOverlayShadowBlur,
                          spreadRadius: 0,
                          offset: Offset(
                            0,
                            HomeConstants.selectionOverlayShadowOffsetY,
                          ),
                        ),
                      ],
                      border: Border.all(
                        color: borderColor,
                        width: HomeConstants.selectionOverlayBorderWidth,
                      ),
                    ),
                    child: RepaintBoundary(
                      child: ClipRRect(
                        borderRadius: radius,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: HomeConstants.selectionOverlayBlurSigma,
                            sigmaY: HomeConstants.selectionOverlayBlurSigma,
                          ),
                          child: Container(
                            decoration: BoxDecoration(color: surfaceColor),
                            child: SelectionToolbar(
                              controller: controller,
                              selectionController: selectionController,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
