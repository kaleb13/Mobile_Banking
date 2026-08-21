import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'app_button.dart';
import 'app_drawer.dart';

/// Standardized Date and Date-Range Picker Drawers following the system-wide
/// Drawer component architecture (`AppDrawer` & `AppDrawerHeaderCard`).
///
/// Adheres strictly to:
/// - Zero borders / stroke lines.
/// - Surface color contrast & backdrop blur.
/// - 100% fully rounded pill action buttons & chips.
/// - Reason-style emerald selection contrast (`AppColors.positive`).
class AppDatePickerDrawer {
  /// Launches a single-date picker bottom drawer.
  static Future<DateTime?> showSingleDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Select Date',
    String? subtitle,
  }) {
    return AppDrawer.show<DateTime>(
      context: context,
      builder: (ctx) => _SingleDatePickerView(
        initialDate: initialDate ?? DateTime.now(),
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        title: title,
        customSubtitle: subtitle,
      ),
    );
  }

  /// Launches a date-range picker bottom drawer.
  static Future<DateTimeRange?> showDateRange({
    required BuildContext context,
    DateTimeRange? initialRange,
    DateTime? firstDate,
    DateTime? lastDate,
    String title = 'Select Date Range',
    String? subtitle,
  }) {
    return AppDrawer.show<DateTimeRange>(
      context: context,
      builder: (ctx) => _DateRangePickerView(
        initialRange: initialRange,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: lastDate ?? DateTime(2100),
        title: title,
        customSubtitle: subtitle,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Single Date Picker Drawer View
// ─────────────────────────────────────────────────────────────────────────────

class _SingleDatePickerView extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String? customSubtitle;

  const _SingleDatePickerView({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    this.customSubtitle,
  });

  @override
  State<_SingleDatePickerView> createState() => _SingleDatePickerViewState();
}

class _SingleDatePickerViewState extends State<_SingleDatePickerView> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSelectable(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !clean.isBefore(first) && !clean.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final subtitleText = widget.customSubtitle ??
        DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate);

    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = (firstDayWeekday - 1) % 7;

    return AppDrawer(
      headerCard: AppDrawerHeaderCard(
        icon: Icons.calendar_month_rounded,
        iconColor: AppColors.positive,
        title: widget.title,
        subtitle: subtitleText,
      ),
      bottomAction: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              text: 'Cancel',
              height: 44,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton.primary(
              text: 'Apply Date',
              height: 44,
              onPressed: () => Navigator.pop(context, _selectedDate),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                  splashRadius: 20,
                  onPressed: _prevMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                  splashRadius: 20,
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Weekday Labels
          Row(
            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Calendar Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyCount + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyCount) {
                return const SizedBox.shrink();
              }

              final dayNum = index - leadingEmptyCount + 1;
              final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final isSelected = _isSameDay(dayDate, _selectedDate);
              final isToday = _isSameDay(dayDate, today);
              final selectable = _isSelectable(dayDate);

              return Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: selectable
                      ? () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _selectedDate = dayDate;
                          });
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? AppColors.positive
                          : (isToday
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.transparent),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: !selectable
                            ? Colors.white.withValues(alpha: 0.20)
                            : (isSelected
                                ? AppColors.buttonPrimaryText
                                : (isToday ? AppColors.positive : Colors.white)),
                        fontSize: 13.5,
                        fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Date Range Picker Drawer View
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangePickerView extends StatefulWidget {
  final DateTimeRange? initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final String? customSubtitle;

  const _DateRangePickerView({
    this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.title,
    this.customSubtitle,
  });

  @override
  State<_DateRangePickerView> createState() => _DateRangePickerViewState();
}

class _DateRangePickerViewState extends State<_DateRangePickerView> {
  DateTime? _startDate;
  DateTime? _endDate;
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    if (widget.initialRange != null) {
      _startDate = DateTime(
        widget.initialRange!.start.year,
        widget.initialRange!.start.month,
        widget.initialRange!.start.day,
      );
      _endDate = DateTime(
        widget.initialRange!.end.year,
        widget.initialRange!.end.month,
        widget.initialRange!.end.day,
      );
      _currentMonth = DateTime(_startDate!.year, _startDate!.month, 1);
    } else {
      _startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7));
      _endDate = DateTime(now.year, now.month, now.day);
      _currentMonth = DateTime(now.year, now.month, 1);
    }
  }

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _onDayTapped(DateTime day) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // Start fresh selection
        _startDate = day;
        _endDate = null;
      } else if (_startDate != null && _endDate == null) {
        if (day.isBefore(_startDate!)) {
          // If clicked before start, make it new start
          _startDate = day;
        } else {
          // Complete the range
          _endDate = day;
        }
      }
    });
  }

  void _setPresetRange(DateTime start, DateTime end) {
    HapticFeedback.mediumImpact();
    setState(() {
      _startDate = DateTime(start.year, start.month, start.day);
      _endDate = DateTime(end.year, end.month, end.day);
      _currentMonth = DateTime(_endDate!.year, _endDate!.month, 1);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSelectable(DateTime date) {
    final clean = DateTime(date.year, date.month, date.day);
    final first = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final last = DateTime(widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !clean.isBefore(first) && !clean.isAfter(last);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String subtitleText;
    if (_startDate != null && _endDate != null) {
      final daysCount = _endDate!.difference(_startDate!).inDays + 1;
      final startFmt = DateFormat('MMM d').format(_startDate!);
      final endFmt = DateFormat('MMM d, yyyy').format(_endDate!);
      subtitleText = '$startFmt – $endFmt ($daysCount ${daysCount == 1 ? 'day' : 'days'})';
    } else if (_startDate != null) {
      subtitleText = 'Start: ${DateFormat('MMM d, yyyy').format(_startDate!)} (Select end date)';
    } else {
      subtitleText = 'Choose your starting date';
    }

    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    final leadingEmptyCount = (firstDayWeekday - 1) % 7;

    return AppDrawer(
      headerCard: AppDrawerHeaderCard(
        icon: Icons.date_range_rounded,
        iconColor: AppColors.positive,
        title: widget.title,
        subtitle: subtitleText,
      ),
      bottomAction: Row(
        children: [
          Expanded(
            child: AppButton.secondary(
              text: 'Cancel',
              height: 44,
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton.primary(
              text: 'Apply Range',
              height: 44,
              onPressed: _startDate != null
                  ? () {
                      final finalEnd = _endDate ?? _startDate!;
                      Navigator.pop(
                        context,
                        DateTimeRange(start: _startDate!, end: finalEnd),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Preset Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPresetChip('7 Days', () {
                  _setPresetRange(now.subtract(const Duration(days: 6)), now);
                }),
                const SizedBox(width: 8),
                _buildPresetChip('30 Days', () {
                  _setPresetRange(now.subtract(const Duration(days: 29)), now);
                }),
                const SizedBox(width: 8),
                _buildPresetChip('This Month', () {
                  _setPresetRange(DateTime(now.year, now.month, 1), now);
                }),
                const SizedBox(width: 8),
                _buildPresetChip('This Year', () {
                  _setPresetRange(DateTime(now.year, 1, 1), now);
                }),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Month Navigator Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 22),
                  splashRadius: 20,
                  onPressed: _prevMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
                  splashRadius: 20,
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Weekday Labels
          Row(
            children: const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyCount + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 0, // seamless range connector
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyCount) {
                return const SizedBox.shrink();
              }

              final dayNum = index - leadingEmptyCount + 1;
              final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNum);
              final selectable = _isSelectable(dayDate);
              final isToday = _isSameDay(dayDate, today);

              final isStart = _startDate != null && _isSameDay(dayDate, _startDate!);
              final isEnd = _endDate != null && _isSameDay(dayDate, _endDate!);
              final isBetween = _startDate != null &&
                  _endDate != null &&
                  dayDate.isAfter(_startDate!) &&
                  dayDate.isBefore(_endDate!);

              // Determine span connector background
              Decoration? spanDecoration;
              if (isBetween) {
                spanDecoration = BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.16),
                );
              } else if (isStart && _endDate != null && !isEnd) {
                spanDecoration = BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.16),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                );
              } else if (isEnd && _startDate != null && !isStart) {
                spanDecoration = BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.16),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
                );
              }

              return Container(
                decoration: spanDecoration,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: selectable ? () => _onDayTapped(dayDate) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isStart || isEnd)
                            ? AppColors.positive
                            : (isToday && !isBetween
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          color: !selectable
                              ? Colors.white.withValues(alpha: 0.20)
                              : (isStart || isEnd
                                  ? AppColors.buttonPrimaryText
                                  : (isBetween
                                      ? Colors.white
                                      : (isToday ? AppColors.positive : Colors.white))),
                          fontSize: 13.5,
                          fontWeight:
                              isStart || isEnd || isBetween || isToday ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
