import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/cash_transaction.dart';
import '../theme/app_theme.dart';

/// Presentation period type matching AnalysisScreen
enum HeatmapPeriodType { day, week, month, quarter, year }

/// Reusable & Adaptive Daily Net Calendar Heatmap Grid component
///
/// Automatically synchronizes with the top Period Filter:
/// - **Day**: Displays the current month grid with the active day prominently highlighted.
/// - **Week**: Displays the month grid with the 7 active days highlighted as a connected band.
/// - **Month**: Displays the full 7-column calendar grid for that selected month.
/// - **Quarter**: Displays a clean 3-month breakdown for the selected quarter.
/// - **Year**: Displays a 12-month annual contribution matrix colored by net cashflow.
class DailyNetHeatmapWidget extends StatelessWidget {
  final List<AppTransaction> bankTransactions;
  final List<CashTransaction> cashTransactions;
  final HeatmapPeriodType periodType;
  final DateTime selectedDate;
  final DateTimeRange? highlightedWeekRange;
  final int selectedQuarter;
  final int selectedYear;
  final DateTime? selectedDay;
  final ValueChanged<DateTime?> onDaySelected;
  final ValueChanged<int>? onMonthSelected;
  final bool isBalanceVisible;
  final int userLevel;

  const DailyNetHeatmapWidget({
    super.key,
    required this.bankTransactions,
    required this.cashTransactions,
    this.periodType = HeatmapPeriodType.month,
    required this.selectedDate,
    this.highlightedWeekRange,
    this.selectedQuarter = 0,
    this.selectedYear = 2026,
    this.selectedDay,
    required this.onDaySelected,
    this.onMonthSelected,
    this.isBalanceVisible = true,
    this.userLevel = 1,
  });

  /// Formats amount into ultra-compact representation (e.g. +70K, -94K, +2.4K, -833)
  static String formatCompactNet(double net) {
    final absNet = net.abs();
    final sign = net > 0 ? '+' : (net < 0 ? '-' : '');

    if (absNet == 0) return '';

    if (absNet >= 1000000) {
      final val = absNet / 1000000;
      return '$sign${val.toStringAsFixed(val >= 10 ? 0 : 1)}M';
    } else if (absNet >= 1000) {
      final val = absNet / 1000;
      return '$sign${val.toStringAsFixed(val >= 10 ? 0 : 1)}K';
    } else {
      return '$sign${absNet.toStringAsFixed(0)}';
    }
  }

  /// Calculates dynamic threshold for "heavy" net gains/losses based on user level
  double _getHighThreshold() {
    switch (userLevel) {
      case 1:
        return 5000.0;
      case 2:
        return 15000.0;
      case 3:
        return 35000.0;
      case 4:
        return 75000.0;
      case 5:
        return 150000.0;
      default:
        return 10000.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (periodType) {
      case HeatmapPeriodType.quarter:
        return _buildQuarterlyHeatmap(context);
      case HeatmapPeriodType.year:
        return _buildAnnualMatrix(context);
      case HeatmapPeriodType.day:
      case HeatmapPeriodType.week:
      case HeatmapPeriodType.month:
        return _buildMonthlyCalendarHeatmap(context);
    }
  }

  // ── 1. Monthly / Daily / Weekly Calendar Grid ──────────────────────────────
  Widget _buildMonthlyCalendarHeatmap(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(selectedDate);
    final daysInMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0).day;
    final highThreshold = _getHighThreshold();

    // Map daily net amounts
    final Map<int, double> dailyNetMap = {};
    final Map<int, bool> dailyHasTxMap = {};

    for (final tx in bankTransactions) {
      if (tx.date.year == selectedDate.year &&
          tx.date.month == selectedDate.month) {
        final d = tx.date.day;
        dailyHasTxMap[d] = true;
        final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
        final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        if (!isCash && !isBounce) {
          final amt = tx.type == 'income' ? tx.amount : -tx.amount;
          dailyNetMap[d] = (dailyNetMap[d] ?? 0) + amt;
        }
      }
    }

    for (final ctx in cashTransactions) {
      if (ctx.date.year == selectedDate.year &&
          ctx.date.month == selectedDate.month) {
        final d = ctx.date.day;
        dailyHasTxMap[d] = true;
        final isAddition = ctx.type == 'addition' || ctx.type == 'income';
        final amt = isAddition ? ctx.amount : -ctx.amount;
        dailyNetMap[d] = (dailyNetMap[d] ?? 0) + amt;
      }
    }

    String headerLabel = 'Daily Net · $monthName';
    if (periodType == HeatmapPeriodType.day) {
      headerLabel = 'Daily Net · ${DateFormat('MMM d').format(selectedDate)}';
    } else if (periodType == HeatmapPeriodType.week &&
        highlightedWeekRange != null) {
      final startFmt = DateFormat('MMM d').format(highlightedWeekRange!.start);
      final endFmt = DateFormat('MMM d').format(highlightedWeekRange!.end);
      headerLabel = 'Daily Net · $startFmt - $endFmt';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Row: Synchronized Title + Legend ─────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                headerLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildLegend(),
          ],
        ),

