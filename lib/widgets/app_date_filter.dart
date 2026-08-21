import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_dropdown.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'app_drawer.dart';
import 'app_date_picker_drawer.dart';

/// Available preset date filter options.
enum AppDateFilterPreset {
  anyTime,
  today,
  yesterday,
  thisWeek,
  thisMonth,
  last30Days,
  thisYear,
  customDate,
  customRange,
}

/// Represents the active state and date range for [AppDateFilter].
class AppDateFilterValue {
  final AppDateFilterPreset preset;
  final DateTime? customDate;
  final DateTimeRange? customRange;

  const AppDateFilterValue({
    this.preset = AppDateFilterPreset.anyTime,
    this.customDate,
    this.customRange,
  });

  const AppDateFilterValue.anyTime()
      : preset = AppDateFilterPreset.anyTime,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.today()
      : preset = AppDateFilterPreset.today,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.yesterday()
      : preset = AppDateFilterPreset.yesterday,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.thisWeek()
      : preset = AppDateFilterPreset.thisWeek,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.thisMonth()
      : preset = AppDateFilterPreset.thisMonth,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.last30Days()
      : preset = AppDateFilterPreset.last30Days,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.thisYear()
      : preset = AppDateFilterPreset.thisYear,
        customDate = null,
        customRange = null;

  const AppDateFilterValue.singleDate(DateTime date)
      : preset = AppDateFilterPreset.customDate,
        customDate = date,
        customRange = null;

  const AppDateFilterValue.dateRange(DateTimeRange range)
      : preset = AppDateFilterPreset.customRange,
        customDate = null,
        customRange = range;

  bool get isDefault => preset == AppDateFilterPreset.anyTime || preset == AppDateFilterPreset.last30Days;

  /// Human-friendly display label on the pill trigger.
  String get label {
    switch (preset) {
      case AppDateFilterPreset.anyTime:
        return 'All Time';
      case AppDateFilterPreset.today:
        return 'Today';
      case AppDateFilterPreset.yesterday:
        return 'Yesterday';
      case AppDateFilterPreset.thisWeek:
        return 'This Week';
      case AppDateFilterPreset.thisMonth:
        return 'This Month';
      case AppDateFilterPreset.last30Days:
        return '30 Days';
      case AppDateFilterPreset.thisYear:
        return 'This Year';
      case AppDateFilterPreset.customDate:
        return customDate != null
            ? DateFormat('MMM d').format(customDate!)
            : 'Date';
      case AppDateFilterPreset.customRange:
        if (customRange != null) {
          if (customRange!.start.year == customRange!.end.year &&
              customRange!.start.month == customRange!.end.month &&
              customRange!.start.day == customRange!.end.day) {
            return DateFormat('MMM d').format(customRange!.start);
          }
          return '${DateFormat('MMM d').format(customRange!.start)} - ${DateFormat('MMM d').format(customRange!.end)}';
        }
        return 'Date';
    }
  }

  /// Evaluates whether a transaction [date] satisfies this filter.
  bool matches(DateTime date) {
    final now = DateTime.now();
    switch (preset) {
      case AppDateFilterPreset.anyTime:
        return true;
      case AppDateFilterPreset.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case AppDateFilterPreset.yesterday:
        final yesterday = now.subtract(const Duration(days: 1));
        return date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;
      case AppDateFilterPreset.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return !date.isBefore(startOfWeek);
      case AppDateFilterPreset.thisMonth:
        return date.year == now.year && date.month == now.month;
      case AppDateFilterPreset.last30Days:
        final thirtyDaysAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
        return !date.isBefore(thirtyDaysAgo);
      case AppDateFilterPreset.thisYear:
        return date.year == now.year;
      case AppDateFilterPreset.customDate:
        if (customDate == null) return true;
        return date.year == customDate!.year &&
            date.month == customDate!.month &&
            date.day == customDate!.day;
      case AppDateFilterPreset.customRange:
        if (customRange == null) return true;
        final start = DateTime(customRange!.start.year,
            customRange!.start.month, customRange!.start.day);
        final end = DateTime(customRange!.end.year, customRange!.end.month,
            customRange!.end.day, 23, 59, 59, 999);
        return (date.isAfter(start.subtract(const Duration(seconds: 1))) ||
                date.isAtSameMomentAs(start)) &&
            (date.isBefore(end.add(const Duration(seconds: 1))) ||
                date.isAtSameMomentAs(end));
    }
  }
}

/// Standardized design-system Date Filter pill and modal picker component.
///
/// Fully rounded (pill shape), zero borders, supporting Light and Dark surfaces,
/// quick presets, single-day picker, and custom date-range picker.
class AppDateFilter extends StatelessWidget {
  /// Currently selected filter value.
  final AppDateFilterValue value;

  /// Callback when date selection changes.
  final ValueChanged<AppDateFilterValue> onChanged;

  /// Visual theme variant (light for white sheets, dark for dark surfaces).
  final AppDropdownVariant variant;

  /// Trigger button height (defaults to 32).
  final double height;

  /// Border radius (defaults to 100 for 100% pill shape).
  final double borderRadius;

  /// Optional maximum width constraint for the trigger button label.
  final double? maxWidth;

  /// Custom background color override.
  final Color? backgroundColor;

  /// Custom text color override.
  final Color? textColor;

  /// Custom icon color override.
  final Color? iconColor;

