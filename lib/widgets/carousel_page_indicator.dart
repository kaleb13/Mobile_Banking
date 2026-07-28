import 'package:flutter/material.dart';

/// A morphing pill-style page indicator that animates smoothly as the user
/// scrolls through pages in a [PageView].
///
/// The active dot expands horizontally and becomes fully opaque, while
/// inactive dots are narrow and semi-transparent — the same style used in
/// the home screen banner carousel.
///
/// Usage:
/// ```dart
/// CarouselPageIndicator(
///   controller: _pageController,
///   pageCount: 4,
/// )
/// ```
class CarouselPageIndicator extends StatelessWidget {
  /// The [PageController] that drives the animation.
  final PageController controller;

  /// Total number of pages / dots to render.
  final int pageCount;

  /// Colour of each dot. Defaults to [Colors.white].
  final Color color;

  /// Width of the active (selected) dot pill. Defaults to 18.
  final double activeWidth;

  /// Width of an inactive dot. Defaults to 6.
  final double inactiveWidth;

  /// Height of every dot. Defaults to 3.5.
  final double height;

  /// Horizontal gap between dots. Defaults to 3.
  final double spacing;

  const CarouselPageIndicator({
    super.key,
    required this.controller,
    required this.pageCount,
    this.color = Colors.white,
    this.activeWidth = 18.0,
    this.inactiveWidth = 6.0,
    this.height = 3.5,
    this.spacing = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Current fractional page offset (handles both attached and detached state)
        final double pageOffset = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(pageCount, (i) {
            // Shortest angular distance to handle wraparound (not strictly needed
            // for onboarding which is linear, but keeps the widget general-purpose)
            double difference = (pageOffset - i).abs();
            if (difference > pageCount / 2) difference = pageCount - difference;
            difference = difference.clamp(0.0, 1.0);

            // factor = 1 when fully selected, 0 when one page away
            final double factor = 1.0 - difference;

            final double dotWidth =
                inactiveWidth + ((activeWidth - inactiveWidth) * factor);
            final double alpha = 0.20 + (0.80 * factor);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: spacing),
              width: dotWidth,
              height: height,
              decoration: BoxDecoration(
                color: color.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(height),
              ),
            );
          }),
        );
      },
    );
  }
}
