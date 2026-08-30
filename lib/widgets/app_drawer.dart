import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'interactive_drag_handle.dart';
import 'app_bottom_sheet.dart';

/// Centralized standardized Drawer / Bottom Sheet Container.
///
/// Implements the clean Reason-Sheet design characteristics:
/// - Top pill drag handle with interactive swipe-down gesture (no close 'X' button)
/// - Optional distinct header card or title row
/// - Smooth scrollable body
/// - Dedicated sticky bottom action sheet / button bar
/// - Fully rounded top corners (28–32px) and zero borders / stroke lines
class AppDrawer extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? headerCard;
  final Widget? trailingHeader;
  final Widget child;
  final Widget? bottomAction;
  final double? heightFactor;
  final double maxHeightFactor;
  final Color backgroundColor;
  final double topRadius;
  final EdgeInsetsGeometry padding;
  final bool showDragHandle;
  final bool isBodyScrollable;

  const AppDrawer({
    super.key,
    this.title,
    this.subtitle,
    this.headerCard,
    this.trailingHeader,
    required this.child,
    this.bottomAction,
    this.heightFactor,
    this.maxHeightFactor = 0.90,
    this.backgroundColor = AppColors.surfaceElevated,
    this.topRadius = AppRadius.sheet,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
    this.showDragHandle = true,
    this.isBodyScrollable = true,
  });

  /// Convenience method to show an [AppDrawer] inside [AppBottomSheet.show]
  /// with a frosted dark blurred backdrop.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    bool enableDrag = true,
    Color? barrierColor,
    double blurSigma = 8.0,
  }) {
    return AppBottomSheet.show<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      barrierColor: barrierColor,
      blurSigma: blurSigma,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final systemNavBottom = MediaQuery.paddingOf(context).bottom;
    final double extraBottom = bottomInset > 0 ? bottomInset : systemNavBottom;
    final insets = padding.resolve(Directionality.of(context));
    final screenHeight = MediaQuery.of(context).size.height;
    final double? targetHeight = heightFactor != null ? screenHeight * heightFactor! : null;
    final double maxHeight = screenHeight * maxHeightFactor;

    Widget bodyWidget;
    if (heightFactor != null) {
      bodyWidget = isBodyScrollable ? Expanded(child: child) : child;
    } else {
      bodyWidget = isBodyScrollable
          ? Flexible(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                child: child,
              ),
            )
          : child;
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: targetHeight,
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: EdgeInsets.fromLTRB(
          insets.left,
          insets.top,
          insets.right,
          insets.bottom + extraBottom,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: heightFactor == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // ── Drag Handle (No close X button) ───────────────────────────
            if (showDragHandle)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InteractiveDragHandle(
                    color: Colors.white.withValues(alpha: 0.25),
                    onTap: () => Navigator.pop(context),
                    onVerticalDragUpdate: (details) {
                      if ((details.primaryDelta ?? 0) > 3) {
                        Navigator.pop(context);
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

            // ── Hero / Header Card (if provided) ─────────────────────────
            if (headerCard != null) ...[
              headerCard!,
              const SizedBox(height: 12),
            ] else if (title != null && title!.isNotEmpty) ...[
              // ── Standard Title Row ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingHeader != null) ...[
                    const SizedBox(width: 8),
                    trailingHeader!,
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── Body Content (Content-wrapped or Expanded) ────────────────
            bodyWidget,

            // ── Dedicated Sticky Bottom Action Sheet / Button Bar ────────
            if (bottomAction != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: bottomAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standardized top title row placed beneath the drag handle in an [AppDrawer].
/// Features a transparent white circular icon on the left, short bold title,
/// and trailing actions/buttons on the right. Zero bulky background box and zero description text.
class AppDrawerHeaderCard extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  const AppDrawerHeaderCard({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Standardized modal menu / 3-dot action item tile for drawers & modal sheets.
///
/// Follows the design system monochrome hierarchy:
/// - Container background: Clean dark surface (`AppColors.surface` / translucent white) with rounded corners and zero borders
/// - Bare icon (NO background box or circle) in translucent white (~50% opacity)
/// - Title in semi-white text (~85% opacity, brighter than the icon, softer than pure white title)
/// - Subtitle in soft white (~45% opacity)
class AppDrawerActionTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;

  const AppDrawerActionTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.margin = const EdgeInsets.only(bottom: 6),
  });

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.white.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.50),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (hasSubtitle) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

