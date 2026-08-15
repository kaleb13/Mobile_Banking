import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Available sizes for the standardized [AppBadge].
enum AppBadgeSize {
  micro,  // Micro tag (NEW, REASON? on list tiles)
  small,  // Compact tag (CURRENT, status pills)
  medium, // Standard badge (detail screens)
  large,  // Prominent badge (hero cards)
}

/// Visual variants for [AppBadge].
enum AppBadgeVariant {
  success,
  warning,
  destructive,
  neutral,
  info,
}

/// Standardized Badge component adhering strictly to the design system:
/// - 100% fully rounded pill shape (BorderRadius.circular(100))
/// - Zero borders / strokes
/// - Solid backgrounds with high-contrast white text and icons
class AppBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final AppBadgeVariant variant;
  final AppBadgeSize size;
  final Color? customBgColor;
  final Color? customTextColor;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.text,
    this.icon,
    this.variant = AppBadgeVariant.neutral,
    this.size = AppBadgeSize.small,
    this.customBgColor,
    this.customTextColor,
    this.onTap,
  });

  /// Solid Emerald Green Badge (Active, Current, Paid, Settled, Income) - Solid Green Bg + White Text
  const AppBadge.success({
    super.key,
    required this.text,
    this.icon,
    this.size = AppBadgeSize.small,
    this.onTap,
  })  : variant = AppBadgeVariant.success,
        customBgColor = null,
        customTextColor = null;

  /// Solid Amber / Orange Badge (Pending, Reason Needed, Due Soon, Attention) - Solid Amber Bg + White Text
  const AppBadge.warning({
    super.key,
    required this.text,
    this.icon,
    this.size = AppBadgeSize.small,
    this.onTap,
  })  : variant = AppBadgeVariant.warning,
        customBgColor = null,
        customTextColor = null;

  /// Solid Crimson Red Badge (Overdue, Unlinked, Paused, New, Danger, Expense) - Solid Red Bg + White Text
  const AppBadge.destructive({
    super.key,
    required this.text,
    this.icon,
    this.size = AppBadgeSize.small,
    this.onTap,
  })  : variant = AppBadgeVariant.destructive,
        customBgColor = null,
        customTextColor = null;

  /// Solid Slate Surface / Neutral Badge (Counts, Versions, Categories) - Solid Slate Bg + White Text
  const AppBadge.neutral({
    super.key,
    required this.text,
    this.icon,
    this.size = AppBadgeSize.small,
    this.onTap,
  })  : variant = AppBadgeVariant.neutral,
        customBgColor = null,
        customTextColor = null;

  /// Solid Royal Blue Badge (Info, Sync, Internal Transfer) - Solid Blue Bg + White Text
  const AppBadge.info({
    super.key,
    required this.text,
    this.icon,
    this.size = AppBadgeSize.small,
    this.onTap,
  })  : variant = AppBadgeVariant.info,
        customBgColor = null,
        customTextColor = null;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor = customTextColor ?? Colors.white;

    switch (variant) {
      case AppBadgeVariant.success:
        bgColor = customBgColor ?? AppColors.badgeSuccessBg;
        break;
      case AppBadgeVariant.warning:
        bgColor = customBgColor ?? AppColors.badgeWarningBg;
        break;
      case AppBadgeVariant.destructive:
        bgColor = customBgColor ?? AppColors.badgeDestructiveBg;
        break;
      case AppBadgeVariant.neutral:
        bgColor = customBgColor ?? AppColors.badgeNeutralBg;
        break;
      case AppBadgeVariant.info:
        bgColor = customBgColor ?? AppColors.badgeInfoBg;
        break;
    }

    final EdgeInsetsGeometry padding;
    final double fontSize;
    final double iconSize;
    final double iconSpacing;

    switch (size) {
      case AppBadgeSize.micro:
        padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5);
        fontSize = 7.5;
        iconSize = 8.0;
        iconSpacing = 3.0;
        break;
      case AppBadgeSize.small:
        padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2);
        fontSize = 8.5;
        iconSize = 9.5;
        iconSpacing = 4.0;
        break;
      case AppBadgeSize.medium:
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        fontSize = 11.0;
        iconSize = 13.0;
        iconSpacing = 5.0;
        break;
      case AppBadgeSize.large:
        padding = const EdgeInsets.symmetric(horizontal: 13, vertical: 6);
        fontSize = 12.5;
        iconSize = 15.0;
        iconSpacing = 6.0;
        break;
    }

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: iconSize,
            color: textColor,
          ),
          SizedBox(width: iconSpacing),
        ],
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );

    Widget badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: content,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: badge,
      );
    }

    return badge;
  }
}

/// Backward compatibility: standard Red Pill Badge for New Transactions (Micro size)
class NewBadge extends StatelessWidget {
  final AppBadgeSize size;
  const NewBadge({super.key, this.size = AppBadgeSize.micro});

  @override
  Widget build(BuildContext context) {
    return AppBadge.destructive(
      text: 'NEW',
      size: size,
    );
  }
}

/// Backward compatibility: standard Orange/Amber Pill Badge for Missing Reason Transactions (Micro size)
class ReasonBadge extends StatelessWidget {
  final AppBadgeSize size;
  const ReasonBadge({super.key, this.size = AppBadgeSize.micro});

  @override
  Widget build(BuildContext context) {
    return AppBadge.warning(
      text: 'REASON?',
      size: size,
    );
  }
}
