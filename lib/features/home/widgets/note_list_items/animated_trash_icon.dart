import 'package:flutter/material.dart';

class AnimatedTrashIcon extends StatelessWidget {
  const AnimatedTrashIcon({
    super.key,
    required this.lidProgress,
    required this.color,
    this.size = 28.0,
  });

  final double lidProgress;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final yOffset = lidProgress * -5;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: 2,
            child: Container(
              width: size * 0.55,
              height: size * 0.60,
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 2.0),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(width: 1.5, height: size * 0.3, color: color),
                  Container(width: 1.5, height: size * 0.3, color: color),
                ],
              ),
            ),
          ),
          Positioned(
            top: size * 0.15,
            child: Transform.translate(
              offset: Offset(0, yOffset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size * 0.2,
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    width: size * 0.75,
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
