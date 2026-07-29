import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Universal back button component for the app using the standard BackForNav SVG icon.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final EdgeInsetsGeometry? padding;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color = Colors.white,
    this.size = 20.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = SvgPicture.asset(
      'assets/images/BackForNav.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    return IconButton(
      icon: iconWidget,
      padding: padding ?? const EdgeInsets.all(8.0),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}
