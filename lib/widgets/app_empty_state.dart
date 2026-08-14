import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';

/// Standardized Empty State component for lists, search results, and filters.
class AppEmptyState extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.iconWidget,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? AppColors.brandGreen;

    Widget visual;
    if (iconWidget != null) {
      visual = iconWidget!;
    } else {
      visual = Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: effectiveIconColor,
          size: 34,
        ),
      );
    }

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            visual,
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(
                color: context.themeTextPrimary,
              ),
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.themeTextSecondary,
                ),
              ),
            ],
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              AppButton.primary(
                text: actionText!,
                onPressed: onAction,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
