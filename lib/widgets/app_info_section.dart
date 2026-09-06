import 'package:flutter/material.dart';

/// Standardized Info Section component adhering strictly to the design system:
/// - Written directly on the page background (no cards, no container background fill, no borders).
/// - Refined hierarchy using varying opacities of white:
///   - Top Icon: `Colors.white.withValues(alpha: 0.4)` (size 15)
///   - Top Title: `Colors.white.withValues(alpha: 0.55)` (fontSize 12, fontWeight w600)
///   - Description Body: `Colors.white.withValues(alpha: 0.4)` (fontSize 11, height 1.45)
class AppInfoSection extends StatelessWidget {
  final String? title;
  final String description;
  final IconData icon;
  final EdgeInsetsGeometry padding;
  final double iconSize;

  const AppInfoSection({
    super.key,
    this.title,
    required this.description,
    this.icon = Icons.info_outline_rounded,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.iconSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title!.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: iconSize,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                height: 1.45,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    icon,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
