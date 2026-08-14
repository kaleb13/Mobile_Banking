import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable capsule-style TabBar / Segmented Control styled with
/// hex color #111821 (AppColors.surface), zero border/stroke,
/// a white pill indicator for active tab, and crisp white inactive text.
class AppCapsuleTabBar extends StatelessWidget {
  final List<String> tabs;
  final int? selectedIndex;
  final ValueChanged<int>? onTabChanged;
  final TabController? controller;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double indicatorRadius;

  final bool expandTabs;

  const AppCapsuleTabBar({
    super.key,
    required this.tabs,
    this.selectedIndex,
    this.onTabChanged,
    this.controller,
    this.height = 40,
    this.fontSize = 12,
    this.margin,
    this.padding = const EdgeInsets.all(4),
    this.borderRadius = 24,
    this.indicatorRadius = 20,
    this.expandTabs = true,
  });

  @override
  Widget build(BuildContext context) {
    final capsuleBg = context.themeSurface;
    final activeTextColor = context.isLightMode
        ? AppColors.textPrimaryLight
        : AppColors.surface;
    final inactiveTextColor = context.isLightMode
        ? AppColors.textSecondaryLight
        : Colors.white;
    final activePillColor = Colors.white;

    final decoration = BoxDecoration(
      color: capsuleBg,
      borderRadius: BorderRadius.circular(borderRadius),
    );

    // Mode 1: Integrated with Flutter TabController
    if (controller != null) {
      return Container(
        height: height,
        margin: margin,
        padding: padding,
        decoration: decoration,
        child: TabBar(
          controller: controller,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: activePillColor,
            borderRadius: BorderRadius.circular(indicatorRadius),
            boxShadow: context.isLightMode
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          dividerColor: Colors.transparent,
          labelColor: activeTextColor,
          unselectedLabelColor: inactiveTextColor,
          labelStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: tabs.map((t) => Tab(height: height - 8, text: t)).toList(),
        ),
      );
    }

    // Mode 2: Index-based switching with animated active pill
    final currIndex = selectedIndex ?? 0;
    return Container(
      height: height,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: Row(
        mainAxisSize: expandTabs ? MainAxisSize.max : MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final isSelected = currIndex == index;
          final itemWidget = GestureDetector(
            onTap: () {
              if (onTabChanged != null) {
                onTabChanged!(index);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: expandTabs
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? activePillColor : Colors.transparent,
                borderRadius: BorderRadius.circular(indicatorRadius),
                boxShadow: isSelected && context.isLightMode
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : null,
              ),
              child: Text(
                tabs[index],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? activeTextColor : inactiveTextColor,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );

          return expandTabs ? Expanded(child: itemWidget) : itemWidget;
        }),
      ),
    );
  }
}
