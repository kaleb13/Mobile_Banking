import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Standardized Reset Filter pill button component for the Mobile Banking design system.
///
/// Features:
/// - 100% fully rounded pill shape (`BorderRadius.circular(100)`).
/// - Zero border strokes.
/// - Soft red tint background (`AppColors.negative` @ 14% opacity).
/// - High-contrast red icon & text (`AppColors.negative`).
/// - Built-in haptic feedback on tap.
class AppResetFilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final double height;
  final EdgeInsetsGeometry? padding;

  const AppResetFilterButton({
    super.key,
    required this.onTap,
    this.label = 'Reset',
    this.height = 34,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.refresh_rounded,
              size: 13,
              color: AppColors.negative,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.negative,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
