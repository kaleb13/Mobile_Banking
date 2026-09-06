import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'frosted_glass_noise_painter.dart';

/// Color variant for [AppBannerCard].
enum AppBannerCardVariant {
  /// Emerald green ambient palette (default for banking tips & onboarding).
  emerald,

  /// Warm orange-with-red sunset ambient palette (for highlighted features & actions).
  orangeRed,
}

/// Trailing action style for [AppBannerCard].
enum AppBannerCardTrailing {
  /// Dismissible 'X' button to dismiss this banner permanently.
  close,

  /// Action arrow indicating forward navigation or trigger.
  arrow,

  /// Subtle right chevron.
  chevron,

  /// No trailing element.
  none,
}

/// A versatile, ambient full-width or pill-shaped banner card.
///
/// Features:
/// - Full-bleed multi-stop gradient background.
/// - Ambient dual radial glows (top-right and bottom-left).
/// - Micro-noise frosted ash grain texture ([FrostedGlassNoisePainter]).
/// - Zero borders, clean radius clipping.
/// - Pure foreground layer containing only icons, text, and trailing action.
///
/// Use [AppBannerCard.onboarding] for dismissible informational banners with an 'X' icon.
/// Use [AppBannerCard.feature] for prominent orange-red feature cards with a forward arrow.
class AppBannerCard extends StatelessWidget {
  /// Informational or feature message.
  final String text;

  /// Optional custom text style (defaults to white 12.5px w500).
  final TextStyle? textStyle;

  /// Icon on the left. Defaults to [Icons.auto_awesome_rounded]. Pass null to hide.
  final IconData? leadingIcon;

  /// Color & atmospheric theme variant.
  final AppBannerCardVariant variant;

  /// Trailing element style.
  final AppBannerCardTrailing trailing;

  /// Optional custom trailing icon when [trailing] is [AppBannerCardTrailing.arrow].
  final IconData? trailingIcon;

  /// Callback triggered when the 'X' close button is pressed.
  final VoidCallback? onDismiss;

  /// Callback triggered when the card is tapped.
  final VoidCallback? onTap;

  /// Outer margin. Defaults to [EdgeInsets.zero] for edge-to-edge full screen fit.
  final EdgeInsetsGeometry margin;

  /// Inner padding for the content layer.
  final EdgeInsetsGeometry padding;

  /// Corner radius. Defaults to [AppRadius.cardRadius] to match the app's signature roundness.
  final BorderRadius? borderRadius;

  /// Whether to render the subtle frosted glass noise texture.
  final bool showNoise;

  const AppBannerCard({
    super.key,
    required this.text,
    this.textStyle,
    this.leadingIcon = Icons.auto_awesome_rounded,
    this.variant = AppBannerCardVariant.emerald,
    this.trailing = AppBannerCardTrailing.close,
    this.trailingIcon,
    this.onDismiss,
    this.onTap,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderRadius,
    this.showNoise = true,
  });

  /// Factory constructor for dismissible onboarding & tip banners.
  ///
  /// Features an 'X' icon on the right that triggers [onDismiss] to remove it forever.
  factory AppBannerCard.onboarding({
    Key? key,
    required String text,
    TextStyle? textStyle,
    IconData? leadingIcon = Icons.auto_awesome_rounded,
    VoidCallback? onDismiss,
    VoidCallback? onTap,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    BorderRadius? borderRadius,
    AppBannerCardVariant variant = AppBannerCardVariant.emerald,
  }) {
    return AppBannerCard(
      key: key,
      text: text,
      textStyle: textStyle,
      leadingIcon: leadingIcon,
      variant: variant,
      trailing: AppBannerCardTrailing.close,
      onDismiss: onDismiss,
      onTap: onTap,
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
    );
  }

