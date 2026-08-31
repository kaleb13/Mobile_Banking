import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// A sleek, high-performance Animated Balance Text widget for fintech apps.
///
/// Smoothly interpolates numeric balance changes using an elastic cubic curve,
/// splitting integer and decimal numbers for refined visual hierarchy.
class AnimatedBalanceText extends StatelessWidget {
  final double value;
  final Duration duration;
  final Curve curve;
  final TextStyle? integerStyle;
  final TextStyle? decimalStyle;
  final String prefix;
  final String suffix;
  final bool isMasked;
  final String maskText;
  final bool isUnknown;

  const AnimatedBalanceText({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 450),
    this.curve = Curves.easeOutCubic,
    this.integerStyle,
    this.decimalStyle,
    this.prefix = '',
    this.suffix = '',
    this.isMasked = false,
    this.maskText = '••••••',
    this.isUnknown = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMasked) {
      return Text(
        '$prefix$maskText$suffix',
        style: integerStyle ?? AppTypography.displayLarge,
      );
    }

    if (isUnknown) {
      return Text(
        'Unknown',
        style: (integerStyle ?? AppTypography.displayLarge).copyWith(
          fontSize: (integerStyle?.fontSize != null)
              ? integerStyle!.fontSize! * 0.85
              : 28,
        ),
      );
    }

    final defaultIntStyle = integerStyle ??
        AppTypography.displayLarge.copyWith(
          color: AppColors.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        );

    final defaultDecStyle = decimalStyle ??
        defaultIntStyle.copyWith(
          fontSize: defaultIntStyle.fontSize != null
              ? defaultIntStyle.fontSize! * 0.58
              : 18,
          color: defaultIntStyle.color?.withValues(alpha: 0.55) ??
              AppColors.textSoft,
          fontWeight: FontWeight.w500,
        );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: duration,
      curve: curve,
      builder: (context, animatedValue, child) {
        final formatted = NumberFormat('#,##0.00').format(animatedValue);
        final parts = formatted.split('.');
        final integerPart = parts[0];
        final decimalPart = parts.length > 1 ? '.${parts[1]}' : '.00';

        return Text.rich(
          TextSpan(
            children: [
              if (prefix.isNotEmpty)
                TextSpan(
                  text: prefix,
                  style: defaultIntStyle,
                ),
              TextSpan(
                text: integerPart,
                style: defaultIntStyle,
              ),
              TextSpan(
                text: decimalPart,
                style: defaultDecStyle,
              ),
              if (suffix.isNotEmpty)
                TextSpan(
                  text: suffix,
                  style: defaultDecStyle,
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
