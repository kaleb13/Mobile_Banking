import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../domain/usecases/analytics/get_balance_history_usecase.dart';
import '../models/cash_transaction.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';
import 'app_capsule_tab_bar.dart';

/// Reusable interactive balance history line chart with touch-hover amount
/// revealing, dynamic gradient dimming, and tertiary time-frame filter tabs.
class InteractiveBalanceChart extends StatefulWidget {
  final List<AppTransaction> transactions;
  final List<CashTransaction> cashTransactions;
  final String initialFilter;
  final List<String> filterTabs;
  final Color accentColor;
  final bool isBalanceVisible;
  final double chartHeight;
  final ValueChanged<String>? onFilterChanged;
  final EdgeInsetsGeometry padding;
  final Set<String>? allowedBanks;

  const InteractiveBalanceChart({
    super.key,
    required this.transactions,
    this.cashTransactions = const [],
    this.initialFilter = '30D',
    this.filterTabs = const ['1D', '7D', '30D', '180D', '360D'],
    this.accentColor = AppColors.positive,
    this.isBalanceVisible = false,
    this.chartHeight = 120.0,
    this.onFilterChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.allowedBanks,
  });

  @override
  State<InteractiveBalanceChart> createState() =>
      _InteractiveBalanceChartState();
}

class _InteractiveBalanceChartState extends State<InteractiveBalanceChart> {
  late String _selectedFilter;
  double? _touchedX;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(covariant InteractiveBalanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter &&
        widget.initialFilter != _selectedFilter) {
      setState(() {
        _selectedFilter = widget.initialFilter;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime todayMidnight = DateTime(now.year, now.month, now.day);

    // Compute balance simulation history spots via domain use case
    final historyResult = const GetBalanceHistoryUseCase().execute(
      transactions: widget.transactions,
      cashTransactions: widget.cashTransactions,
      filter: _selectedFilter,
      referenceDate: todayMidnight,
      allowedBanks: widget.allowedBanks,
    );
    final List<FlSpot> spots = List.from(historyResult.spots);

    if (spots.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: widget.chartHeight,
            child: const Center(
              child: Text(
                'No activity recorded for this period',
                style: TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _buildFilterTabs(),
        ],
      );
    }

    // ── Gradient configuration ──────────────────────────────────────────────
    // LINE  : always left→right so stops map to horizontal chart positions.
    // FILL  : always top→bottom for that strong area-chart fade effect.
    //         When touched we dim the entire fill uniformly; the clear
    //         left/right distinction is shown by the line gradient + indicator.
    List<double> lineStops = [0.0, 1.0];
    List<Color> lineColors = [widget.accentColor, widget.accentColor];

    List<Color> fillColors = [
      widget.accentColor.withValues(alpha: 0.28),
      widget.accentColor.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        final double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        // Line: full accent color left of indicator, nearly invisible right of it
        lineColors = [
          widget.accentColor,
          widget.accentColor,
          widget.accentColor.withValues(alpha: 0.08),
          widget.accentColor.withValues(alpha: 0.08),
        ];
        // Fill: dim the whole fill uniformly when touching
        fillColors = [
          widget.accentColor.withValues(alpha: 0.07),
          widget.accentColor.withValues(alpha: 0.0),
        ];
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          height: widget.chartHeight,
          width: double.infinity,
          padding: widget.padding,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchCallback:
                    (FlTouchEvent event, LineTouchResponse? touchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        touchResponse == null ||
                        touchResponse.lineBarSpots == null ||
                        touchResponse.lineBarSpots!.isEmpty) {
                      _touchedX = null;
                      return;
                    }
                    final newX = touchResponse.lineBarSpots!.first.x;
                    if (_touchedX != newX) {
                      HapticFeedback.selectionClick();
                      _touchedX = newX;
                    }
                  });
                },
                getTouchedSpotIndicator:
                    (LineChartBarData barData, List<int> spotIndexes) {
                  return spotIndexes.map((index) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: Colors.white.withValues(alpha: 0.2),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.gold,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        ),
                      ),
                    );
                  }).toList();
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  tooltipMargin: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((s) {
                      return LineTooltipItem(
                        '',
                        const TextStyle(),
                        children: [
                          if (widget.isBalanceVisible)
                            const TextSpan(
                              text: 'ETB ',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          TextSpan(
                            text: widget.isBalanceVisible
                                ? NumberFormat('#,##0').format(s.y)
                                : '••••••••',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: lineColors,
                    stops: lineStops,
                  ),
                  barWidth: 1.8,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: fillColors,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildFilterTabs(),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return AppTertiaryTabBar(
      tabs: widget.filterTabs,
      selectedTab: _selectedFilter,
      onTabChanged: (val) {
        setState(() => _selectedFilter = val);
        widget.onFilterChanged?.call(val);
      },
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    );
  }
}
