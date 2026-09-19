import 'dart:ui' show lerpDouble;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_back_button.dart';

/// Presentation mode for [AppScrollHeaderBar].
enum AppScrollHeaderMode {
  /// Large title displayed at the top beside the back arrow from the start.
  /// As the user scrolls, the title font size smoothly decreases from large
  /// (e.g. 22.5px) down to compact (e.g. 17.0px) and the background transitions
  /// from transparent to a solid surface with elevation.
  collapsingTitle,

  /// Title (and avatar/icon) starts invisible at offset 0 and smoothly fades in
  /// only after the user scrolls past the hero section (e.g., My Profile).
  revealOnScroll,
}

/// AppScrollHeaderBar — dynamic collapsing sticky top navigation bar.
///
/// Supports two distinct UX modes:
/// 1. `collapsingTitle` (default for Settings & standard pages):
///    - Offset = 0: Back button + Large bold title (22.5px) visible immediately, transparent background.
///    - Offset > 0: Font size smoothly scales down to 17px, background fades to solid with shadow.
/// 2. `revealOnScroll` (for My Profile & hero pages):
///    - Offset = 0: Back button visible with transparent background; title & avatar are hidden.
///    - Offset > threshold: Title & avatar smoothly fade in beside back button.
class AppScrollHeaderBar extends StatelessWidget {
  final ScrollController? scrollController;
  final ValueListenable<double>? scrollOffsetListenable;
  final Widget? leading;
  final bool showBackButton;
  final Widget? icon;
  final String title;
  final Widget? trailing;
  final double scrollThreshold;
  final Color? solidBackgroundColor;
  final AppScrollHeaderMode mode;
  final double initialFontSize;
  final double scrolledFontSize;
  final double initialHeight;
  final double collapsedHeight;
  final AppBackButtonVariant backButtonVariant;
  final VoidCallback? onBack;
  final bool showTrailingOnlyOnScroll;

  const AppScrollHeaderBar({
    super.key,
    this.scrollController,
    this.scrollOffsetListenable,
    this.leading,
    this.showBackButton = true,
    this.icon,
    required this.title,
    this.trailing,
    this.scrollThreshold = 55.0,
    this.solidBackgroundColor,
    this.mode = AppScrollHeaderMode.collapsingTitle,
    this.initialFontSize = 22.5,
    this.scrolledFontSize = 17.0,
    this.initialHeight = 54.0,
    this.collapsedHeight = 54.0,
    this.backButtonVariant = AppBackButtonVariant.auto,
    this.onBack,
    this.showTrailingOnlyOnScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final topSafe = MediaQuery.paddingOf(context).top;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final defaultBg = isLight ? AppColors.surfaceLight : AppColors.surface;
    final bgColor = solidBackgroundColor ?? defaultBg;

    final Listenable animationTarget = scrollOffsetListenable ??
        scrollController ??
        const AlwaysStoppedAnimation(0.0);

    return AnimatedBuilder(
      animation: animationTarget,
      builder: (context, _) {
        final double offset = scrollOffsetListenable != null
            ? scrollOffsetListenable!.value
            : (scrollController != null && scrollController!.hasClients
                ? scrollController!.offset
                : 0.0);
        final double progress =
            (offset / scrollThreshold).clamp(0.0, 1.0);
        final double bgOpacity = (progress * 1.6).clamp(0.0, 1.0);
        final bool isScrolled = progress > 0.03;

        final bool hasLeading = leading != null || showBackButton;

        // Dynamic height interpolation
        final double currentHeight = lerpDouble(
          topSafe + initialHeight,
          topSafe + collapsedHeight,
          progress,
        )!;

        // Font size & letter spacing interpolation for collapsingTitle
        final double currentFontSize = mode == AppScrollHeaderMode.collapsingTitle
            ? lerpDouble(initialFontSize, scrolledFontSize, progress)!
            : scrolledFontSize;
        final double currentLetterSpacing =
            mode == AppScrollHeaderMode.collapsingTitle
                ? lerpDouble(-0.5, -0.3, progress)!
                : -0.3;

        // Title opacity: 1.0 always in collapsingTitle, or progress in revealOnScroll
        final double titleOpacity = mode == AppScrollHeaderMode.revealOnScroll
            ? progress
            : 1.0;

        // Icon opacity: in revealOnScroll it fades with progress. In collapsingTitle,
        // if an icon is provided, it fades in as the title shrinks to compact navbar size.
        final double iconOpacity = progress;

        // Trailing opacity
        final double trailingOpacity =
            showTrailingOnlyOnScroll ? progress : 1.0;

        return Container(
          padding: EdgeInsets.only(top: topSafe),
          height: currentHeight,
          decoration: BoxDecoration(
            color: isScrolled
                ? (bgOpacity >= 0.95
                    ? bgColor
                    : bgColor.withValues(alpha: bgOpacity))
                : Colors.transparent,
            boxShadow: isScrolled && progress >= 0.7
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22 * progress),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (leading != null)
                  leading!
                else if (showBackButton)
                  AppBackButton(
                    variant: backButtonVariant,
                    onPressed: onBack,
                  ),
                if (hasLeading) const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Opacity(
                          opacity: iconOpacity,
                          child: icon!,
                        ),
                        if (iconOpacity > 0.05) const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Opacity(
                          opacity: titleOpacity,
                          child: Text(
                            title,
                            style: TextStyle(
                              color: isLight
                                  ? AppColors.textPrimaryLight
                                  : Colors.white,
                              fontSize: currentFontSize,
                              fontWeight: FontWeight.bold,
                              letterSpacing: currentLetterSpacing,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null)
                  Opacity(
                    opacity: trailingOpacity,
                    child: trailing!,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
