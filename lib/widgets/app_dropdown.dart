import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Visual style variant for [AppDropdown].
enum AppDropdownVariant {
  /// Optimized for white / light background surfaces (e.g. homepage transaction sheet).
  light,

  /// Optimized for dark / translucent background surfaces (e.g. search screen, dark sheets).
  dark,

  /// Automatically adapts based on the active theme surface brightness.
  auto,
}

/// Item model for [AppDropdown].
class AppDropdownItem<T> {
  final T value;
  final String label;
  final Widget? leading;
  final IconData? icon;
  final String? subtitle;

  const AppDropdownItem({
    required this.value,
    required this.label,
    this.leading,
    this.icon,
    this.subtitle,
  });
}

/// Standardized design system Dropdown component.
///
/// Features 100% rounded pill triggers, custom menu popups with rounded corners,
/// zero border strokes, and dedicated light and dark variants.
class AppDropdown<T> extends StatelessWidget {
  /// Currently selected value.
  final T? value;

  /// Available options.
  final List<AppDropdownItem<T>> items;

  /// Callback when a value is chosen.
  final ValueChanged<T?> onChanged;

  /// Visual theme variant (light for white sheets, dark for dark surfaces).
  final AppDropdownVariant variant;

  /// Maximum width constraint for the selected text and menu items.
  final double? maxWidth;

  /// Trigger button height (defaults to 32).
  final double height;

  /// Border radius for the trigger and dropdown menu popup (defaults to 16).
  final double borderRadius;

  /// Custom padding for the trigger button.
  final EdgeInsetsGeometry? padding;

  /// Optional prefix widget before the label.
  final Widget? prefix;

  /// Dropdown chevron / indicator icon.
  final IconData? icon;

  /// Explicit default state override. If null, inferred automatically.
  final bool? isDefault;

  /// Placeholder text when value is null.
  final String placeholder;

  /// Custom background color override for the trigger button.
  final Color? backgroundColor;

  /// Custom background color override for the popup menu.
  final Color? dropdownColor;

  /// Custom text color override for the trigger button.
  final Color? textColor;

