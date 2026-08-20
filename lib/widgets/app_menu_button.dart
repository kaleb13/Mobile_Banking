import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Style variants for [AppMenuButton].
enum AppMenuButtonVariant {
  /// Automatically adapts background and icon colors to active theme/brightness.
  auto,

  /// Optimized for dark surfaces with dark surface circle and white icon.
  dark,

  /// Optimized for light / white surfaces with light grey circle and dark icon.
  light,
}

/// Item model for [AppMenuButton].
class AppMenuItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool enabled;

  const AppMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.enabled = true,
  });
}

/// Standardized three-dot action menu component for the design system.
///
/// Features a medium-sized 40x40 circular trigger button, seamless light/dark
/// theme support, 16px rounded popup menu overlay with zero border strokes,
/// and consistent white text styling.
class AppMenuButton<T> extends StatefulWidget {
  /// Available menu options.
  final List<AppMenuItem<T>> items;

  /// Callback when an item is selected.
  final ValueChanged<T> onSelected;

  /// Icon to display on the circular trigger (defaults to [Icons.more_vert_rounded]).
  final IconData icon;

  /// Total outer diameter of the circular button (defaults to 40.0).
  final double size;

  /// Icon size (defaults to 20.0).
  final double iconSize;

  /// Color styling variant (auto, dark, light).
  final AppMenuButtonVariant variant;

  /// Custom background color override for the circular trigger.
  final Color? backgroundColor;

  /// Custom icon color override for the circular trigger.
  final Color? iconColor;

  /// Popup menu offset from the button (defaults to Offset(0, 44)).
  final Offset offset;

  /// Minimum popup width constraint (defaults to 150.0).
  final double minWidth;

  /// Tooltip text.
  final String tooltip;

  const AppMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
    this.size = 36.0,
    this.iconSize = 18.0,
    this.variant = AppMenuButtonVariant.auto,
    this.backgroundColor,
    this.iconColor,
    this.offset = const Offset(0, 44),
    this.minWidth = 150.0,
    this.tooltip = 'More options',
  });

  /// Named constructor for dark background sections.
  const AppMenuButton.dark({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
    this.size = 36.0,
    this.iconSize = 18.0,
    this.backgroundColor,
    this.iconColor,
    this.offset = const Offset(0, 44),
    this.minWidth = 150.0,
    this.tooltip = 'More options',
  }) : variant = AppMenuButtonVariant.dark;

  /// Named constructor for light / white background sections.
  const AppMenuButton.light({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
    this.size = 36.0,
    this.iconSize = 18.0,
    this.backgroundColor,
    this.iconColor,
    this.offset = const Offset(0, 44),
    this.minWidth = 150.0,
    this.tooltip = 'More options',
  }) : variant = AppMenuButtonVariant.light;

  @override
  State<AppMenuButton<T>> createState() => _AppMenuButtonState<T>();
}

class _AppMenuButtonState<T> extends State<AppMenuButton<T>> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final bool isLight = widget.variant == AppMenuButtonVariant.light ||
        (widget.variant == AppMenuButtonVariant.auto &&
            Theme.of(context).brightness == Brightness.light);

    final Color effectiveBgColor = widget.backgroundColor ??
        (_isOpen
            ? (isLight ? AppColors.lightGreyBackground : AppColors.buttonSecondary)
            : (isLight ? AppColors.lightGreyBackground : AppColors.surface));

    final Color effectiveIconColor = widget.iconColor ??
        (isLight ? AppColors.darkCharcoal : Colors.white);

    final Color popupBgColor = isLight ? Colors.white : AppColors.surface;
    final Color itemTextColor = isLight ? AppColors.darkCharcoal : Colors.white;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: isLight
            ? AppColors.darkCharcoal.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.12),
        highlightColor: isLight
            ? AppColors.darkCharcoal.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.08),
      ),
      child: PopupMenuButton<T>(
        tooltip: widget.tooltip,
        onOpened: () {
          HapticFeedback.selectionClick();
          setState(() => _isOpen = true);
        },
        onCanceled: () => setState(() => _isOpen = false),
        offset: widget.offset,
        constraints: BoxConstraints(minWidth: widget.minWidth, maxWidth: 220),
        borderRadius: BorderRadius.circular(100),
        padding: EdgeInsets.zero,
        color: popupBgColor,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onSelected: (value) {
          setState(() => _isOpen = false);
          HapticFeedback.selectionClick();
          widget.onSelected(value);
        },
        itemBuilder: (context) {
          return widget.items.map((item) {
            return PopupMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(
                      item.icon,
                      size: 17,
                      color: itemTextColor,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: itemTextColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList();
        },
        icon: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: effectiveIconColor,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
