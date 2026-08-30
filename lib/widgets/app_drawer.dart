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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 12,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingHeader != null) trailingHeader!,
                ],
              ),
              const SizedBox(height: 14),
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

/// Standardized card placed beneath the drag handle in an [AppDrawer].
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
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ] else if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.positive).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.positive,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
