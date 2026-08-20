import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

// ═════════════════════════════════════════════════════════════════════════════
// 1. PRIMARY TAB COMPONENT (AppPrimaryTabBar / AppCapsuleTabBar)
// ═════════════════════════════════════════════════════════════════════════════

/// Primary high-level content / feature switcher tab bar.
///
/// Styled with an inset track ([AppColors.tabBackground]), a crisp white pill
/// indicator for the active tab, high-contrast dark text on the active pill,
/// crisp white inactive text, and 100% fully rounded pill geometry with zero borders.
///
/// Supports dual modes:
/// 1. Controller mode: Synchronized with Flutter [TabController] and [TabBarView].
/// 2. Index mode: State-driven with [selectedIndex] and [onTabChanged].
class AppPrimaryTabBar extends StatelessWidget {
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
  final Color? backgroundColor;

  const AppPrimaryTabBar({
    super.key,
    required this.tabs,
    this.selectedIndex,
    this.onTabChanged,
    this.controller,
    this.height = 32,
    this.fontSize = 11,
    this.margin,
    this.padding = const EdgeInsets.all(2.5),
    this.borderRadius = 100,
    this.indicatorRadius = 100,
    this.expandTabs = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final capsuleBg = backgroundColor ??
        (context.isLightMode
            ? AppColors.tabBackgroundLight
            : AppColors.tabBackground);
    final activeTextColor = context.isLightMode
        ? AppColors.textPrimaryLight
        : AppColors.surface;
    final inactiveTextColor = context.isLightMode
        ? AppColors.textSecondaryLight
        : AppColors.buttonSecondaryText;
    const activePillColor = AppColors.buttonPrimary;

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
            letterSpacing: -0.2,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: tabs.map((t) => Tab(height: height - 5, text: t)).toList(),
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
                HapticFeedback.selectionClick();
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
                  : const EdgeInsets.symmetric(horizontal: 10),
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
                  letterSpacing: -0.2,
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

/// Alias for backwards compatibility across existing imports.
typedef AppCapsuleTabBar = AppPrimaryTabBar;

// ═════════════════════════════════════════════════════════════════════════════
// 2. SECONDARY TAB COMPONENT (AppSecondaryTabBar)
// ═════════════════════════════════════════════════════════════════════════════

/// Secondary pill tab switcher, primarily used for sub-period selection
/// (days, weeks, months, quarters, years) and multi-option pill filters.
///
/// Features independent 100% fully rounded pill elements with surface/elevated
/// surface contrast, zero borders, and horizontal scrolling support.
class AppSecondaryTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;
  final bool isScrollable;
  final double height;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double itemSpacing;
  final Color? activeColor;
  final Color? inactiveColor;

  const AppSecondaryTabBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
    this.isScrollable = true,
    this.height = 36,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.itemSpacing = 8,
    this.activeColor,
    this.inactiveColor,
  });

  Widget _buildPill(BuildContext context, int index) {
    final isSelected = index == selectedIndex;
    final activeBg = activeColor ??
        (context.isLightMode
            ? AppColors.buttonPrimary
            : AppColors.buttonPrimary);
    final inactiveBg = inactiveColor ??
        (context.isLightMode
            ? AppColors.cardTileLight
            : AppColors.heatmapNeutral);

    final activeText = context.isLightMode
        ? AppColors.buttonPrimaryText
        : AppColors.buttonPrimaryText;
    final inactiveText = context.isLightMode
        ? AppColors.textSecondaryLight
        : AppColors.textSoft;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTabChanged(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Text(
            tabs[index],
            style: TextStyle(
              color: isSelected ? activeText : inactiveText,
              fontSize: fontSize,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    if (isScrollable) {
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          padding: padding,
          itemCount: tabs.length,
          separatorBuilder: (_, __) => SizedBox(width: itemSpacing),
          itemBuilder: (context, index) => _buildPill(context, index),
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: List.generate(tabs.length, (index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index < tabs.length - 1 ? itemSpacing : 0,
              ),
              child: _buildPill(context, index),
            ),
          );
        }),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// 3. TERTIARY TAB COMPONENT (AppTertiaryTabBar)
// ═════════════════════════════════════════════════════════════════════════════

/// Tertiary compact timeframe tab bar placed beneath charts and metric graphs
/// (e.g. ['1D', '7D', '30D', '180D', '360D']).
///
/// Features low-profile 100% fully rounded pill chips, subtle translucent glass
/// active highlight ([AppColors.buttonSecondary]), zero borders, and integrated haptics.
class AppTertiaryTabBar extends StatelessWidget {
  final List<String> tabs;
  final String? selectedTab;
  final int? selectedIndex;
  final ValueChanged<String>? onTabChanged;
  final ValueChanged<int>? onIndexChanged;
  final EdgeInsetsGeometry padding;
  final double fontSize;
  final MainAxisAlignment alignment;

  const AppTertiaryTabBar({
    super.key,
    required this.tabs,
    this.selectedTab,
    this.selectedIndex,
    this.onTabChanged,
    this.onIndexChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.fontSize = 10,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(tabs.length, (index) {
          final tabText = tabs[index];
          final isSelected = (selectedTab != null && selectedTab == tabText) ||
              (selectedIndex != null && selectedIndex == index);

          final activeBg = context.isLightMode
              ? AppColors.surfaceElevated
              : AppColors.buttonSecondary;
          final inactiveBg = Colors.transparent;

          final activeText = context.isLightMode
              ? AppColors.textPrimaryLight
              : AppColors.buttonSecondaryText;
          final inactiveText = context.isLightMode
              ? AppColors.textSecondaryLight
              : AppColors.textSoft;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              if (onTabChanged != null) onTabChanged!(tabText);
              if (onIndexChanged != null) onIndexChanged!(index);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? activeBg : inactiveBg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                tabText,
                style: TextStyle(
                  color: isSelected ? activeText : inactiveText,
                  fontSize: fontSize,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