  const AppDateFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.variant = AppDropdownVariant.dark,
    this.height = 32,
    this.borderRadius = 100,
    this.maxWidth,
    this.backgroundColor,
    this.textColor,
    this.iconColor,
  });

  /// Factory constructor for white / light background surfaces.
  factory AppDateFilter.light({
    Key? key,
    required AppDateFilterValue value,
    required ValueChanged<AppDateFilterValue> onChanged,
    double height = 32,
    double borderRadius = 100,
    double? maxWidth,
    Color? backgroundColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppDateFilter(
      key: key,
      value: value,
      onChanged: onChanged,
      variant: AppDropdownVariant.light,
      height: height,
      borderRadius: borderRadius,
      maxWidth: maxWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      iconColor: iconColor,
    );
  }

  /// Factory constructor for dark background surfaces.
  factory AppDateFilter.dark({
    Key? key,
    required AppDateFilterValue value,
    required ValueChanged<AppDateFilterValue> onChanged,
    double height = 32,
    double borderRadius = 100,
    double? maxWidth,
    Color? backgroundColor,
    Color? textColor,
    Color? iconColor,
  }) {
    return AppDateFilter(
      key: key,
      value: value,
      onChanged: onChanged,
      variant: AppDropdownVariant.dark,
      height: height,
      borderRadius: borderRadius,
      maxWidth: maxWidth,
      backgroundColor: backgroundColor,
      textColor: textColor,
      iconColor: iconColor,
    );
  }

  void _showDatePickerSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _AppDateFilterSheet(
          currentValue: value,
          onSelected: (newValue) {
            onChanged(newValue);
            if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
              Navigator.of(sheetContext).pop();
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = variant == AppDropdownVariant.light ||
        (variant == AppDropdownVariant.auto &&
            Theme.of(context).brightness == Brightness.light);

    final bool isDef = value.isDefault;

    // Trigger background styling (Zero borders)
    final Color triggerBg = backgroundColor ??
        (isLight ? AppColors.lightGreyBackground : AppColors.heatmapNeutral);

    final Color effectiveTextColor = textColor ??
        (isLight
            ? (isDef ? AppColors.mediumGreyText : AppColors.darkCharcoal)
            : (isDef ? AppColors.textSoft : Colors.white));

    final Color effectiveIconColor = iconColor ??
        (isLight
            ? (isDef ? AppColors.mediumGreyText : AppColors.darkCharcoal)
            : (isDef ? AppColors.textSoft : Colors.white));

    return GestureDetector(
      onTap: () => _showDatePickerSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: triggerBg,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: effectiveIconColor,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth ?? 140),
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontSize: 12,
                  fontWeight: isDef ? FontWeight.w500 : FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: effectiveIconColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal Bottom Sheet containing date presets and custom pickers.
class _AppDateFilterSheet extends StatelessWidget {
  final AppDateFilterValue currentValue;
  final ValueChanged<AppDateFilterValue> onSelected;

  const _AppDateFilterSheet({
    required this.currentValue,
    required this.onSelected,
  });

  Future<void> _pickSingleDate(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = currentValue.customDate ?? now;

    final picked = await AppDatePickerDrawer.showSingleDate(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      title: 'Filter Single Date',
    );

    if (context.mounted && picked != null) {
      onSelected(AppDateFilterValue.singleDate(picked));
    }
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final now = DateTime.now();
    final initialRange = currentValue.customRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );

    final picked = await AppDatePickerDrawer.showDateRange(
      context: context,
      initialRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      title: 'Filter Date Range',
    );

    if (context.mounted && picked != null) {
      onSelected(AppDateFilterValue.dateRange(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = [
      {'label': 'Last 30 Days', 'value': const AppDateFilterValue.last30Days()},
      {'label': 'Any Time (All Transactions)', 'value': const AppDateFilterValue.anyTime()},
      {'label': 'Today', 'value': const AppDateFilterValue.today()},
      {'label': 'Yesterday', 'value': const AppDateFilterValue.yesterday()},
      {'label': 'This Week', 'value': const AppDateFilterValue.thisWeek()},
      {'label': 'This Month', 'value': const AppDateFilterValue.thisMonth()},
      {'label': 'This Year', 'value': const AppDateFilterValue.thisYear()},
    ];

    return AppDrawer(
      headerCard: AppDrawerHeaderCard(
        icon: Icons.calendar_month_rounded,
        iconColor: AppColors.positive,
        title: 'Filter by Date',
        subtitle: 'Select a time preset or pick a custom range',
        trailing: !currentValue.isDefault
            ? GestureDetector(
                onTap: () => onSelected(const AppDateFilterValue.anyTime()),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.buttonSecondary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: AppColors.positive,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Presets
          ...presets.map((item) {
            final val = item['value'] as AppDateFilterValue;
            final isSelected = currentValue.preset == val.preset;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.positive.withValues(alpha: 0.14)
                    : AppColors.drawerCard,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: AppRadius.cardRadius,
                child: InkWell(
                  onTap: () => onSelected(val),
                  borderRadius: AppRadius.cardRadius,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['label'] as String,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.9),
                              fontSize: 13.5,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.positive,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 10),

          // Custom Pickers Section
          Row(
            children: [
              // Single Date Picker Action Pill
              Expanded(
                child: AppButton.secondary(
                  text: currentValue.preset == AppDateFilterPreset.customDate
                      ? currentValue.label
                      : 'Pick Date',
                  icon: Icons.event_outlined,
                  height: 44,
                  fontSize: 12.5,
                  onPressed: () => _pickSingleDate(context),
                ),
              ),
              const SizedBox(width: 8),
              // Date Range Picker Action Pill
              Expanded(
                child: AppButton.secondary(
                  text: currentValue.preset == AppDateFilterPreset.customRange
                      ? 'Range Active'
                      : 'Date Range',
                  icon: Icons.date_range_rounded,
                  height: 44,
                  fontSize: 12.5,
                  onPressed: () => _pickDateRange(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
