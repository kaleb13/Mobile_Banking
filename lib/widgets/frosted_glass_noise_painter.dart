import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted Glass Micro-Noise ("Ash" / Grain) CustomPainter.
///
/// Renders subtle pseudo-random noise points across the canvas to break
/// gradient banding and give ambient cards a frosted, textured surface.
class FrostedGlassNoisePainter extends CustomPainter {
  final int pointCount;
  final double lightAlpha;
  final double darkAlpha;

  const FrostedGlassNoisePainter({
    this.pointCount = 700,
    this.lightAlpha = 0.07,
    this.darkAlpha = 0.07,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rand = Random(42);
    final paintLight = Paint()
      ..color = Colors.white.withValues(alpha: lightAlpha)
      ..strokeWidth = 1.0;
    final paintDark = Paint()
      ..color = Colors.black.withValues(alpha: darkAlpha)
      ..strokeWidth = 1.0;

    final pointsLight = <Offset>[];
    final pointsDark = <Offset>[];

    for (int i = 0; i < pointCount; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      if (i % 2 == 0) {
        pointsLight.add(Offset(dx, dy));
      } else {
        pointsDark.add(Offset(dx, dy));
      }
    }

    canvas.drawPoints(PointMode.points, pointsLight, paintLight);
    canvas.drawPoints(PointMode.points, pointsDark, paintDark);
  }

  @override
  bool shouldRepaint(covariant FrostedGlassNoisePainter oldDelegate) =>
      oldDelegate.pointCount != pointCount ||
      oldDelegate.lightAlpha != lightAlpha ||
      oldDelegate.darkAlpha != darkAlpha;
}
