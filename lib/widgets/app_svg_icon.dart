import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Standardized, dynamic SVG Icon component that automatically adapts its monochrome
/// (dark vs. light) appearance based on the background surface luminance or explicit flag,
/// while allowing custom brand/semantic colors (e.g. green, red, gold) when specified.
class AppSvgIcon extends StatelessWidget {
  final String assetPath;
  final double? size;
  final double? width;
  final double? height;
  final BoxFit fit;

  /// Explicit color override. When provided (e.g. emerald, red, gold),
  /// the icon renders in this exact color regardless of background.
  final Color? color;

  /// Explicit flag to force the light-surface (dark icon) variant.
  /// If null, color is computed dynamically from [surfaceColor] or [BuildContext].
  final bool? onLightSurface;

  /// The background color behind this icon. When provided, the icon automatically
  /// computes whether it needs a dark or light contrast color via relative luminance.
  final Color? surfaceColor;

  /// Blend mode for the color filter (defaults to [BlendMode.srcIn]).
  final BlendMode blendMode;

  const AppSvgIcon(
    this.assetPath, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.onLightSurface,
    this.surfaceColor,
    this.blendMode = BlendMode.srcIn,
  });

  /// Convenient constructor for an icon placed on a light/white background.
  const AppSvgIcon.onLight(
    this.assetPath, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.surfaceColor,
    this.blendMode = BlendMode.srcIn,
  }) : onLightSurface = true;

  /// Convenient constructor for an icon placed on a dark background.
  const AppSvgIcon.onDark(
    this.assetPath, {
    super.key,
    this.size,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.surfaceColor,
    this.blendMode = BlendMode.srcIn,
  }) : onLightSurface = false;

  @override
  Widget build(BuildContext context) {
    final double effectiveWidth = width ?? size ?? 20.0;
    final double effectiveHeight = height ?? size ?? 20.0;

    // Resolve dynamic monochrome color if no explicit color was passed
    final Color effectiveColor = color ??
        (onLightSurface != null
            ? (onLightSurface! ? AppColors.iconDark : AppColors.iconLight)
            : (surfaceColor != null
                ? surfaceColor!.onIconColor
                : context.themeIconPrimary));

    return SvgPicture.asset(
      assetPath,
      width: effectiveWidth,
      height: effectiveHeight,
      fit: fit,
      colorFilter: ColorFilter.mode(effectiveColor, blendMode),
    );
  }
}
