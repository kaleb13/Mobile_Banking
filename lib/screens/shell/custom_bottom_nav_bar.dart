import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show lerpDouble;
import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomBottomNavBar
//
// Listens directly to the PageController's fractional `.page` value so the
// nav bar tracks swipe progress in real time:
//
//   page = 0.5  →  item 0 at 50% activation, item 1 at 50% activation
//   page = 1.0  →  item 0 at 0%, item 1 at 100%
//
// The active pill expands dynamically, icons scale gently, and labels fade/slide.
// ─────────────────────────────────────────────────────────────────────────────

class CustomBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// The PageController from the parent PageView.
  /// We listen to it to drive the per-item activation fractions.
  final PageController pageController;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
    required this.pageController,
  });

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _lastIndex = 0;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.currentIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _lastIndex = oldWidget.currentIndex;
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  double _getItemActivation(int index, double page) {
    if (widget.pageController.hasClients &&
        widget.pageController.position.haveDimensions &&
        (widget.pageController.position.isScrollingNotifier.value ||
            widget.pageController.page != widget.currentIndex.toDouble())) {
      final lowerIndex = page.floor();
      final upperIndex = page.ceil();
      final fraction = page - lowerIndex;
      if (index == lowerIndex) {
        return (1.0 - fraction).clamp(0.0, 1.0);
      } else if (index == upperIndex) {
        return fraction.clamp(0.0, 1.0);
      } else {
        return 0.0;
      }
    }

    if (_animController.isAnimating) {
      final t = Curves.easeInOutCubic.transform(_animController.value);
      if (index == widget.currentIndex) return t;
      if (index == _lastIndex) return (1.0 - t).clamp(0.0, 1.0);
      return 0.0;
    }

    return index == widget.currentIndex ? 1.0 : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically pad above the system navigation bar (3-button nav, gesture
    // bar, etc.).  MediaQuery.padding.bottom reflects whatever the OS insets
    // are, so on gesture-nav devices it is 0 and on 3-button-nav devices it is
    // the height of that bar.  We keep a 12 px base gap on top of that.
    final systemNavBottom = MediaQuery.paddingOf(context).bottom;
    final bottomMargin = systemNavBottom + 12.0;

    return Container(
      margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isLightMode ? 0.08 : 0.50),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: CustomPaint(
          painter: ShibreNavBarPainter(
            backgroundColor: context.isLightMode
                ? AppColors.bottomNavBgLight
                : AppColors.bottomNavBg,
            borderColor: context.isLightMode
                ? AppColors.tabBackgroundLight.withValues(alpha: 0.99)
                : AppColors.bottomNavBorder,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            // AnimatedBuilder rebuilds the row on either PageController scroll or direct jump animation
            child: AnimatedBuilder(
              animation: Listenable.merge([widget.pageController, _animController]),
              builder: (context, _) {
                final page = (widget.pageController.hasClients &&
                        widget.pageController.page != null)
                    ? widget.pageController.page!
                    : widget.currentIndex.toDouble();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final total = constraints.maxWidth;
                    // 44% for the active pill — fits all 2-word labels comfortably without crowding.
                    final activeW = total * 0.44;
                    final inactiveW = (total - activeW) / 4;

                    return Row(
                      children: [
                        _NavItem(
                          label: 'Home Overview',
                          assetPath: 'assets/images/Shibre Icon.png',
                          activationT: _getItemActivation(0, page),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => widget.onTap?.call(0),
                        ),
                        _NavItem(
                          label: 'Wallet Manager',
                          svgPath: 'assets/images/Wallet Icon.svg',
                          activationT: _getItemActivation(1, page),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => widget.onTap?.call(1),
                        ),
                        _NavItem(
                          label: 'Spending Charts',
                          svgPath: 'assets/images/Analysis Icon.svg',
                          activationT: _getItemActivation(2, page),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => widget.onTap?.call(2),
                        ),
                        _NavItem(
                          label: 'Loan Tracker',
                          svgPath: 'assets/images/Loan Icon.svg',
                          activationT: _getItemActivation(3, page),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => widget.onTap?.call(3),
                        ),
                        _NavItem(
                          label: 'Profile Hub',
                          svgPath: 'assets/images/Profile_Icon.svg',
                          activationT: _getItemActivation(4, page),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => widget.onTap?.call(4),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final double activationT;
  final double activeWidth;
  final double inactiveWidth;
  final VoidCallback onTap;
  final String? assetPath;
  final String? svgPath;

  const _NavItem({
    required this.label,
    required this.activationT,
    required this.activeWidth,
    required this.inactiveWidth,
    required this.onTap,
    this.assetPath,
    this.svgPath,
  });

  Widget _buildIcon(Color color) {
    if (svgPath != null) {
      return SvgPicture.asset(
        svgPath!,
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    if (assetPath != null) {
      return Image.asset(assetPath!, width: 18, height: 18, color: color);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // Total sum of containerWidth across all 5 items is mathematically guaranteed to equal constraints.maxWidth
    final containerWidth = inactiveWidth + (activeWidth - inactiveWidth) * activationT;
    final curved = Curves.easeOutCubic.transform(activationT);

    final iconColor = Color.lerp(
      context.themeTextSecondary,
      context.themeTextPrimary,
      curved,
    )!;

    final iconScale = lerpDouble(0.88, 1.0, curved)!;
    final textOpacity = curved.clamp(0.0, 1.0);

    return SizedBox(
      width: containerWidth,
      height: 52,
      child: ClipRect(
        child: OverflowBox(
          maxWidth: activeWidth,
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: activeWidth,
              height: 52,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: inactiveWidth,
                    child: Center(
                      child: Transform.scale(
                        scale: iconScale,
                        child: _buildIcon(iconColor),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Opacity(
                        opacity: textOpacity,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: context.themeTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for Shibre Navigation Bar:
/// - Fills the stadium pill background RRect
/// - Strokes the top border across the top edge with full width
/// - Tapers smoothly around the left and right corner curves to a needle-sharp zero-width tip on both side endpoints
class ShibreNavBarPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double maxBorderWidth;

  const ShibreNavBarPainter({
    required this.backgroundColor,
    required this.borderColor,
    this.maxBorderWidth = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final radius = size.height / 2;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1. Fill background shape
    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // 2. Continuous top border with zero-width needle tips at left and right sides
    final w = maxBorderWidth;
    final path = Path();

    // ── 1. Outer Contour (Exact Outer Pill Top Boundary) ──
    // Starts at left side tip (0, radius) with 0 width
    path.moveTo(0, radius);
    // Outer arc around top-left corner to (radius, 0)
    path.arcTo(
      Rect.fromLTWH(0, 0, radius * 2, radius * 2),
      math.pi,
      math.pi / 2,
      false,
    );
    // Full width horizontal top edge across the middle to (size.width - radius, 0)
    path.lineTo(size.width - radius, 0);
    // Outer arc around top-right corner to right side tip (size.width, radius)
    path.arcTo(
      Rect.fromLTWH(size.width - radius * 2, 0, radius * 2, radius * 2),
      -math.pi / 2,
      math.pi / 2,
      false,
    );

    // ── 2. Inner Contour (Strict Monotonic Tapering: t(theta) = w * cos(theta)) ──
    // From right tip (size.width, radius) where t = 0 up to (size.width - radius, w) where t = w
    const int steps = 16;
    for (int i = 1; i <= steps; i++) {
      final double theta = (math.pi / 2) * (1.0 - i / steps); // theta: pi/2 -> 0
      final double currentW = w * math.cos(theta); // thickness strictly bounded <= w
      final double innerR = radius - currentW;
      final double x = (size.width - radius) + innerR * math.sin(theta);
      final double y = radius - innerR * math.cos(theta);
      path.lineTo(x, y);
    }

    // Inner horizontal top edge across the middle with constant thickness w
    path.lineTo(radius, w);

    // From (radius, w) down to left tip (0, radius) where t = 0
    for (int i = 1; i <= steps; i++) {
      final double theta = (math.pi / 2) * (i / steps); // theta: 0 -> pi/2
      final double currentW = w * math.cos(theta); // thickness strictly bounded <= w
      final double innerR = radius - currentW;
      final double x = radius - innerR * math.sin(theta);
      final double y = radius - innerR * math.cos(theta);
      path.lineTo(x, y);
    }
    path.close();

    // Gradient shader: soft fade at the zero-width side tips, bright & crisp across the top middle
    final borderShader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        borderColor.withValues(alpha: 0.15),
        borderColor,
        borderColor,
        borderColor.withValues(alpha: 0.15),
      ],
      stops: const [0.0, 0.12, 0.88, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, size.width, radius));

    final borderPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = borderShader;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant ShibreNavBarPainter oldDelegate) {
    return oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.maxBorderWidth != maxBorderWidth;
  }
}