  /// Custom icon color override for the trigger button.
  final Color? iconColor;

  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.variant = AppDropdownVariant.dark,
    this.maxWidth,
    this.height = 32,
    this.borderRadius = 16,
    this.padding,
    this.prefix,
    this.icon,
    this.isDefault,
    this.placeholder = 'Select',
    this.backgroundColor,
    this.dropdownColor,
    this.textColor,
    this.iconColor,
  });

  /// Factory constructor for white / light background surfaces.
  factory AppDropdown.light({
    Key? key,
    required T? value,
    required List<AppDropdownItem<T>> items,
    required ValueChanged<T?> onChanged,
    double? maxWidth,
    double height = 32,
    double borderRadius = 16,
    EdgeInsetsGeometry? padding,
    Widget? prefix,
    IconData? icon,
    bool? isDefault,
    String placeholder = 'Select',
    Color? backgroundColor,
    Color? dropdownColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppDropdown<T>(
      key: key,
      value: value,
      items: items,
      onChanged: onChanged,
      variant: AppDropdownVariant.light,
      maxWidth: maxWidth,
      height: height,
      borderRadius: borderRadius,
      padding: padding,
      prefix: prefix,
      icon: icon,
      isDefault: isDefault,
      placeholder: placeholder,
      backgroundColor: backgroundColor,
      dropdownColor: dropdownColor,
      textColor: textColor,
      iconColor: iconColor,
    );
  }

  /// Factory constructor for dark background surfaces.
  factory AppDropdown.dark({
    Key? key,
    required T? value,
    required List<AppDropdownItem<T>> items,
    required ValueChanged<T?> onChanged,
    double? maxWidth,
    double height = 32,
    double borderRadius = 16,
    EdgeInsetsGeometry? padding,
    Widget? prefix,
    IconData? icon,
    bool? isDefault,
    String placeholder = 'Select',
    Color? backgroundColor,
    Color? dropdownColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppDropdown<T>(
      key: key,
      value: value,
      items: items,
      onChanged: onChanged,
      variant: AppDropdownVariant.dark,
      maxWidth: maxWidth,
      height: height,
      borderRadius: borderRadius,
      padding: padding,
      prefix: prefix,
      icon: icon,
      isDefault: isDefault,
      placeholder: placeholder,
      backgroundColor: backgroundColor,
      dropdownColor: dropdownColor,
      textColor: textColor,
      iconColor: iconColor,
    );
  }

  /// Convenience factory for simple `List<String>` items.
  static Widget simple({
    Key? key,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    AppDropdownVariant variant = AppDropdownVariant.dark,
    double? maxWidth,
    double height = 32,
    double borderRadius = 16,
    EdgeInsetsGeometry? padding,
    Widget? prefix,
    IconData? icon,
    bool? isDefault,
    Color? backgroundColor,
    Color? dropdownColor,
    Color? textColor,
    Color? iconColor,
  }) {
    final dropdownItems = items
        .map((item) => AppDropdownItem<String>(value: item, label: item))
        .toList();

    return AppDropdown<String>(
      key: key,
      value: value,
      items: dropdownItems,
      onChanged: onChanged,
      variant: variant,
      maxWidth: maxWidth,
      height: height,
      borderRadius: borderRadius,
      padding: padding,
      prefix: prefix,
      icon: icon,
      isDefault: isDefault,
      backgroundColor: backgroundColor,
      dropdownColor: dropdownColor,
      textColor: textColor,
      iconColor: iconColor,
    );
  }

  bool _computeIsDefault() {
    if (isDefault != null) return isDefault!;
    if (value == null) return true;
    final str = value.toString();
    return str == 'All' ||
        str == 'Any Time' ||
        str == 'All Senders' ||
        str == 'All Banks' ||
        (items.isNotEmpty && items.first.value == value);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = variant == AppDropdownVariant.light ||
        (variant == AppDropdownVariant.auto &&
            Theme.of(context).brightness == Brightness.light);

    final bool isDef = _computeIsDefault();

    // Trigger styling
    final Color triggerBg = backgroundColor ??
        (isLight
            ? (isDef
                ? AppColors.lightGreyBackground
                : AppColors.bgDeepLight)
            : (isDef
                ? AppColors.surface
                : AppColors.surface));

    final Color effectiveTextColor = textColor ??
        (isLight
            ? (isDef ? AppColors.mediumGreyText : AppColors.darkCharcoal)
            : (isDef ? AppColors.textSecondary : Colors.white));

    final Color effectiveIconColor = iconColor ??
        (isLight
            ? (isDef ? AppColors.mediumGreyText : AppColors.darkCharcoal)
            : (isDef ? AppColors.textSecondary : Colors.white));

    // Popup styling
    final Color menuBg = dropdownColor ?? (isLight ? Colors.white : AppColors.surfaceElevated);
    final Color itemTextColor = isLight ? AppColors.darkCharcoal : Colors.white;

    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: triggerBg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 4),
          ],
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isDense: true,
              value: value,
              icon: Padding(
                padding: const EdgeInsets.only(left: 4.0),
                child: Icon(
                  icon ?? Icons.keyboard_arrow_down_rounded,
                  color: effectiveIconColor,
                  size: 16,
                ),
              ),
              dropdownColor: menuBg,
              borderRadius: BorderRadius.circular(borderRadius),
              menuMaxHeight: 300,
              elevation: 8,
              style: TextStyle(
                color: effectiveTextColor,
                fontSize: 12,
                fontWeight: isDef ? FontWeight.w500 : FontWeight.w700,
              ),
              onChanged: onChanged,
              items: items.map((AppDropdownItem<T> item) {
                return DropdownMenuItem<T>(
                  value: item.value,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth ?? 160),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.leading != null) ...[
                          item.leading!,
                          const SizedBox(width: 8),
                        ] else if (item.icon != null) ...[
                          Icon(item.icon, size: 16, color: itemTextColor),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: itemTextColor,
                              fontSize: 13,
                              fontWeight:
                                  item.value == value ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
