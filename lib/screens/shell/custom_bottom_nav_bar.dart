import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
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
// Each item's activationT = clamp(1 − |page − itemIndex|, 0, 1)
// ─────────────────────────────────────────────────────────────────────────────

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// The PageController from the parent PageView.
  /// We listen to it to drive the per-item activation fractions.
  final PageController pageController;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.pageController,
  });

  // Helper: compute 0→1 activation fraction for item at [index]
  // given the current fractional page position [page].
  static double _activationT(double page, int index) {
    return (1.0 - (page - index).abs()).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
      height: 60,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bottomNavBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // AnimatedBuilder rebuilds the row on every PageController tick
            child: AnimatedBuilder(
              animation: pageController,
              builder: (context, _) {
                final page = (pageController.hasClients &&
                        pageController.page != null)
                    ? pageController.page!
                    : currentIndex.toDouble();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final total = constraints.maxWidth;
                    // 46% for the active pill — fits all 2-word labels comfortably.
                    final activeW = total * 0.46;
                    final inactiveW = (total - activeW) / 4;

                    return Row(
                      children: [
                        _NavItem(
                          label: 'Home Overview',
                          assetPath: 'assets/images/Shibre Icon.png',
                          activationT: _activationT(page, 0),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => onTap?.call(0),
                        ),
                        _NavItem(
                          label: 'Wallet Manager',
                          svgPath: 'assets/images/Wallet Icon.svg',
                          activationT: _activationT(page, 1),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => onTap?.call(1),
                        ),
                        _NavItem(
                          label: 'Spending Charts',
                          svgPath: 'assets/images/Analysis Icon.svg',
                          activationT: _activationT(page, 2),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => onTap?.call(2),
                        ),
                        _NavItem(
                          label: 'Loan Tracker',
                          svgPath: 'assets/images/Loan Icon.svg',
                          activationT: _activationT(page, 3),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => onTap?.call(3),
                        ),
                        _NavItem(
                          label: 'Profile Hub',
                          svgPath: 'assets/images/Profile_Icon.svg',
                          activationT: _activationT(page, 4),
                          activeWidth: activeW,
                          inactiveWidth: inactiveW,
                          onTap: () => onTap?.call(4),
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
    final curved = Curves.easeInOut.transform(activationT);
    final containerWidth = lerpDouble(inactiveWidth, activeWidth, curved)!;

    final iconColor = Color.lerp(
      AppColors.textSecondary,
      AppColors.textPrimary,
      curved,
    )!;

    final iconScale = lerpDouble(0.88, 1.0, curved)!;

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
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
