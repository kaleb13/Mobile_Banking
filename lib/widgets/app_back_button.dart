import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Style variants for [AppBackButton].
enum AppBackButtonVariant {
  /// Automatically adapts background and icon colors to active theme/brightness.
  auto,

  /// Optimized for dark surfaces with dark surface background and white icon.
  dark,

  /// Optimized for light / white surfaces with light grey background and dark icon.
  light,
}

/// Universal back button component for the application with a medium-sized circular
/// background, centered BackForNav SVG icon, and unified light/dark behaviors.
class AppBackButton extends StatelessWidget {
  /// Callback when the back button is pressed.
  /// If null, defaults to [Navigator.maybePop].
  final VoidCallback? onPressed;

  /// Custom icon color override.
  final Color? color;

  /// Custom circle background color override.
  final Color? backgroundColor;

  /// Total outer diameter of the circular button (defaults to 36.0).
  final double size;

  /// Rendered size of the BackForNav SVG icon (defaults to 16.0).
  final double iconSize;

  /// Outer padding around the circular button.
  final EdgeInsetsGeometry? padding;

  /// Color styling variant (auto, dark, light).
  final AppBackButtonVariant variant;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 36.0,
    this.iconSize = 16.0,
    this.padding,
    this.variant = AppBackButtonVariant.auto,
  });

  /// Named constructor for dark background sections.
  const AppBackButton.dark({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 36.0,
    this.iconSize = 16.0,
    this.padding,
  }) : variant = AppBackButtonVariant.dark;

  /// Named constructor for light / white background sections.
  const AppBackButton.light({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 36.0,
    this.iconSize = 16.0,
    this.padding,
  }) : variant = AppBackButtonVariant.light;

  @override
  Widget build(BuildContext context) {
    final bool isLight = variant == AppBackButtonVariant.light ||
        (variant == AppBackButtonVariant.auto &&
            Theme.of(context).brightness == Brightness.light);

    final Color effectiveBgColor = backgroundColor ??
        (isLight ? AppColors.lightGreyBackground : AppColors.surface);

    final Color effectiveIconColor = color ??
        (isLight ? AppColors.darkCharcoal : Colors.white);

    final Widget buttonContent = Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (onPressed != null) {
            onPressed!();
          } else {
            Navigator.maybePop(context);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/images/BackForNav.svg',
            width: iconSize,
            height: iconSize,
            colorFilter: ColorFilter.mode(effectiveIconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: buttonContent,
      );
    }

    return buttonContent;
  }
}
