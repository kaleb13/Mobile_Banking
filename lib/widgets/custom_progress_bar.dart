import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable Progress Bar Component
/// Supports custom height, track color, gradient/solid filled bar,
/// and centered percentage text (either centered inside the filled gradient section or full track).
class CustomProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color backgroundColor;
  final Gradient? progressGradient;
  final Color? progressColor;
  final String? centerLabel;
  final TextStyle? labelStyle;
  final bool labelInFilledOnly;
  final BorderRadius? borderRadius;

  const CustomProgressBar({
    super.key,
    required this.progress,
    this.height = 28.0,
    required this.backgroundColor,
    this.progressGradient,
    this.progressColor,
    this.centerLabel,
    this.labelStyle,
    this.labelInFilledOnly = false,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(height / 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final filledWidth = (totalWidth * clampedProgress).clamp(0.0, totalWidth);

        return Container(
          height: height,
          width: totalWidth,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: effectiveRadius,
          ),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Filled portion
              if (filledWidth > 0)
                ClipRRect(
                  borderRadius: effectiveRadius,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    centerLabel!,
                                    style: labelStyle ??
                                        const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
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
