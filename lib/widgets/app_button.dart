import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum AppButtonVariant {
  primary,
  secondary,
  destructive,
  pill,
}

/// Standardized Button component for the Mobile Banking application.
/// 
/// Strictly adheres to:
/// - 100% Fully rounded pill shape (`borderRadius = 100.0`).
/// - Zero borders / outlines.
/// - Primary: Crisp white background with dark contrast text (#0F172A).
/// - Secondary: Glass-like translucent dark background with clean white text (Used for all secondary & cancel actions).
/// - Destructive: Single unified soft-red danger button (#E11D48 @ 14% tint + crimson text).
/// - Pill: Selectable filter & category chips.
class AppButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool fullWidth;
  final double? width;
  final double? minWidth;
  final double? maxWidth;
  final double? height;
  final double borderRadius;
  final double elevation;
  final bool isSelected; // For pill variant
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final double? iconSize;
  final Color? customBackgroundColor;
  final Color? customTextColor;
  final String? tooltip;

  const AppButton.primary({
    super.key,
    required String this.text,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height = 50.0,
    this.borderRadius = 100.0,
    this.elevation = 0.0,
    this.padding,
    this.fontSize,
    this.iconSize,
    this.tooltip,
  })  : variant = AppButtonVariant.primary,
        isSelected = false,
        customBackgroundColor = null,
        customTextColor = null;

  const AppButton.secondary({
    super.key,
    required String this.text,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height = 48.0,
    this.borderRadius = 100.0,
    this.elevation = 0.0,
    this.padding,
    this.fontSize,
    this.iconSize,
    this.tooltip,
  })  : variant = AppButtonVariant.secondary,
        isSelected = false,
        customBackgroundColor = null,
        customTextColor = null;

  /// Single unified danger / destructive button (soft red translucent tint + crimson text)
  const AppButton.destructive({
    super.key,
    required String this.text,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = true,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height = 48.0,
    this.borderRadius = 100.0,
    this.elevation = 0.0,
    this.padding,
    this.fontSize,
    this.iconSize,
    this.tooltip,
  })  : variant = AppButtonVariant.destructive,
        isSelected = false,
        customBackgroundColor = null,
        customTextColor = null;

  const AppButton.pill({
    super.key,
    required String this.text,
    required this.onPressed,
    required this.isSelected,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.fullWidth = false,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.height = 34.0,
    this.borderRadius = 100.0,
    this.elevation = 0.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    this.fontSize,
    this.iconSize,
    this.tooltip,
  })  : variant = AppButtonVariant.pill,
        customBackgroundColor = null,
        customTextColor = null;

  @override
  Widget build(BuildContext context) {
    final bool isInteractive = onPressed != null && !isLoading;
    final bool isCompact = height != null && height! <= 34.0;

    Color bg;
    Color textColor;

    switch (variant) {
      case AppButtonVariant.primary:
        bg = customBackgroundColor ??
            (isInteractive
                ? AppColors.buttonPrimary
                : AppColors.buttonPrimaryDisabled);
        textColor = customTextColor ?? AppColors.buttonPrimaryText;
        break;

      case AppButtonVariant.secondary:
        bg = customBackgroundColor ??
            (isInteractive
                ? AppColors.buttonSecondary
                : AppColors.buttonSecondary.withValues(alpha: 0.05));
        textColor = customTextColor ?? AppColors.buttonSecondaryText;
        break;

      case AppButtonVariant.destructive:
        bg = customBackgroundColor ??
            (isInteractive
                ? AppColors.buttonSoftDestructiveBg
                : AppColors.buttonSoftDestructiveBg.withValues(alpha: 0.5));
        textColor = customTextColor ?? AppColors.buttonDestructive;
        break;

      case AppButtonVariant.pill:
        if (isSelected) {
          bg = customBackgroundColor ?? AppColors.buttonPrimary;
          textColor = customTextColor ?? AppColors.buttonPrimaryText;
        } else {
          bg = customBackgroundColor ?? AppColors.buttonSecondary;
          textColor = customTextColor ?? AppColors.textSecondary;
        }
        break;
    }

    final double effectiveFontSize = fontSize ??
        (isCompact
            ? 12.0
            : (variant == AppButtonVariant.pill ? 12.0 : 14.0));
    final double effectiveIconSize = iconSize ??
        (isCompact
            ? 13.5
            : (variant == AppButtonVariant.pill ? 14.0 : 18.0));
    final double effectiveSpacing = isCompact ? 4.0 : 8.0;

    final TextStyle textStyle = variant == AppButtonVariant.pill
        ? TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: effectiveFontSize,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: textColor,
          )
        : AppTypography.button.copyWith(
            color: textColor,
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.bold,
          );

    Widget content;
    if (isLoading) {
      content = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(textColor),
        ),
      );
    } else {
      final List<Widget> children = [];
      if (icon != null) {
        children.add(Icon(icon, size: effectiveIconSize, color: textColor));
        children.add(SizedBox(width: effectiveSpacing));
      }
      if (text != null) {
        children.add(
          Flexible(
            fit: fullWidth ? FlexFit.loose : FlexFit.loose,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text!,
                style: textStyle,
                maxLines: 1,
              ),
            ),
          ),
        );
      }
      if (trailingIcon != null) {
        children.add(SizedBox(width: effectiveSpacing));
        children.add(Icon(trailingIcon, size: effectiveIconSize, color: textColor));
      }

      content = Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children,
      );
    }

    final BoxConstraints? effectiveConstraints =
        (minWidth != null || maxWidth != null)
            ? BoxConstraints(
                minWidth: minWidth ?? 0.0,
                maxWidth: maxWidth ?? double.infinity,
              )
            : null;

    final double? effectiveWidth = fullWidth ? double.infinity : width;
    final EdgeInsetsGeometry effectivePadding = padding ??
        (isCompact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 8));

    Widget coreButton = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: effectiveWidth,
      height: height,
      constraints: effectiveConstraints,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: elevation * 2.2,
                  offset: Offset(0, elevation * 0.7),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: isInteractive
            ? InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
                splashColor: (variant == AppButtonVariant.primary
                        ? AppColors.buttonPrimaryText
                        : Colors.white)
                    .withValues(alpha: 0.12),
                highlightColor: (variant == AppButtonVariant.primary
                        ? AppColors.buttonPrimaryText
                        : Colors.white)
                    .withValues(alpha: 0.06),
                child: Padding(
                  padding: effectivePadding,
                  child: Center(
                    widthFactor: fullWidth || effectiveWidth != null ? null : 1.0,
                    heightFactor: height != null ? null : 1.0,
                    child: content,
                  ),
                ),
              )
            : Padding(
                padding: effectivePadding,
                child: Center(
                  widthFactor: fullWidth || effectiveWidth != null ? null : 1.0,
                  heightFactor: height != null ? null : 1.0,
                  child: content,
                ),
              ),
      ),
    );

    if (tooltip != null) {
      coreButton = Tooltip(
        message: tooltip!,
        child: coreButton,
      );
    }

    return coreButton;
  }
}
