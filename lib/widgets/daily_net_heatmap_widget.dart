import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/cash_transaction.dart';
import '../theme/app_theme.dart';

/// Reusable Daily Net Calendar Heatmap Grid component
/// Displays a 7-column calendar grid of the selected month,
/// coloring each day tile according to daily net cashflow (+ or -).
class DailyNetHeatmapWidget extends StatelessWidget {
  final List<AppTransaction> bankTransactions;
  final List<CashTransaction> cashTransactions;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final DateTime? selectedDay;
  final ValueChanged<DateTime?> onDaySelected;
  final bool isBalanceVisible;
  final int userLevel;

  const DailyNetHeatmapWidget({
    super.key,
    required this.bankTransactions,
    required this.cashTransactions,
    required this.selectedMonth,
    required this.onMonthChanged,
    this.selectedDay,
    required this.onDaySelected,
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
      case 1: return 5000.0;
      case 2: return 15000.0;
      case 3: return 35000.0;
      case 4: return 75000.0;
      case 5: return 150000.0;
      default: return 10000.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMM').format(selectedMonth);
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final highThreshold = _getHighThreshold();

    // Map daily net amounts
    final Map<int, double> dailyNetMap = {};
    final Map<int, bool> dailyHasTxMap = {};

    for (final tx in bankTransactions) {
      if (tx.date.year == selectedMonth.year && tx.date.month == selectedMonth.month) {
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
      if (ctx.date.year == selectedMonth.year && ctx.date.month == selectedMonth.month) {
        final d = ctx.date.day;
        dailyHasTxMap[d] = true;
        final amt = ctx.type == 'income' ? ctx.amount : -ctx.amount;
        dailyNetMap[d] = (dailyNetMap[d] ?? 0) + amt;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header Row: Title & Month Nav + Legend ─────────────────────────
        Row(
          children: [
            // Title & Month Picker Navigation
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Daily net · $monthName',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    final prev = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                    onMonthChanged(prev);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 22),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final next = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                    onMonthChanged(next);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 22),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Right Legend: - [H.Red] [S.Red] [Neutral] [S.Green] [H.Green] +
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('-', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
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
                const Text('+', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ── 7-Column Calendar Grid (Full Width & Spacious) ─────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final double gridSpacing = 6.0;
            final double itemWidth = (constraints.maxWidth - (gridSpacing * 6)) / 7;
            final double itemHeight = itemWidth * 0.95;

            return Wrap(
              spacing: gridSpacing,
              runSpacing: gridSpacing,
              children: List.generate(daysInMonth, (index) {
                final dayNum = index + 1;
                final date = DateTime(selectedMonth.year, selectedMonth.month, dayNum);
                final net = dailyNetMap[dayNum] ?? 0.0;
                final hasTx = dailyHasTxMap[dayNum] ?? false;
                final isSelected = selectedDay != null &&
                    selectedDay!.year == date.year &&
                    selectedDay!.month == date.month &&
                    selectedDay!.day == date.day;

                Color tileBg;
                Color textColor;

                if (!hasTx || net == 0) {
                  tileBg = AppColors.heatmapNeutral;
                  textColor = AppColors.textSecondary;
                } else if (net > 0) {
                  if (net >= highThreshold) {
                    tileBg = AppColors.heatmapHeavyGreen;
                    textColor = AppColors.background; // Dark text for bright emerald
                  } else {
                    tileBg = AppColors.heatmapSubtleGreen;
                    textColor = AppColors.textPrimary;
                  }
                } else {
                  if (net.abs() >= highThreshold) {
                    tileBg = AppColors.heatmapHeavyRed;
                    textColor = AppColors.background; // Dark text for bright coral red
                  } else {
                    tileBg = AppColors.heatmapSubtleRed;
                    textColor = AppColors.textPrimary;
                  }
                }

                final formattedNet = isBalanceVisible ? formatCompactNet(net) : '***';

                return InkWell(
                  onTap: () {
                    if (isSelected) {
                      onDaySelected(null); // toggle off
                    } else {
                      onDaySelected(date);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: itemWidth,
                    height: itemHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 3.0),
                    decoration: BoxDecoration(
                      color: tileBg,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
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
                );
              }),
            );
            },
          ),
        ],
      );
    }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
