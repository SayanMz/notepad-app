import 'package:flutter/material.dart';

// Drag handle gives the search results list a compact scroll grip.
class SearchDragHandle extends StatelessWidget {
  const SearchDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 65,
      child: CustomPaint(
        painter: DragTabPainter(
          color: Color(0xFFAAB2C0),
          gripColor: Color(0xFF7E8694),
        ),
      ),
    );
  }
}

class DragTabPainter extends CustomPainter {
  final Color color;
  final Color gripColor;

  const DragTabPainter({required this.color, required this.gripColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    path.moveTo(size.width, 0);
    path.cubicTo(
      0,
      size.height * 0.15,
      0,
      size.height * 0.85,
      size.width,
      size.height,
    );

    path.close();
    canvas.drawPath(path, paint);

    final gripPaint = Paint()
      ..color = gripColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final double midX = size.width * 0.4;
    final double endX = size.width * 0.85;

    // Center tactile ridges
    canvas.drawLine(
      Offset(midX, size.height * 0.35),
      Offset(endX, size.height * 0.35),
      gripPaint,
    );
    canvas.drawLine(
      Offset(midX, size.height * 0.50),
      Offset(endX, size.height * 0.50),
      gripPaint,
    );
    canvas.drawLine(
      Offset(midX, size.height * 0.65),
      Offset(endX, size.height * 0.65),
      gripPaint,
    );
  }

  @override
  bool shouldRepaint(covariant DragTabPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.gripColor != gripColor;
  }
}
