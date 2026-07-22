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
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 28),
      height: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.overlay,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            // AnimatedBuilder rebuilds the row on every PageController tick —
            // this is how swipe progress maps to nav bar animation in real time.
            child: AnimatedBuilder(
              animation: pageController,
              builder: (context, _) {
                // Fractional page position. Falls back to currentIndex when
                // the controller has no clients yet (first frame).
                final page = (pageController.hasClients &&
                        pageController.page != null)
                    ? pageController.page!
                    : currentIndex.toDouble();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final total = constraints.maxWidth;
                    // 46% for the active pill — fits all 2-word labels comfortably.
                    // The remaining 54% is split evenly across the 4 inactive icon slots.
                    final activeW = total * 0.46;
                    final inactiveW = (total - activeW) / 4;

                    return Row(
                      children: [
                        _NavItem(
                          label: 'Shibre Home',
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
                          label: 'App Settings',
                          svgPath: 'assets/images/Settings_icon.svg',
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

// ─────────────────────────────────────────────────────────────────────────────
// _NavItem  (StatelessWidget — all animation driven by activationT from parent)
//
// activationT = 0.0  → fully inactive (container = inactiveWidth, icon gray)
// activationT = 0.5  → mid-transition (container half-expanded, icon half-white)
// activationT = 1.0  → fully active   (container = activeWidth, icon white)
//
// The text is always laid out at full size inside an OverflowBox.
// ClipRect masks it. As activationT rises the container expands and reveals
// the text from left to right — no opacity tricks.
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final String label;

  /// 0.0 → fully inactive, 1.0 → fully active.
  /// Driven directly by pageController.page — updates on every scroll frame.
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
        width: 22,
        height: 22,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }
    if (assetPath != null) {
      return Image.asset(assetPath!, width: 20, height: 20, color: color);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    // Softer curve than easeInOutCubic — the animation spends more time in the
    // mid-range (40%–60%) so the 50/50 state between two items is visible.
    final curved = Curves.easeInOut.transform(activationT);

    // Container width: inactiveWidth → activeWidth
    final containerWidth = lerpDouble(inactiveWidth, activeWidth, curved)!;

    // Icon color: gray (inactive) → white (active)
    final iconColor = Color.lerp(
      AppColors.textSecondary,
      AppColors.textPrimary,
      curved,
    )!;

    // Icon scale: 0.88 (inactive) → 1.0 (active)
    final iconScale = lerpDouble(0.88, 1.0, curved)!;

    return SizedBox(
      width: containerWidth,
      height: 64,
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
              height: 64,
              child: Row(
                // mainAxisSize.max → Row fills exactly activeWidth.
                // This hard-constrains children so nothing can push beyond it.
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Icon slot ───────────────────────────────────────────
                  SizedBox(
                    width: inactiveWidth,
                    child: Center(
                      child: Transform.scale(
                        scale: iconScale,
                        child: _buildIcon(iconColor),
                      ),
                    ),
                  ),

                  // ── Label ───────────────────────────────────────────────
                  // Expanded takes exactly (activeWidth - inactiveWidth) px.
                  // Text can never cause the Row to overflow — ClipRect
                  // handles the visual masking as the container expands.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
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
