import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_back_button.dart';

/// Universal Screen Header and Top Navigation Bar for screens.
class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final bool centerTitle;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 16, 12),
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showBackButton) ...[
            AppBackButton(onPressed: onBack),
            const SizedBox(width: 6),
          ] else if (!centerTitle)
            const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.heading1.copyWith(
                    color: context.themeTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      color: context.themeTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (showBackButton && centerTitle)
            const SizedBox(width: 48), // balance back button width
        ],
      ),
    );
  }
}
