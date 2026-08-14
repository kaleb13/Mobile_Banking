import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Universal Card container that automatically adapts surface color
/// based on the active theme mode.
/// 
/// Strictly adheres to the zero-border / zero-stroke design system rule.
/// Card depth and separation are achieved purely through background surface colors
/// (`themeSurface`, `themeSurfaceElevated`, etc.) and corner radius clipping.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? customColor;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 16,
    this.onTap,
    this.customColor,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = customColor ?? context.themeSurface;

    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: clipBehavior,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
