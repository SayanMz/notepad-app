import 'package:flutter/material.dart';

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
    // Controls the speed of the spin. Smaller duration = faster spin!
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // The .repeat() makes it loop infinitely
  }

  @override
  void dispose() {
    _controller.dispose(); // Always dispose controllers to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: RotationTransition(
        turns: _controller,
        child: const Icon(
          Icons.sync,
          color: Colors.lightBlueAccent, // Matches your progress bar color
        ),
      ),
    );
  }
}