        const SizedBox(height: 12),

        // ── 7-Column Calendar Grid ─────────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final double gridSpacing = 6.0;
            final double itemWidth =
                (constraints.maxWidth - (gridSpacing * 6)) / 7;
            final double itemHeight = itemWidth * 0.95;

            return Wrap(
              spacing: gridSpacing,
              runSpacing: gridSpacing,
              children: List.generate(daysInMonth, (index) {
                final dayNum = index + 1;
                final date =
                    DateTime(selectedDate.year, selectedDate.month, dayNum);
                final net = dailyNetMap[dayNum] ?? 0.0;
                final hasTx = dailyHasTxMap[dayNum] ?? false;

                // Selection / highlight logic
                final isSelectedDay = selectedDay != null &&
                    selectedDay!.year == date.year &&
                    selectedDay!.month == date.month &&
                    selectedDay!.day == date.day;

                final isDayModeActive = periodType == HeatmapPeriodType.day &&
                    selectedDate.year == date.year &&
                    selectedDate.month == date.month &&
                    selectedDate.day == date.day;

                final isWeekHighlighted =
                    periodType == HeatmapPeriodType.week &&
                        highlightedWeekRange != null &&
                        !date.isBefore(DateTime(
                          highlightedWeekRange!.start.year,
                          highlightedWeekRange!.start.month,
                          highlightedWeekRange!.start.day,
                        )) &&
                        !date.isAfter(DateTime(
                          highlightedWeekRange!.end.year,
                          highlightedWeekRange!.end.month,
                          highlightedWeekRange!.end.day,
                          23,
                          59,
                          59,
                        ));

                final isHighlighted =
                    isSelectedDay || isDayModeActive || isWeekHighlighted;

                Color tileBg;
                Color textColor;

                if (!hasTx || net == 0) {
                  tileBg = AppColors.heatmapNeutral;
                  textColor = AppColors.textSecondary;
                } else if (net > 0) {
                  if (net >= highThreshold) {
                    tileBg = AppColors.heatmapHeavyGreen;
                    textColor = AppColors.background;
                  } else {
                    tileBg = AppColors.heatmapSubtleGreen;
                    textColor = AppColors.textPrimary;
                  }
                } else {
                  if (net.abs() >= highThreshold) {
                    tileBg = AppColors.heatmapHeavyRed;
                    textColor = AppColors.background;
                  } else {
                    tileBg = AppColors.heatmapSubtleRed;
                    textColor = AppColors.textPrimary;
                  }
                }

                final formattedNet =
                    isBalanceVisible ? formatCompactNet(net) : '•••';

                return InkWell(
                  onTap: () {
                    if (isSelectedDay) {
                      onDaySelected(null);
                    } else {
                      onDaySelected(date);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: itemWidth,
                        height: itemHeight,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3.5, vertical: 3.0),
                        decoration: BoxDecoration(
                          color: tileBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$dayNum',
                                style: TextStyle(
                                  color: textColor.withValues(alpha: 0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (formattedNet.isNotEmpty)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  formattedNet,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isHighlighted)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isSelectedDay || isDayModeActive
                                    ? AppColors.buttonGlass
                                    : AppColors.glassSurfaceSubtle,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

  // ── 2. Quarterly 3-Month Heatmap Breakdown ────────────────────────────────
  Widget _buildQuarterlyHeatmap(BuildContext context) {
    final startMonth = (selectedQuarter * 3) + 1;
    final quarterName = 'Q${selectedQuarter + 1} ($selectedYear)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Legend
        Row(
          children: [
            Expanded(
              child: Text(
                'Quarterly Net · $quarterName',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            _buildLegend(),
          ],
        ),
        const SizedBox(height: 12),

        // 3 Month Cards Row
        Row(
          children: List.generate(3, (i) {
            final monthNum = startMonth + i;
            final monthDate = DateTime(selectedYear, monthNum, 1);
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: i == 0 ? 0 : 4,
                  right: i == 2 ? 0 : 4,
                ),
                child: _buildMiniMonthCard(context, monthDate),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMiniMonthCard(BuildContext context, DateTime monthDate) {
    final monthName = DateFormat('MMM').format(monthDate);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final highThreshold = _getHighThreshold();

    double monthTotalNet = 0;
    final Map<int, double> dailyNetMap = {};

    for (final tx in bankTransactions) {
      if (tx.date.year == monthDate.year && tx.date.month == monthDate.month) {
        final d = tx.date.day;
        final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
        final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
            tx.resolvedReason?.toLowerCase() == 'internal transfer';
        if (!isCash && !isBounce) {
          final amt = tx.type == 'income' ? tx.amount : -tx.amount;
          dailyNetMap[d] = (dailyNetMap[d] ?? 0) + amt;
          monthTotalNet += amt;
        }
      }
    }

    for (final ctx in cashTransactions) {
      if (ctx.date.year == monthDate.year &&
          ctx.date.month == monthDate.month) {
        final d = ctx.date.day;
        final isAddition = ctx.type == 'addition' || ctx.type == 'income';
        final amt = isAddition ? ctx.amount : -ctx.amount;
        dailyNetMap[d] = (dailyNetMap[d] ?? 0) + amt;
        monthTotalNet += amt;
      }
    }

    final formattedTotal =
        isBalanceVisible ? formatCompactNet(monthTotalNet) : '••••';

    final Color totalColor = monthTotalNet > 0
        ? AppColors.positive
        : (monthTotalNet < 0 ? AppColors.negative : AppColors.textSecondary);

    return InkWell(
      onTap: () {
        onMonthSelected?.call(monthDate.month - 1);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month title & Month total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formattedTotal.isNotEmpty ? formattedTotal : '0',
                  style: TextStyle(
                    color: totalColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Mini 7-col dots grid
            Wrap(
              spacing: 3,
              runSpacing: 3,
              children: List.generate(daysInMonth, (dIndex) {
                final dayNum = dIndex + 1;
                final net = dailyNetMap[dayNum] ?? 0.0;

                Color dotColor;
                if (net == 0) {
                  dotColor = AppColors.heatmapNeutral;
                } else if (net > 0) {
                  dotColor = net >= highThreshold
                      ? AppColors.heatmapHeavyGreen
                      : AppColors.heatmapSubtleGreen;
                } else {
                  dotColor = net.abs() >= highThreshold
                      ? AppColors.heatmapHeavyRed
                      : AppColors.heatmapSubtleRed;
                }

                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Annual 12-Month Contribution Matrix ────────────────────────────────
  Widget _buildAnnualMatrix(BuildContext context) {
    final highThreshold = _getHighThreshold() * 10; // monthly threshold

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Legend
        Row(
          children: [
            Expanded(
              child: Text(
                'Annual Net Matrix · $selectedYear',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            _buildLegend(),
          ],
        ),
        const SizedBox(height: 12),

        // 4 Columns x 3 Rows Month Matrix
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final monthIndex = index;
            final monthDate = DateTime(selectedYear, monthIndex + 1, 1);
            final monthAbbr = DateFormat('MMM').format(monthDate);

            double monthNet = 0;
            bool hasTx = false;

            for (final tx in bankTransactions) {
              if (tx.date.year == selectedYear &&
                  tx.date.month == monthIndex + 1) {
                hasTx = true;
                final isCash = tx.resolvedReason?.toLowerCase() == 'cash';
                final isBounce = tx.resolvedReason?.toLowerCase() == 'bounce' ||
                    tx.resolvedReason?.toLowerCase() == 'internal transfer';
                if (!isCash && !isBounce) {
                  final amt = tx.type == 'income' ? tx.amount : -tx.amount;
                  monthNet += amt;
                }
              }
            }

            for (final ctx in cashTransactions) {
              if (ctx.date.year == selectedYear &&
                  ctx.date.month == monthIndex + 1) {
                hasTx = true;
                final isAddition =
                    ctx.type == 'addition' || ctx.type == 'income';
                final amt = isAddition ? ctx.amount : -ctx.amount;
                monthNet += amt;
              }
            }

            Color tileBg;
            Color textColor;

            if (!hasTx || monthNet == 0) {
              tileBg = AppColors.heatmapNeutral;
              textColor = AppColors.textSecondary;
            } else if (monthNet > 0) {
              if (monthNet >= highThreshold) {
                tileBg = AppColors.heatmapHeavyGreen;
                textColor = AppColors.background;
              } else {
                tileBg = AppColors.heatmapSubtleGreen;
                textColor = AppColors.textPrimary;
              }
            } else {
              if (monthNet.abs() >= highThreshold) {
                tileBg = AppColors.heatmapHeavyRed;
                textColor = AppColors.background;
              } else {
                tileBg = AppColors.heatmapSubtleRed;
                textColor = AppColors.textPrimary;
              }
            }

            final formattedNet =
                isBalanceVisible ? formatCompactNet(monthNet) : '•••';

            return InkWell(
              onTap: () {
                onMonthSelected?.call(monthIndex);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthAbbr,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.85),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (formattedNet.isNotEmpty)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          formattedNet,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Legend Widget ─────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('-',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        _buildLegendDot(AppColors.heatmapHeavyRed),
        const SizedBox(width: 3),
        _buildLegendDot(AppColors.heatmapSubtleRed),
        const SizedBox(width: 3),
        _buildLegendDot(AppColors.heatmapNeutral),
        const SizedBox(width: 3),
        _buildLegendDot(AppColors.heatmapSubtleGreen),
        const SizedBox(width: 3),
        _buildLegendDot(AppColors.heatmapHeavyGreen),
        const SizedBox(width: 4),
        const Text('+',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }
}
