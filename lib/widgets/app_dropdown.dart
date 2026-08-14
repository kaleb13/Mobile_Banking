import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

/// A generic, theme-adaptive Dropdown component for single and multi-selection.
///
/// Supports both compact pill triggers (for filters/bars) and full-width
/// form triggers with unified design, typography, and selection indicators.
class AppDropdown<T> extends StatelessWidget {
  /// Currently selected value for single-select mode.
  final T? value;

  /// Currently selected values for multi-select mode.
  final List<T>? selectedValues;

  /// Available options to select from.
  final List<AppDropdownItem<T>> items;

  /// Callback when a value is selected in single-select mode.
  final ValueChanged<T>? onChanged;

  /// Callback when values change in multi-select mode.
  final ValueChanged<List<T>>? onMultiChanged;

  /// Placeholder text when no item is selected.
  final String placeholder;

  /// Whether multiple items can be selected.
  final bool isMultiSelect;

  /// Whether the trigger is rendered as a compact pill or full-width container.
  final bool isPill;

  /// Custom height for the trigger button.
  final double? height;

  /// Custom padding for the trigger button.
  final EdgeInsetsGeometry? padding;

  /// Optional prefix widget (e.g. filter icon or bank logo).
  final Widget? prefix;

  /// Whether to display the chevron/dropdown indicator icon.
  final bool showChevron;

  /// Border radius for the trigger and popup menu.
  final double borderRadius;

  /// Background color override.
  final Color? backgroundColor;

  const AppDropdown({
    super.key,
    required this.items,
    this.value,
    this.selectedValues,
    this.onChanged,
    this.onMultiChanged,
    this.placeholder = 'Select',
    this.isMultiSelect = false,
    this.isPill = true,
    this.height,
    this.padding,
    this.prefix,
    this.showChevron = true,
    this.borderRadius = 20,
    this.backgroundColor,
  });

  /// Factory constructor for a compact pill dropdown (ideal for filter bars).
  factory AppDropdown.pill({
    Key? key,
    required List<AppDropdownItem<T>> items,
    T? value,
    ValueChanged<T>? onChanged,
    String placeholder = 'Select',
    Widget? prefix,
    double height = 38,
    double borderRadius = 20,
    Color? backgroundColor,
  }) {
    return AppDropdown<T>(
      key: key,
      items: items,
      value: value,
      onChanged: onChanged,
      placeholder: placeholder,
      isPill: true,
      height: height,
      borderRadius: borderRadius,
      prefix: prefix,
      backgroundColor: backgroundColor,
    );
  }

  /// Factory constructor for a multi-select dropdown.
  factory AppDropdown.multi({
    Key? key,
    required List<AppDropdownItem<T>> items,
    required List<T> selectedValues,
    required ValueChanged<List<T>> onMultiChanged,
    String placeholder = 'Select options',
    bool isPill = false,
    double? height,
    double borderRadius = 16,
    Color? backgroundColor,
  }) {
    return AppDropdown<T>(
      key: key,
      items: items,
      selectedValues: selectedValues,
      onMultiChanged: onMultiChanged,
      placeholder: placeholder,
      isMultiSelect: true,
      isPill: isPill,
      height: height,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
    );
  }

  String _getDisplayLabel() {
    if (isMultiSelect) {
      final selected = selectedValues ?? [];
      if (selected.isEmpty) return placeholder;
      if (selected.length == 1) {
        final match = items.where((i) => i.value == selected.first);
        return match.isNotEmpty ? match.first.label : placeholder;
      }
      return '${selected.length} Selected';
    }

    if (value == null) return placeholder;
    final match = items.where((i) => i.value == value);
    return match.isNotEmpty ? match.first.label : placeholder;
  }

  bool _isItemSelected(T itemValue) {
    if (isMultiSelect) {
      return selectedValues?.contains(itemValue) ?? false;
    }
    return value == itemValue;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? context.themeSurface;
    final displayLabel = _getDisplayLabel();
    final effectivePadding = padding ??
        (isPill
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12));

    final trigger = Container(
      height: height,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: isPill ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment:
            isPill ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
        children: [
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              displayLabel,
              style: (isPill ? AppTypography.titleSmall : AppTypography.bodyMedium)
                  .copyWith(
                color: (value != null || (selectedValues?.isNotEmpty ?? false))
                    ? context.themeTextPrimary
                    : context.themeTextSecondary,
                fontWeight: isPill ? FontWeight.w600 : FontWeight.w500,
                fontSize: isPill ? 12 : 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.unfold_more_rounded,
              color: context.themeTextSecondary,
              size: isPill ? 16 : 18,
            ),
          ],
        ],
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.white.withValues(alpha: 0.14),
        highlightColor: Colors.white.withValues(alpha: 0.10),
      ),
      child: PopupMenuButton<T>(
        offset: Offset(0, (height ?? (isPill ? 34 : 44)) + 6),
        constraints: const BoxConstraints(minWidth: 130, maxWidth: 220),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        color: context.themeSurface,
        elevation: 12,
        borderRadius: BorderRadius.circular(borderRadius),
        onSelected: (T selected) {
          if (isMultiSelect) {
            final current = List<T>.from(selectedValues ?? []);
            if (current.contains(selected)) {
              current.remove(selected);
            } else {
              current.add(selected);
            }
            onMultiChanged?.call(current);
          } else {
            onChanged?.call(selected);
          }
        },
        itemBuilder: (BuildContext menuContext) {
          return items.map((opt) {
            final isSelected = _isItemSelected(opt.value);
            return PopupMenuItem<T>(
              value: opt.value,
              height: 42,
              child: Row(
                children: [
                  if (opt.leading != null) ...[
                    opt.leading!,
                    const SizedBox(width: 10),
                  ] else if (opt.icon != null) ...[
                    Icon(opt.icon,
                        color: isSelected
                            ? AppColors.brandGreen
                            : menuContext.themeTextSecondary,
                        size: 18),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          opt.label,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isSelected
                                ? menuContext.themeTextPrimary
                                : menuContext.themeTextSecondary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (opt.subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            opt.subtitle!,
                            style: AppTypography.bodySmall.copyWith(
                              color: menuContext.themeTextSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.check_rounded,
                      color: AppColors.brandGreen,
                      size: 18,
                    ),
                  ],
                ],
              ),
            );
          }).toList();
        },
        child: trigger,
      ),
    );
  }
}
