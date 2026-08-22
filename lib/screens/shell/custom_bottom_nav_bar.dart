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

class CustomBottomNavBar extends StatefulWidget {
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

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  int _prevIndex = 0;
  int _targetIndex = 0;
  bool _isDirectJump = false;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.currentIndex;
    _targetIndex = widget.currentIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didUpdateWidget(covariant CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      final diff = (widget.currentIndex - oldWidget.currentIndex).abs();
      _prevIndex = oldWidget.currentIndex;
      _targetIndex = widget.currentIndex;

      if (diff > 1) {
        // Non-adjacent jump: animate only prev and target items directly without middle items
        _isDirectJump = true;
        _animController.forward(from: 0.0).then((_) {
          if (mounted) {
            setState(() {
              _isDirectJump = false;
              _prevIndex = _targetIndex;
            });
          }
        });
      } else {
        _isDirectJump = false;
        _prevIndex = _targetIndex;
        _animController.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Helper: compute 0→1 activation fraction for item at [index]
  // given the current fractional page position [page].
  static double _activationT(double page, int index) {
    return (1.0 - (page - index).abs()).clamp(0.0, 1.0);
  }

  double _getItemActivation(int index, double page) {
    if (_isDirectJump && _animController.isAnimating) {
      final progress = Curves.easeOutCubic.transform(_animController.value);
      if (index == _prevIndex) {
        return (1.0 - progress).clamp(0.0, 1.0);
      } else if (index == _targetIndex) {
        return progress.clamp(0.0, 1.0);
      } else {
        return 0.0;
      }
    }
    return _activationT(page, index);
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppColors.glassBlurSigma,
            sigmaY: AppColors.glassBlurSigma,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.isLightMode
                  ? AppColors.bottomNavBgLight
                  : AppColors.bottomNavBg,
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: context.isLightMode ? 0.06 : 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
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
                    // 46% for the active pill — fits all 2-word labels comfortably.
                    final activeW = total * 0.46;
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
    final curved = Curves.easeInOut.transform(activationT);
    final containerWidth = lerpDouble(inactiveWidth, activeWidth, curved)!;

    final iconColor = Color.lerp(
      context.themeTextSecondary,
      context.themeTextPrimary,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
