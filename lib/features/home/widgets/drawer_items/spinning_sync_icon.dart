import 'package:flutter/material.dart';
import 'package:notepad/core/constants/animation_constants.dart';

class SpinningSyncIcon extends StatefulWidget {
  const SpinningSyncIcon({super.key});

  @override
  State<SpinningSyncIcon> createState() => _SpinningSyncIconState();
}

class _SpinningSyncIconState extends State<SpinningSyncIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AnimationConstants.snackbarShort,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: const Icon(
          Icons.sync,
          color: Colors.lightBlueAccent,
        ),
      ),
    );
  }
}
