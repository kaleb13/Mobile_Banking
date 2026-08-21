import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Standardized List & Menu Tile component for settings, profiles, and option lists.
class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? leadingWidget;
  final Color? leadingColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool showChevron;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Widget? badge;
  final Color? backgroundColor;
  final bool isSelected;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.leadingWidget,
    this.leadingColor,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.showChevron = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderRadius = AppRadius.card,
    this.badge,
    this.backgroundColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? leadingContent;
    if (leadingWidget != null) {
      leadingContent = leadingWidget;
    } else if (leadingIcon != null) {
      final iconColor = isDestructive
          ? AppColors.destructiveRed
          : (isSelected
              ? AppColors.positive
              : (leadingColor ?? context.themeTextPrimary));
      final boxBg = isDestructive
          ? AppColors.destructiveRed.withValues(alpha: 0.12)
          : (isSelected
              ? AppColors.positive.withValues(alpha: 0.20)
              : context.themeTileBg);

      leadingContent = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: boxBg,
          shape: BoxShape.circle,
        ),
        child: Icon(leadingIcon, color: iconColor, size: 20),
      );
    }

    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && isSelected) {
      effectiveTrailing = const Icon(
        Icons.check_circle_rounded,
        color: AppColors.positive,
        size: 20,
      );
    } else if (effectiveTrailing == null && showChevron && onTap != null) {
      effectiveTrailing = Icon(
        Icons.chevron_right_rounded,
        color: context.themeTextSecondary,
        size: 20,
      );
    }

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.positive.withValues(alpha: 0.14)
            : (backgroundColor ?? context.themeSurface),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          if (leadingContent != null) ...[
            leadingContent,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: isDestructive
                              ? AppColors.destructiveRed
                              : context.themeTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      badge!,
                    ],
                  ],
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(
                      color: context.themeTextSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (effectiveTrailing != null) ...[
            const SizedBox(width: 12),
            effectiveTrailing,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      ),
    );
  }
}
