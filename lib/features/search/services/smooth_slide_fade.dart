import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

class SmoothSlideFade extends StatefulWidget {
  final Widget child;
  final bool showTopBars;

  const SmoothSlideFade({
    super.key,
    required this.child,
    required this.showTopBars,
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
      value: widget.showTopBars ? 1.0 : 0.0,
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
    if (widget.showTopBars != oldWidget.showTopBars) {
      widget.showTopBars ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _animation,
        child: RepaintBoundary(
          child: IgnorePointer(
            ignoring: !widget.showTopBars,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
