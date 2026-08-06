import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:notepad/core/extensions/context_extensions.dart';
import 'package:notepad/core/theme/app_colors.dart';

class ScrollToTopFab extends StatefulWidget {
  const ScrollToTopFab({
    required this.scrollController,
    required this.heroTag,
    required this.behavior,
    this.additionalCondition = true, //For Search Page
    this.onPressed,
    super.key,
  });

  final ScrollController scrollController;
  final String heroTag;
  final FabScrollBehavior behavior;
  final bool additionalCondition;
  final VoidCallback? onPressed;

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _isVisible = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleScroll() {
    final position = widget.scrollController.position;

    // ---------------------------------------------------------
    // GAME RULE 1: Absolute Boundary Gate
    // ---------------------------------------------------------
    final pastThreshold = position.pixels > 200.0;
    if (!pastThreshold) {
      _debounceTimer?.cancel();
      if (_isVisible) setState(() => _isVisible = false);
      return; // Exit early! Nothing else matters if we are near the top.
    }

    // ---------------------------------------------------------
    // GAME RULE 2: Active Scroll Direction Management
    // ---------------------------------------------------------
    final direction = position.userScrollDirection;

    if (direction == ScrollDirection.reverse && _isVisible) {
      setState(
        () => _isVisible = false,
      ); // Hides immediately when scrolling down
    } else if (direction == ScrollDirection.forward && !_isVisible) {
      setState(() => _isVisible = true); // Shows immediately when scrolling up
    }

    // ---------------------------------------------------------
    // GAME RULE 3: Idle Timeout Override
    // ---------------------------------------------------------
    if (widget.behavior == FabScrollBehavior.autoDimOnIdle) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && _isVisible) setState(() => _isVisible = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final bool fullyVisible = _isVisible && widget.additionalCondition;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: AnimatedOpacity(
          opacity: fullyVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: IgnorePointer(
            ignoring: !fullyVisible,
            child: FloatingActionButton.small(
              heroTag: widget.heroTag,
              backgroundColor: isDark
                  ? AppColors.recycleFabBgDark
                  : AppColors.recycleFabBgLight,
              foregroundColor: isDark
                  ? AppColors.recycleFabFgDark
                  : AppColors.recycleFabFgLight,
              onPressed: () {
                widget.scrollController.animateTo(
                  0.0,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.fastOutSlowIn,
                );
                widget.onPressed?.call();
              },
              child: const Icon(Icons.arrow_upward),
            ),
          ),
        ),
      ),
    );
  }
}

enum FabScrollBehavior {
  /// The button fades away after inactivity to clear visual space.
  autoDimOnIdle,

  /// The button stays anchored on screen as long as the user is past the threshold.
  persistentWhileScrolling,
}
