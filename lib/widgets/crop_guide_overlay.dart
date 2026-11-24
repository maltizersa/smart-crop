import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dims everything outside the centered square and marks its corners.
///
/// The square is the largest centered square of the area, which is exactly
/// the part of the photo the model sees (the preprocessor center-crops the
/// same way). Place it over a camera preview that has the photo's aspect ratio.
class CropGuideOverlay extends StatelessWidget {
  const CropGuideOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _CropGuidePainter(), size: Size.infinite),
    );
  }
}

class _CropGuidePainter extends CustomPainter {
  const _CropGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final square = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );

    final shade = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(square);
    canvas.drawPath(shade, Paint()..color = Colors.black54);

    final corner = side * 0.12;
    final inner = square.deflate(6);
    final pen = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (point, dx, dy) in [
      (inner.topLeft, 1.0, 1.0),
      (inner.topRight, -1.0, 1.0),
      (inner.bottomLeft, 1.0, -1.0),
      (inner.bottomRight, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(point, point.translate(dx * corner, 0), pen)
        ..drawLine(point, point.translate(0, dy * corner), pen);
    }
  }

  @override
  bool shouldRepaint(_CropGuidePainter oldDelegate) => false;
}
