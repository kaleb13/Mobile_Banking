import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Predefined iOS gradient presets matching Apple design guidelines.
enum AppIconBadgeColor {
  green, // Face ID, Biometrics, Success, Active (#34D399 -> #059669)
  blue, // Privacy, Security, Info, Cloud, PIN (#60A5FA -> #2563EB)
  red, // Emergency, SOS, Danger, Reset, Remove PIN (#F87171 -> #DC2626)
  coral, // Notifications, Alerts, Sounds (#FB7185 -> #E11D48)
  orange, // Warm Amber, Action, Recurring, Templates (#FB923C -> #EA580C)
  yellow, // Gold, Storage, Backup, Lock (#FBBF24 -> #D97706)
  purple, // Focus, Categories, Custom Rules, Settings (#C084FC -> #7C3AED)
  indigo, // Deep Indigo, Calendar, Schedule (#818CF8 -> #4F46E5)
  teal, // Maintenance, Metadata, Refresh (#2DD4BF -> #0D9488)
  cyan, // Sky blue, Permissions, Cloud (#38BDF8 -> #0284C7)
  pink, // Rewards, Badges, Heart (#F472B6 -> #DB2777)
  slate, // Neutral, System, About (#64748B -> #334155)
  black, // Wallet, Apple Pay, Dark Slate (#334155 -> #0F172A)
}

/// Standardized iOS-style gradient icon badge with a vibrant gradient squircle
/// background and a centered, crisp pure white icon.
///
/// Ensures consistent high-contrast, theme-agnostic visual hierarchy across
/// both light and dark themes.
class AppIconBadge extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final Widget? customChild;
  final double size;
  final double iconSize;
  final double? borderRadius;
  final LinearGradient gradient;

  const AppIconBadge({
    super.key,
    this.icon,
    this.svgAsset,
    this.customChild,
    this.size = 32.0,
    this.iconSize = 18.0,
    this.borderRadius,
    required this.gradient,
  });

  /// Factory constructor for predefined iOS gradient presets.
  factory AppIconBadge.preset({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    required AppIconBadgeColor color,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) {
    return AppIconBadge(
      key: key,
      icon: icon,
      svgAsset: svgAsset,
      customChild: customChild,
      size: size,
      iconSize: iconSize,
      borderRadius: borderRadius,
      gradient: _gradientFor(color),
    );
  }

  // ── Convenient Named Constructors ──────────────────────────────────────────

  factory AppIconBadge.green({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.green,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.blue({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.blue,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.red({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.red,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.coral({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.coral,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.orange({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.orange,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.yellow({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.yellow,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.purple({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.purple,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.indigo({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.indigo,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.teal({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.teal,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.cyan({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.cyan,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.pink({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.pink,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.slate({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) =>
      AppIconBadge.preset(
        key: key,
        icon: icon,
        svgAsset: svgAsset,
        customChild: customChild,
        color: AppIconBadgeColor.slate,
        size: size,
        iconSize: iconSize,
        borderRadius: borderRadius,
      );

  factory AppIconBadge.fromColor({
    Key? key,
    IconData? icon,
    String? svgAsset,
    Widget? customChild,
    required Color color,
    double size = 32.0,
    double iconSize = 18.0,
    double? borderRadius,
  }) {
    // Generate smooth, luminous vertical top-to-bottom gradient with a lighter/whiter top tone
    final HSLColor hsl = HSLColor.fromColor(color);
    final Color topColor = hsl
        .withLightness((hsl.lightness + 0.22).clamp(0.0, 0.88))
        .withSaturation((hsl.saturation * 0.95).clamp(0.0, 1.0))
        .toColor();
    final Color bottomColor = hsl
        .withLightness((hsl.lightness + 0.04).clamp(0.0, 0.72))
        .toColor();

    return AppIconBadge(
      key: key,
      icon: icon,
      svgAsset: svgAsset,
      customChild: customChild,
      size: size,
      iconSize: iconSize,
      borderRadius: borderRadius,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ),
    );
  }

  static LinearGradient _gradientFor(AppIconBadgeColor color) {
    switch (color) {
      case AppIconBadgeColor.green:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6EE7B7), Color(0xFF10B981)],
        );
      case AppIconBadgeColor.blue:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF93C5FD), Color(0xFF3B82F6)],
        );
      case AppIconBadgeColor.red:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFCA5A5), Color(0xFFEF4444)],
        );
      case AppIconBadgeColor.coral:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDA4AF), Color(0xFFF43F5E)],
        );
      case AppIconBadgeColor.orange:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDBA74), Color(0xFFF97316)],
        );
      case AppIconBadgeColor.yellow:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDE047), Color(0xFFF59E0B)],
        );
      case AppIconBadgeColor.purple:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9D5FF), Color(0xFFA855F7)],
        );
      case AppIconBadgeColor.indigo:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC7D2FE), Color(0xFF6366F1)],
        );
      case AppIconBadgeColor.teal:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF99F6E4), Color(0xFF14B8A6)],
        );
      case AppIconBadgeColor.cyan:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBAE6FD), Color(0xFF0EA5E9)],
        );
      case AppIconBadgeColor.pink:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBCFE8), Color(0xFFEC4899)],
        );
      case AppIconBadgeColor.slate:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCBD5E1), Color(0xFF64748B)],
        );
      case AppIconBadgeColor.black:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF64748B), Color(0xFF1E293B)],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? (size * 0.32);

    Widget childWidget;
    if (customChild != null) {
      childWidget = customChild!;
    } else if (svgAsset != null) {
      childWidget = SvgPicture.asset(
        svgAsset!,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    } else if (icon != null) {
      childWidget = Icon(
        icon,
        color: Colors.white,
        size: iconSize,
      );
    } else {
      childWidget = const SizedBox.shrink();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: childWidget,
    );
  }
}
