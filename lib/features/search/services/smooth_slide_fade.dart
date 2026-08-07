import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

// Combines slide and fade transitions natively
class SmoothSlideFade extends StatefulWidget {
  final Widget child;
  final bool isVisible;
  final double? minHeight;

  const SmoothSlideFade({
    super.key,
    required this.child,
    required this.isVisible,
    this.minHeight,
  });

  @override
  State<SmoothSlideFade> createState() => _SmoothSlideFadeState();
}

class _SmoothSlideFadeState extends State<SmoothSlideFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: AnimationConstants.slow,
      reverseDuration: AnimationConstants.snappy,
      value: widget.isVisible ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(SmoothSlideFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smoothly reverse or forward the animation from its exact current tick
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SizeTransition(
        sizeFactor: _animation,
        alignment: Alignment.topCenter,
        child: RepaintBoundary(
          child: IgnorePointer(
            ignoring: !widget.isVisible,
            child: SizedBox(
              height: widget.minHeight,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
