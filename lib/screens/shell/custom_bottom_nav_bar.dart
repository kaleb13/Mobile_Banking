import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DynamicNavBarWrapper extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final bool isDynamic;
  final VoidCallback? onDynamicAdd;
  final VoidCallback? onDynamicBack;
  final String? dynamicActionLabel;
  final IconData? dynamicActionIcon;

  const DynamicNavBarWrapper({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDynamic = false,
    this.onDynamicAdd,
    this.onDynamicBack,
    this.dynamicActionLabel,
    this.dynamicActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'dynamic_navbar_hero',
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        final Hero fromHero = fromHeroContext.widget as Hero;
        final CustomBottomNavBar fromWidget = (fromHero.child is Material)
            ? (fromHero.child as Material).child as CustomBottomNavBar
            : fromHero.child as CustomBottomNavBar;

        final Hero toHero = toHeroContext.widget as Hero;
        final CustomBottomNavBar toWidget = (toHero.child is Material)
            ? (toHero.child as Material).child as CustomBottomNavBar
            : toHero.child as CustomBottomNavBar;

        final startMorph = fromWidget.isDynamic ? 1.0 : 0.0;
        final endMorph = toWidget.isDynamic ? 1.0 : 0.0;

        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final currentMorph = startMorph + (endMorph - startMorph) * t;

            return Material(
              type: MaterialType.transparency,
              child: CustomBottomNavBar(
                currentIndex: toWidget.currentIndex,
                onTap: toWidget.onTap,
                isDynamic: toWidget.isDynamic,
                onDynamicAdd: toWidget.onDynamicAdd,
                onDynamicBack: toWidget.onDynamicBack,
                dynamicActionLabel: toWidget.dynamicActionLabel,
                dynamicActionIcon: toWidget.dynamicActionIcon,
                morphProgress: currentMorph,
              ),
            );
          },
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: CustomBottomNavBar(
          currentIndex: currentIndex,
          onTap: onTap,
          isDynamic: isDynamic,
          onDynamicAdd: onDynamicAdd,
          onDynamicBack: onDynamicBack,
          dynamicActionLabel: dynamicActionLabel,
          dynamicActionIcon: dynamicActionIcon,
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;
  final bool isDynamic;
  final VoidCallback? onDynamicAdd;
  final VoidCallback? onDynamicBack;
  final double morphProgress;
  final String? dynamicActionLabel;
  final IconData? dynamicActionIcon;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isDynamic = false,
    this.onDynamicAdd,
    this.onDynamicBack,
    this.morphProgress = -1.0,
    this.dynamicActionLabel,
    this.dynamicActionIcon,
  });

  @override
  Widget build(BuildContext context) {
    // If morphProgress is not provided (-1.0), derive it from isDynamic.
    final t = morphProgress >= 0 ? morphProgress : (isDynamic ? 1.0 : 0.0);

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
      height: 56,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;

          // Width/Position interpolations
          final homeWidth = 56.0 * (1 - t);
          final middleLeft = 64.0 * (1 - t);
          final middleWidth = (totalWidth - 128) + (64.0 * t);
          final backLeft = totalWidth - 56.0;

          // Color interpolations
          final middleColor =
              Color.lerp(const Color(0xFF2A2A34), const Color(0xFFF0B90B), t)!;
          final homeColor = const Color(0xFF2A2A34);
          final backColor = const Color(0xFF2A2A34);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // HOME ICON (Disappearing to the left)
              Positioned(
                left: -40 * t, // Slides out
                top: 0,
                width: homeWidth,
                height: 56,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: homeColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: () => onTap?.call(0),
                      behavior: HitTestBehavior.opaque,
                      child: Image.asset(
                        'assets/images/Shibre Icon.png',
                        width: 20,
                        height: 20,
                        color: currentIndex == 0
                            ? Colors.white
                            : Colors.white.withAlpha((0.4 * 255).round()),
                      ),
                    ),
                  ),
                ),
              ),

              // MIDDLE PILL (Main Dynamic Section)
              Positioned(
                left: middleLeft,
                top: 0,
                width: middleWidth,
                height: 56,
                child: GestureDetector(
                  onTap: () {
                    if (t > 0.5) {
                      onDynamicAdd?.call();
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: middleColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Navigation Icons (Fade out)
                        Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: totalWidth - 128,
                              height: 56,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildMiddleItem(
                                    isActive: currentIndex == 1,
                                    iconData: Icons.insert_chart_outlined,
                                    label: 'Analysis',
                                    onTap: () => onTap?.call(1),
                                  ),
                                  _buildMiddleItem(
                                    isActive: currentIndex == 2,
                                    iconData:
                                        Icons.account_balance_wallet_outlined,
                                    label: 'Wallet',
                                    onTap: () => onTap?.call(2),
                                  ),
                                  _buildMiddleItem(
                                    isActive: currentIndex == 3,
                                    iconData: Icons.payments_outlined,
                                    label: 'Loan',
                                    onTap: () => onTap?.call(3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Action Icons/Label (Fade in)
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.5 + (t * 0.5),
                            child: dynamicActionLabel != null
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (dynamicActionIcon != null) ...[
                                          Icon(dynamicActionIcon,
                                              color: const Color(0xFF301900),
                                              size: 18),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          dynamicActionLabel!,
                                          style: const TextStyle(
                                            color: Color(0xFF301900),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  )
                                : Icon(
                                    dynamicActionIcon ?? Icons.add,
                                    color: const Color(0xFF301900),
                                    size: 22,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // SETTINGS / BACK (Right Circle)
              Positioned(
                left: backLeft,
                top: 0,
                width: 56,
                height: 56,
                child: GestureDetector(
                  onTap: () {
                    // Back logic triggers if dynamic or if specifically requested
                    if (t > 0.5 ||
                        (isDynamic == false && onDynamicBack != null)) {
                      onDynamicBack?.call();
                    } else {
                      onTap?.call(4);
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(
                      color: backColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Normal Settings Icon
                        Opacity(
                          opacity: (1 - t).clamp(0.0, 1.0),
                          child: Icon(
                            Icons.settings_outlined,
                            color: currentIndex == 4
                                ? Colors.white
                                : Colors.white.withAlpha((0.4 * 255).round()),
                            size: 24,
                          ),
                        ),
                        // Dynamic Back Icon
                        Opacity(
                          opacity: t.clamp(0.0, 1.0),
                          child: SvgPicture.asset(
                            'assets/images/BackForNav.svg',
                            colorFilter: const ColorFilter.mode(
                                Colors.white, BlendMode.srcIn),
                            width: 20,
                            height: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMiddleItem({
    required bool isActive,
    required IconData iconData,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              color: isActive
                  ? Colors.white
                  : Colors.white.withAlpha((0.4 * 255).round()),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isActive
                    ? Colors.white
                    : Colors.white.withAlpha((0.4 * 255).round()),
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
