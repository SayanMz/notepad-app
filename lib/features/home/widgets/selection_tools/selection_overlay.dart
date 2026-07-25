import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/features/home/controllers/home_controller.dart';
import 'package:notepad/features/home/home_constants.dart';
import 'package:notepad/features/home/widgets/selection_tools/selection_toolbar.dart';

// Bottom overlay that shows the selection toolbar with a blurred panel.
class SelectionOverlay extends StatelessWidget {
  const SelectionOverlay({super.key, required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final isActive = controller.selectionController.isSelectionMode;

    return Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        ignoring: !isActive,
        child: AnimatedSlide(
          offset: isActive ? Offset.zero : const Offset(0, 1.8),
          duration: AnimationConstants.medium,
          curve: Curves.fastOutSlowIn,
          child: _SelectionOverlayContent(controller: controller),
        ),
      ),
    );
  }
}

class _SelectionOverlayContent extends StatelessWidget {
  const _SelectionOverlayContent({required this.controller});

  final HomeController controller;

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

    return SafeArea(
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
                offset: Offset(0, HomeConstants.selectionOverlayShadowOffsetY),
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
                  color: surfaceColor,
                  child: SelectionToolbar(controller: controller),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
