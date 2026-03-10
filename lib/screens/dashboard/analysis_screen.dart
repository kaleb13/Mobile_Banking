import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../theme/app_theme.dart';

// ─── Period Enum ──────────────────────────────────────────────────────────────
enum AnalysisPeriod { d1, d7, d30, d180, d360 }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  AnalysisPeriod _period = AnalysisPeriod.d30;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _changePeriod(AnalysisPeriod p) {
    if (_period == p) return;
    setState(() => _period = p);
  }

  // ─── Filtered transactions ──────────────────────────────────────────────────
  ({List<AppTransaction> txs, List<CashTransaction> cashTxs}) _filtered(
      List<AppTransaction> allTxs, List<CashTransaction> allCashTxs) {
    final now = DateTime.now();
    DateTime cutoff;
    switch (_period) {
      case AnalysisPeriod.d1:
        cutoff = now.subtract(const Duration(days: 1));
        break;
      case AnalysisPeriod.d7:
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case AnalysisPeriod.d30:
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case AnalysisPeriod.d180:
        cutoff = now.subtract(const Duration(days: 180));
        break;
      case AnalysisPeriod.d360:
        cutoff = now.subtract(const Duration(days: 360));
        break;
    }

    final filteredTxs = allTxs
        .where((t) =>
            t.date.isAfter(cutoff) &&
            t.resolvedReason?.toLowerCase() != 'bounce' &&
            t.resolvedReason?.toLowerCase() != 'internal transfer')
        .toList();

    final filteredCashTxs =
        allCashTxs.where((t) => t.date.isAfter(cutoff)).toList();

    return (txs: filteredTxs, cashTxs: filteredCashTxs);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final filtered =
        _filtered(provider.transactions, provider.cashTransactions);
    final txs = filtered.txs;
    final cashTxs = filtered.cashTxs;

    // Separate regular transactions and cash transfers
    final regularTxs = txs
        .where((t) =>
            t.reason?.toLowerCase() != 'cash' &&
            t.customReasonText?.toLowerCase() != 'cash' &&
            t.resolvedReason?.toLowerCase() != 'cash')
        .toList();

    // Sum real expenses: Regular bank expenses + Cash wallet expenses
    double totalExpense = regularTxs
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);

    totalExpense += cashTxs
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);

    final totalIncome = regularTxs
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final net = totalIncome - totalExpense;

    // Smart P/L values from provider
    final dailyPnl = provider.dailyPnl;
    final monthlyPnl = provider.monthlyPnl;
    final overallPnl = provider.overallPnl;
    final borrowedLiability = provider.totalBorrowedLiability;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1F1F25),
                Color(0xFF1B1B21),
              ],
            ),
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                              child: _buildSumCard(
                                  'In',
                                  provider.isBalanceVisible
                                      ? NumberFormat('#,##0.00')
                                          .format(totalIncome)
                                      : '****',
                                  const Color(0xFF3EB489),
                                  Icons.arrow_downward_rounded)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildSumCard(
                                  'Out',
                                  provider.isBalanceVisible
                                      ? NumberFormat('#,##0.00')
                                          .format(totalExpense)
                                      : '****',
                                  const Color(0xFFEF4444),
                                  Icons.arrow_upward_rounded)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: _buildSumCard(
                                  'P/L',
                                  provider.isBalanceVisible
                                      ? NumberFormat('#,##0.00').format(net)
                                      : '****',
                                  const Color(0xFFF0B90B),
                                  Icons.auto_graph_rounded)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildPeriodSelector(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Profit & Loss'),
                      const SizedBox(height: 14),
                      _buildPnlSection(dailyPnl, monthlyPnl, overallPnl,
                          borrowedLiability, provider.isBalanceVisible),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Cash Flow'),
                      const SizedBox(height: 14),
                      _buildBarChart(txs, cashTxs),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Spending by Category'),
                      const SizedBox(height: 14),
                      _buildRadarSection(txs, cashTxs, provider),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Bank Performance'),
                      const SizedBox(height: 14),
                      _buildBankPerformance(txs, provider),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Top Spending Reasons'),
                      const SizedBox(height: 14),
                      _buildReasonBreakdown(txs, cashTxs, provider),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Analysis',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            )),
        Text(
          'Spend with awareness',
          style: TextStyle(color: AppColors.labelGray, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSumCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.labelGray,
                      fontSize: 10,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ─── Period Selector ────────────────────────────────────────────────────────
  Widget _buildPeriodSelector() {
    final periods = [
      (AnalysisPeriod.d1, '1D'),
      (AnalysisPeriod.d7, '7D'),
      (AnalysisPeriod.d30, '30D'),
      (AnalysisPeriod.d180, '180D'),
      (AnalysisPeriod.d360, '360D'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: periods.map((item) {
          final isActive = _period == item.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changePeriod(item.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.labelGray,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Profit & Loss Section ──────────────────────────────────────────────────
  Widget _buildPnlSection(double daily, double monthly, double overall,
      double borrowedLiability, bool isBalanceVisible) {
    final fmt = NumberFormat('#,##0.00');
    final hasBorrowedDebt = borrowedLiability > 0;

    return Column(
      children: [
        // Three P/L cards
        Row(
          children: [
            Expanded(
              child: _buildPnlCard(
                label: 'Today',
                value: daily,
                fmt: fmt,
                tooltip: 'Can go negative if expenses exceed income today',
                canBeNegative: true,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPnlCard(
                label: 'This Month',
                value: monthly,
                fmt: fmt,
                tooltip: hasBorrowedDebt
                    ? 'Your borrowed loan balance reduces monthly profit'
                    : 'Floors at 0 unless borrowed debt exceeds income',
                canBeNegative: hasBorrowedDebt,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPnlCard(
                label: 'Overall',
                value: overall,
                fmt: fmt,
                tooltip: hasBorrowedDebt
                    ? 'Borrowed debt deducted from overall growth'
                    : 'Growth since first measurement',
                canBeNegative: hasBorrowedDebt,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
          ],
        ),

        // Loan liability callout — only shown when there's borrowed debt
        if (hasBorrowedDebt) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE11D48).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFFE11D48),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Loan Liability',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'You have ${NumberFormat('#,##0.00').format(borrowedLiability)} ETB in outstanding borrowed funds. '
                        'This amount is treated as a liability and reduces your monthly and overall P/L. '
                        'Once repaid, your true profit will reflect accurately.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Explanation row
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A34).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily P/L can be negative. Monthly & overall P/L only go negative when borrowed loan liabilities exceed your assets.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPnlCard({
    required String label,
    required double value,
    required NumberFormat fmt,
    required String tooltip,
    bool canBeNegative = false,
    required bool isBalanceVisible,
  }) {
    final isNeg = value < 0;
    final isZero = value == 0;
    final Color color = isNeg
        ? const Color(0xFFE11D48)
        : isZero
            ? AppColors.labelGray
            : const Color(0xFF3EB489);
    final IconData icon = isNeg
        ? Icons.trending_down_rounded
        : isZero
            ? Icons.trending_flat_rounded
            : Icons.trending_up_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: color.withValues(alpha: isNeg ? 0.2 : 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.labelGray.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isBalanceVisible
                ? '${isNeg ? '-' : ''}${fmt.format(value.abs())}'
                : '****.**',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (canBeNegative && isNeg) ...[
            const SizedBox(height: 4),
            Text(
              '⚠ Debt drag',
              style: TextStyle(
                color: const Color(0xFFE11D48).withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    );
  }

  // ─── Bar Chart: Cash Flow ───────────────────────────────────────────────────
  Widget _buildBarChart(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    // Build time-bucketed data
    final groups = _buildBarGroups(txs, cashTxs);

    if (groups.isEmpty || txs.isEmpty) {
      return _buildEmptyState('No transactions in this period');
    }

    final maxY =
        groups.expand((g) => g.barRods.map((r) => r.toY)).fold<double>(0, max);
    final yInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1000.0;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY + yInterval,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF1A2530),
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final isIncome = rodIndex == 0;
                return BarTooltipItem(
                  '${isIncome ? '▲ ' : '▼ '}${NumberFormat('#,##0').format(rod.toY)}',
                  TextStyle(
                    color: isIncome ? AppColors.mintGreen : AppColors.alertRed,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48.0,
                interval: yInterval,
                getTitlesWidget: (value, meta) => Text(
                  _formatYAxis(value),
                  style:
                      const TextStyle(color: AppColors.labelGray, fontSize: 9),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22.0,
                getTitlesWidget: (value, meta) {
                  final labels = _barLabels(txs);
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(labels[idx],
                        style: const TextStyle(
                            color: AppColors.labelGray, fontSize: 9)),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (v) => FlLine(
              color: Colors.white.withValues(alpha: 0.04),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  String _formatYAxis(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }

  List<String> _barLabels(List<AppTransaction> txs) {
    switch (_period) {
      case AnalysisPeriod.d1:
        return List.generate(24, (i) => i % 4 == 0 ? '$i' : '');
      case AnalysisPeriod.d7:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case AnalysisPeriod.d30:
        final daysInMonth =
            DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
        return List.generate(
            daysInMonth, (i) => (i + 1) % 5 == 0 ? '${i + 1}' : '');
      case AnalysisPeriod.d180:
      case AnalysisPeriod.d360:
        final months = txs
            .map((t) => '${t.date.year}-${t.date.month}')
            .toSet()
            .toList()
          ..sort();
        return months.map((m) {
          final parts = m.split('-');
          final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
          return DateFormat('MMM').format(dt);
        }).toList();
    }
  }

  List<BarChartGroupData> _buildBarGroups(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    switch (_period) {
      case AnalysisPeriod.d1:
        return _groupByHour(txs, cashTxs);
      case AnalysisPeriod.d7:
        return _groupByWeekday(txs, cashTxs);
      case AnalysisPeriod.d30:
        return _groupByDayOfMonth(txs, cashTxs);
      case AnalysisPeriod.d180:
      case AnalysisPeriod.d360:
        return _groupByMonth(txs, cashTxs);
    }
  }

  BarChartGroupData _barGroup(int x, double income, double expense) {
    return BarChartGroupData(
      x: x,
      groupVertically: false,
      barRods: [
        BarChartRodData(
          toY: income,
          color: const Color(0xFFF0B90B),
          width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 0,
            color: Colors.transparent,
          ),
        ),
        BarChartRodData(
          toY: expense,
          color: const Color(0xFFEF4444).withValues(alpha: 0.8),
          width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ],
      barsSpace: 2,
    );
  }

  List<BarChartGroupData> _groupByHour(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    Map<int, List<double>> map = {
      for (int i = 0; i < 24; i++) i: [0, 0]
    };
    for (var t in txs) {
      bool isCashTransfer = t.reason?.toLowerCase() == 'cash' ||
          t.customReasonText?.toLowerCase() == 'cash' ||
          t.resolvedReason?.toLowerCase() == 'cash';
      if (isCashTransfer) continue;

      if (t.type == 'income') map[t.date.hour]![0] += t.amount;
      if (t.type == 'expense') map[t.date.hour]![1] += t.amount;
    }
    for (var t in cashTxs) {
      if (t.type == 'addition') map[t.date.hour]![0] += t.amount;
      if (t.type == 'expense') map[t.date.hour]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByWeekday(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    Map<int, List<double>> map = {
      for (int i = 0; i < 7; i++) i: [0, 0]
    };
    for (var t in txs) {
      bool isCashTransfer = t.reason?.toLowerCase() == 'cash' ||
          t.customReasonText?.toLowerCase() == 'cash' ||
          t.resolvedReason?.toLowerCase() == 'cash';
      if (isCashTransfer) continue;

      final dow = (t.date.weekday - 1) % 7;
      if (t.type == 'income') map[dow]![0] += t.amount;
      if (t.type == 'expense') map[dow]![1] += t.amount;
    }
    for (var t in cashTxs) {
      final dow = (t.date.weekday - 1) % 7;
      if (t.type == 'addition') map[dow]![0] += t.amount;
      if (t.type == 'expense') map[dow]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByDayOfMonth(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    Map<int, List<double>> map = {
      for (int i = 1; i <= days; i++) i: [0, 0]
    };
    for (var t in txs) {
      bool isCashTransfer = t.reason?.toLowerCase() == 'cash' ||
          t.customReasonText?.toLowerCase() == 'cash' ||
          t.resolvedReason?.toLowerCase() == 'cash';
      if (isCashTransfer) continue;

      if (t.type == 'income') map[t.date.day]![0] += t.amount;
      if (t.type == 'expense') map[t.date.day]![1] += t.amount;
    }
    for (var t in cashTxs) {
      if (t.type == 'addition') map[t.date.day]![0] += t.amount;
      if (t.type == 'expense') map[t.date.day]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key - 1, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByMonth(
      List<AppTransaction> txs, List<CashTransaction> cashTxs) {
    Map<String, List<double>> map = {};
    for (var t in txs) {
      bool isCashTransfer = t.reason?.toLowerCase() == 'cash' ||
          t.customReasonText?.toLowerCase() == 'cash' ||
          t.resolvedReason?.toLowerCase() == 'cash';
      if (isCashTransfer) continue;

      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => [0, 0]);
      if (t.type == 'income') map[key]![0] += t.amount;
      if (t.type == 'expense') map[key]![1] += t.amount;
    }
    for (var t in cashTxs) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => [0, 0]);
      if (t.type == 'addition') map[key]![0] += t.amount;
      if (t.type == 'expense') map[key]![1] += t.amount;
    }
    final sorted = map.keys.toList()..sort();
    return sorted
        .asMap()
        .entries
        .map((e) => _barGroup(e.key, map[e.value]![0], map[e.value]![1]))
        .toList();
  }

  // ─── Radar Chart: Category Spending ─────────────────────────────────────────
  Widget _buildRadarSection(List<AppTransaction> txs,
      List<CashTransaction> cashTxs, FinanceProvider provider) {
    final categoryTotals = <String, double>{};
    // Regular expenses (Neutralize Cash transfers)
    for (var t in txs.where((t) =>
        t.type == 'expense' &&
        t.reason?.toLowerCase() != 'cash' &&
        t.customReasonText?.toLowerCase() != 'cash' &&
        t.resolvedReason?.toLowerCase() != 'cash')) {
      final cat = (t.resolvedReason?.isNotEmpty == true)
          ? t.resolvedReason!
          : t.category;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + t.amount;
    }
    // Cash wallet expenses (Now unified with Reason system)
    for (var ctx in cashTxs.where((t) => t.type == 'expense')) {
      final cat = ctx.reasonName ?? 'Other Cash';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + ctx.amount;
    }

    if (categoryTotals.isEmpty) {
      return _buildEmptyState('No expense data for this period');
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList(); // radar works best with 5-7 axes
    final maxVal = top.isEmpty ? 0.0 : top.first.value;
    final totalExpense = top.fold<double>(0, (s, e) => s + e.value);

    if (top.length < 3) {
      return _buildEmptyState(
          'Add at least 3 expense categories to see the spending chart.');
    }

    return Column(
      children: [
        // ── Full Width Radar Chart ─────────────────
        Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              tickCount: 4,
              ticksTextStyle:
                  const TextStyle(color: Colors.transparent, fontSize: 0),
              gridBorderData: BorderSide(
                  color: Colors.white.withValues(alpha: 0.07), width: 1),
              radarBorderData: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              titlePositionPercentageOffset: 0.2,
              titleTextStyle: const TextStyle(
                  color: AppColors.textGray,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
              getTitle: (index, angle) {
                if (index >= top.length) return const RadarChartTitle(text: '');
                final name = top[index].key;
                return RadarChartTitle(
                  text: name.length > 10 ? '${name.substring(0, 9)}…' : name,
                  angle: angle,
                );
              },
              dataSets: [
                RadarDataSet(
                  dataEntries: top
                      .map((e) => RadarEntry(
                          value: maxVal > 0 ? (e.value / maxVal) * 100 : 0))
                      .toList(),
                  fillColor: const Color(0xFFF0B90B).withValues(alpha: 0.15),
                  borderColor: const Color(0xFFF0B90B),
                  borderWidth: 2,
                  entryRadius: 3,
                ),
              ],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutQuart,
          ),
        ),

        const SizedBox(height: 24),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: top.asMap().entries.map((entry) {
            final pct = totalExpense > 0
                ? (entry.value.value / totalExpense * 100).toStringAsFixed(1)
                : '0';
            final color = _categoryColor(entry.key);

            // 3 cards per row: (screenWidth - 32 horizontal padding - 16 gaps of 8) / 3
            final cardWidth = (MediaQuery.of(context).size.width - 32 - 16) / 3;

            return Container(
              width: cardWidth,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Color dot + category name
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry.value.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Percentage
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  // Amount
                  Text(
                    NumberFormat('#,##0').format(entry.value.value),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _categoryColor(int i) {
    const colors = [
      Color(0xFFF0B90B), // Gold
      Color(0xFF3EB489), // Mint
      Color(0xFF64B5F6), // Blue
      Color(0xFFCE93D8), // Purple
      Color(0xFFF48FB1), // Pink
      Color(0xFFEF4444), // Red
    ];
    return colors[i % colors.length];
  }

  // ─── Bank Performance ────────────────────────────────────────────────────────
  Widget _buildBankPerformance(
      List<AppTransaction> txs, FinanceProvider provider) {
    final banks = provider.senders.map((s) => s.senderName).toList();
    if (banks.isEmpty || txs.isEmpty) {
      return _buildEmptyState('No bank data for this period');
    }

    // Compute per-bank stats
    final List<_BankStat> stats = [];
    for (final bank in banks) {
      final bankTxs = txs.where((t) => t.name == bank).toList();
      final income = bankTxs
          .where((t) => t.type == 'income')
          .fold<double>(0, (s, t) => s + t.amount);
      final expense = bankTxs
          .where((t) => t.type == 'expense')
          .fold<double>(0, (s, t) => s + t.amount);
      final net = income - expense;

      // Latest balance
      double latestBal = 0;
      final withBal = bankTxs.where((t) => t.totalBalance > 0);
      if (withBal.isNotEmpty) latestBal = withBal.first.totalBalance;

      stats.add(_BankStat(
          name: bank,
          income: income,
          expense: expense,
          net: net,
          balance: latestBal,
          txCount: bankTxs.length));
    }

    // Sort: banks with most transactions first
    stats.sort((a, b) => b.txCount.compareTo(a.txCount));

    final totalAbs = stats.fold<double>(0, (s, b) => s + b.income + b.expense);
    final fmt = NumberFormat('#,##0');

    return Column(
      children: stats.map((s) {
        final share = totalAbs > 0 ? (s.income + s.expense) / totalAbs : 0.0;
        final incomeShare = (s.income + s.expense) > 0
            ? s.income / (s.income + s.expense)
            : 0.0;
        final isPositive = s.net >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _bankLogo(s.name),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        Text('${s.txCount} transactions',
                            style: const TextStyle(
                                color: AppColors.labelGray, fontSize: 11)),
                      ],
                    ),
                  ),
                  // Net badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A34).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color:
                              const Color(0xFFF0B90B).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                            isPositive
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color: isPositive
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${isPositive ? '+' : ''}${fmt.format(s.net)}',
                          style: TextStyle(
                            color: isPositive
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress bar: income vs expense
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: incomeShare.clamp(0.0, 1.0),
                    backgroundColor:
                        const Color(0xFFEF4444).withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.mintGreen),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statChip(
                      '▲ ${fmt.format(s.income)}', const Color(0xFF3EB489)),
                  _statChip(
                      '▼ ${fmt.format(s.expense)}', const Color(0xFFEF4444)),
                  if (s.balance > 0)
                    _statChip('Bal: ${fmt.format(s.balance)}',
                        const Color(0xFFF0B90B)),
                ],
              ),
              // Share pill
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Activity share:',
                      style:
                          TextStyle(color: AppColors.textGray, fontSize: 10)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFF0B90B),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${(share * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: AppColors.textGray, fontSize: 10)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _statChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    Widget logoWidget;
    List<Color> cardGradient;

    if (nameUp == 'CBE') {
      logoWidget = Image.asset('assets/images/CBE logo 1.png',
          width: 22, height: 22, fit: BoxFit.contain);
      cardGradient = [
        const Color(0xFF3D1B0F),
        const Color(0xFF6E482F),
        const Color(0xFF3D1B0F)
      ];
    } else if (nameUp == 'TELEBIRR') {
      logoWidget = Image.asset('assets/images/Telebirr Logo.png',
          width: 22, height: 22, fit: BoxFit.contain);
      cardGradient = [
        const Color(0xFF0BA751),
        const Color(0xFF88BF47),
        const Color(0xFF0BA751)
      ];
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      logoWidget = Image.asset('assets/images/CBEBirr Logo.png',
          width: 22, height: 22, fit: BoxFit.contain);
      cardGradient = [
        const Color(0xFFAFAFB3),
        const Color(0xFFFFFFFF),
        const Color(0xFFAFAFB3)
      ];
    } else {
      logoWidget = Text(
        name.substring(0, min(1, name.length)).toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      );
      cardGradient = [
        const Color(0xFF1E1E26),
        const Color(0xFF3E3E4A),
        const Color(0xFF1E1E26)
      ];
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardGradient.first, width: 1.5),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: SweepGradient(
            center: Alignment.center,
            transform: const GradientRotation(pi / 4),
            colors: cardGradient,
          ),
        ),
        child: Center(child: logoWidget),
      ),
    );
  }

  Widget _buildReasonBreakdown(List<AppTransaction> txs,
      List<CashTransaction> cashTxs, FinanceProvider provider) {
    final Map<String, double> reasonTotals = {};
    // Regular
    for (var t in txs.where((t) =>
        t.type == 'expense' &&
        t.reason?.toLowerCase() != 'cash' &&
        t.customReasonText?.toLowerCase() != 'cash' &&
        t.resolvedReason?.toLowerCase() != 'cash')) {
      final label = (t.resolvedReason?.isNotEmpty == true)
          ? t.resolvedReason!
          : 'Uncategorized';
      reasonTotals[label] = (reasonTotals[label] ?? 0) + t.amount;
    }
    // Cash
    for (var ctx in cashTxs.where((t) => t.type == 'expense')) {
      final label = ctx.reasonName ?? 'Other Cash';
      reasonTotals[label] = (reasonTotals[label] ?? 0) + ctx.amount;
    }

    if (reasonTotals.isEmpty) {
      return _buildEmptyState('Tag your expenses with reasons for insights');
    }

    final sorted = reasonTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<double>(0, (s, e) => s + e.value);
    final fmt = NumberFormat('#,##0.00');

    return Column(
      children: sorted.asMap().entries.take(8).map((entry) {
        final i = entry.key;
        final e = entry.value;
        final pct = total > 0 ? e.value / total : 0.0;
        final color = _categoryColor(i);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              // Rank circle
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.3), width: 1),
                ),
                child: Center(
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        Text(fmt.format(e.value),
                            style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${(pct * 100).toStringAsFixed(1)}% of total expenses',
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              color: Colors.white.withValues(alpha: 0.12), size: 28),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.labelGray, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Data class ─────────────────────────────────────────────────────────────
class _BankStat {
  final String name;
  final double income;
  final double expense;
  final double net;
  final double balance;
  final int txCount;

  const _BankStat({
    required this.name,
    required this.income,
    required this.expense,
    required this.net,
    required this.balance,
    required this.txCount,
  });
}
