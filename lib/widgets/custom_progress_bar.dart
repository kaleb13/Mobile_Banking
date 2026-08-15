import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Standard Design System Progress Bar Component
/// Single source of truth for all linear progress indicators across the app.
/// Matches the sleek, pill-shaped representation in Profile Hub.
class CustomProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? backgroundColor;
  final Gradient? progressGradient;
  final Color? progressColor;
  final String? centerLabel;
  final TextStyle? labelStyle;
  final bool labelInFilledOnly;
  final BorderRadius? borderRadius;
  final Duration animationDuration;
  final Curve animationCurve;

  const CustomProgressBar({
    super.key,
    required this.progress,
    this.height = 10.0,
    this.backgroundColor,
    this.progressGradient,
    this.progressColor,
    this.centerLabel,
    this.labelStyle,
    this.labelInFilledOnly = false,
    this.borderRadius,
    this.animationDuration = const Duration(milliseconds: 350),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(height / 2);
    final effectiveBg = backgroundColor ?? Colors.white.withValues(alpha: 0.08);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth =
            (totalWidth * clampedProgress).clamp(0.0, totalWidth);

        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: effectiveRadius,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Smooth animated filled bar portion
              ClipRRect(
                borderRadius: effectiveRadius,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: animationDuration,
                    curve: animationCurve,
                    width: filledWidth,
                    height: height,
                    decoration: BoxDecoration(
                      color: progressGradient == null
                          ? (progressColor ?? AppColors.positive)
                          : null,
                      gradient: progressGradient,
                      borderRadius: effectiveRadius,
                    ),
                    child: (labelInFilledOnly && centerLabel != null)
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  centerLabel!,
                                  style: labelStyle ??
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),

              // Label centered across full bar width when labelInFilledOnly is false
              if (!labelInFilledOnly && centerLabel != null)
                Center(
                  child: Text(
                    centerLabel!,
                    style: labelStyle ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Type alias for design system consistency (`AppProgressBar`)
typedef AppProgressBar = CustomProgressBar;