  /// Factory constructor for orange-red gradient feature cards with an arrow icon.
  factory AppBannerCard.feature({
    Key? key,
    required String text,
    TextStyle? textStyle,
    IconData? leadingIcon = Icons.auto_awesome_rounded,
    IconData trailingIcon = Icons.arrow_forward_rounded,
    VoidCallback? onTap,
    VoidCallback? onDismiss,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    BorderRadius? borderRadius,
    AppBannerCardVariant variant = AppBannerCardVariant.orangeRed,
  }) {
    return AppBannerCard(
      key: key,
      text: text,
      textStyle: textStyle,
      leadingIcon: leadingIcon,
      variant: variant,
      trailing: AppBannerCardTrailing.arrow,
      trailingIcon: trailingIcon,
      onTap: onTap,
      onDismiss: onDismiss,
      margin: margin,
      padding: padding,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppRadius.cardRadius;

    return Container(
      width: double.infinity,
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: effectiveRadius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── 1. BACKGROUND LAYER: Full-Bleed Gradient ──
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getGradientColors(),
                        stops: const [0.0, 0.45, 1.0],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                  ),
                ),

                // ── 2. BACKGROUND LAYER: Ambient Radial Glow (Top-Right) ──
                Positioned(
                  top: -45,
                  right: -25,
                  width: 150,
                  height: 150,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _getTopRightGlowColors(),
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── 3. BACKGROUND LAYER: Subtle Secondary Glow (Bottom-Left) ──
                Positioned(
                  bottom: -35,
                  left: -25,
                  width: 130,
                  height: 130,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: _getBottomLeftGlowColors(),
                      ),
                    ),
                  ),
                ),

                // ── 4. BACKGROUND LAYER: Micro-Noise Ash Texture ──
                if (showNoise)
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: FrostedGlassNoisePainter(
                        pointCount: 220,
                        lightAlpha: 0.07,
                        darkAlpha: 0.07,
                      ),
                    ),
                  ),

                // ── 5. TOP / FOREGROUND LAYER: Pure Icons & Text ONLY ──
                Padding(
                  padding: padding,
                  child: Row(
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(
                          leadingIcon,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          text,
                          style: textStyle ??
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildTrailing(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (variant) {
      case AppBannerCardVariant.emerald:
        return const [
          AppColors.analysisCardGradientStart,
          AppColors.analysisCardGradientMid,
          AppColors.analysisCardGradientEnd,
        ];
      case AppBannerCardVariant.orangeRed:
        return const [
          AppColors.bannerOrangeRedStart,
          AppColors.bannerOrangeRedMid,
          AppColors.bannerOrangeRedEnd,
        ];
    }
  }

  List<Color> _getTopRightGlowColors() {
    switch (variant) {
      case AppBannerCardVariant.emerald:
        return [
          AppColors.brandGreen.withValues(alpha: 0.38),
          AppColors.brandGreen.withValues(alpha: 0.15),
          Colors.transparent,
        ];
      case AppBannerCardVariant.orangeRed:
        return [
          AppColors.bannerOrangeGlow.withValues(alpha: 0.42),
          AppColors.bannerOrangeGlow.withValues(alpha: 0.16),
          Colors.transparent,
        ];
    }
  }

  List<Color> _getBottomLeftGlowColors() {
    switch (variant) {
      case AppBannerCardVariant.emerald:
        return [
          AppColors.analysisAmbientGlow.withValues(alpha: 0.35),
          Colors.transparent,
        ];
      case AppBannerCardVariant.orangeRed:
        return [
          AppColors.bannerRedGlow.withValues(alpha: 0.35),
          Colors.transparent,
        ];
    }
  }

  Widget _buildTrailing(BuildContext context) {
    switch (trailing) {
      case AppBannerCardTrailing.close:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            onDismiss?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        );
      case AppBannerCardTrailing.arrow:
        return Icon(
          trailingIcon ?? Icons.arrow_forward_rounded,
          color: Colors.white.withValues(alpha: 0.85),
          size: 18,
        );
      case AppBannerCardTrailing.chevron:
        return Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.75),
          size: 20,
        );
      case AppBannerCardTrailing.none:
        return const SizedBox.shrink();
    }
  }
}
