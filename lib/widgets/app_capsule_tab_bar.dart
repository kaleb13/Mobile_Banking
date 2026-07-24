import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A reusable capsule-style TabBar / Segmented Control styled with
/// hex color #191F28 (AppColors.tabBackground), zero border/stroke,
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
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: AppColors.tabBackground,
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(indicatorRadius),
          ),
          dividerColor: Colors.transparent,
          labelColor: AppColors.tabBackground,
          unselectedLabelColor: Colors.white,
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
        children: List.generate(tabs.length, (index) {
          final isSelected = currIndex == index;
          return Expanded(
            child: GestureDetector(
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
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(indicatorRadius),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? AppColors.tabBackground : Colors.white,
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
