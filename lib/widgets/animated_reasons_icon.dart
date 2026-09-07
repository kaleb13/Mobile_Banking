import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Micro-animated Reasons (Category) Icon composed of the classic triad:
/// 1. Top Triangle
/// 2. Bottom-Left Circle
/// 3. Bottom-Right Rounded Rectangle
///
/// Features smooth, staggered phase-delayed micro-animations (scale, rotation, float)
/// that create an elegant organic breathing wave across the three geometric shapes.
class AnimatedReasonsIcon extends StatefulWidget {
  final double size;
  final Color? color;

  const AnimatedReasonsIcon({
    super.key,
    this.size = 13.0,
    this.color,
  });

  @override
  State<AnimatedReasonsIcon> createState() => _AnimatedReasonsIconState();
}

class _AnimatedReasonsIconState extends State<AnimatedReasonsIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.color ?? AppColors.textPrimary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ReasonsIconPainter(
            progress: _controller.value,
            color: effectiveColor,
          ),
        );
      },
    );
  }
}

class _ReasonsIconPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ReasonsIconPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Stroke paint to give crisp softly-rounded corners to the triangle
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, w * 0.05)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final t = progress * 2 * math.pi;

    // ── 1. Top Triangle (Phase 0: Leading) ──────────────────────────────────
    final trianglePhase = t;
    final triangleWave = math.sin(trianglePhase);
    final triangleScale = 1.0 + 0.16 * triangleWave;
    final triangleRot = 0.10 * triangleWave;
    final triangleDy = -0.6 * triangleWave;

    final triangleCenterX = w * 0.50;
    final triangleCenterY = h * 0.27;

    canvas.save();
    canvas.translate(triangleCenterX, triangleCenterY + triangleDy);
    canvas.rotate(triangleRot);
    canvas.scale(triangleScale);
    canvas.translate(-triangleCenterX, -triangleCenterY);

    final trianglePath = Path()
      ..moveTo(w * 0.50, h * 0.09)
      ..lineTo(w * 0.76, h * 0.44)
      ..lineTo(w * 0.24, h * 0.44)
      ..close();

    canvas.drawPath(trianglePath, paint);
    canvas.drawPath(trianglePath, strokePaint);
    canvas.restore();

    // ── 2. Bottom-Left Circle (Phase 120°: Staggered Delay) ────────────────
    final circlePhase = t - (2 * math.pi / 3);
    final circleWave = math.sin(circlePhase);
    final circleScale = 1.0 + 0.20 * circleWave;
    final circleDx = -0.4 * circleWave;

    final circleCenterX = w * 0.27;
    final circleCenterY = h * 0.74;
    final circleRadius = w * 0.185;

    canvas.save();
    canvas.translate(circleCenterX + circleDx, circleCenterY);
    canvas.scale(circleScale);
    canvas.drawCircle(Offset.zero, circleRadius, paint);
    canvas.restore();

    // ── 3. Bottom-Right Rounded Square (Phase 240°: Trailing Delay) ───────
    final rectPhase = t - (4 * math.pi / 3);
    final rectWave = math.sin(rectPhase);
    final rectScale = 1.0 + 0.16 * rectWave;
    final rectRot = -0.10 * rectWave;
    final rectDy = 0.5 * rectWave;

    final rectCenterX = w * 0.73;
    final rectCenterY = h * 0.74;
    final rectSize = w * 0.36;
    final rectRadius = Radius.circular(math.max(1.0, w * 0.08));

    canvas.save();
    canvas.translate(rectCenterX, rectCenterY + rectDy);
    canvas.rotate(rectRot);
    canvas.scale(rectScale);

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: rectSize,
        height: rectSize,
      ),
      rectRadius,
    );

    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ReasonsIconPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
