import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';

// ─── Period Enum ──────────────────────────────────────────────────────────────
enum AnalysisPeriod { daily, weekly, monthly, all }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  AnalysisPeriod _period = AnalysisPeriod.monthly;
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
    _fadeCtrl
      ..reset()
      ..forward();
  }

  // ─── Filtered transactions ──────────────────────────────────────────────────
  List<AppTransaction> _filtered(List<AppTransaction> all) {
    final now = DateTime.now();
    switch (_period) {
      case AnalysisPeriod.daily:
        return all
            .where((t) =>
                t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day)
            .toList();
      case AnalysisPeriod.weekly:
        final week = now.subtract(const Duration(days: 7));
        return all.where((t) => t.date.isAfter(week)).toList();
      case AnalysisPeriod.monthly:
        return all
            .where((t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
      case AnalysisPeriod.all:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final txs = _filtered(provider.transactions);

    // Separate regular transactions and cash transactions
    final regularTxs =
        txs.where((t) => t.reason?.toLowerCase() != 'cash').toList();
    final cashWithdrawals =
        txs.where((t) => t.reason?.toLowerCase() == 'cash').toList();

    // Sum real expenses: Regular expenses + Cash spendings
    double totalExpense = regularTxs
        .where((t) => t.type == 'expense')
        .fold<double>(0, (s, t) => s + t.amount);

    // Add spendings from all cash withdrawals in the period
    final List<dynamic> allSpendingsInPeriod = [];
    for (final tx in cashWithdrawals) {
      final spendings = provider.spendingsForTransaction(tx.id!);
      for (final s in spendings) {
        // Need to filter spendings by the same period Logic?
        // Better: just include all spendings linked to these specific withdrawals
        totalExpense += s.amount;
        allSpendingsInPeriod.add(s);
      }
    }

    final incomes = txs.where((t) => t.type == 'income').toList();
    final totalIncome = incomes.fold<double>(0, (s, t) => s + t.amount);
    final net = totalIncome - totalExpense;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0B0D),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(totalIncome, totalExpense, net),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildPeriodSelector(),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Cash Flow'),
                      const SizedBox(height: 14),
                      _buildBarChart(txs),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Spending by Category'),
                      const SizedBox(height: 14),
                      _buildRadarSection(expenses),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Bank Performance'),
                      const SizedBox(height: 14),
                      _buildBankPerformance(txs, provider),
                      const SizedBox(height: 28),
                      _buildSectionLabel('Top Spending Reasons'),
                      const SizedBox(height: 14),
                      _buildReasonBreakdown(expenses),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sliver App Bar ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(
      double totalIncome, double totalExpense, double net) {
    final fmt = NumberFormat('#,##0.00');
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF0A0B0D),
      surfaceTintColor: Colors.transparent,
      leading: const SizedBox(),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.0, -0.8),
              radius: 1.1,
              colors: [
                Color(0xFF1A4D6E),
                Color(0xFF0D2E40),
                Color(0xFF0A0B0D),
              ],
              stops: [0.0, 0.55, 1.0],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.bar_chart_rounded,
                            color: AppColors.accentBlue, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Analysis',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              )),
                          Text('Spend with awareness',
                              style: TextStyle(
                                  color: Color(0xFF6B8FA6), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: _buildSumCard(
                              'Income',
                              fmt.format(totalIncome),
                              AppColors.mintGreen,
                              Icons.arrow_downward_rounded)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildSumCard(
                              'Expense',
                              fmt.format(totalExpense),
                              AppColors.alertRed,
                              Icons.arrow_upward_rounded)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildSumCard(
                              'Net',
                              (net >= 0 ? '+' : '') + fmt.format(net),
                              net >= 0
                                  ? AppColors.mintGreen
                                  : AppColors.alertRed,
                              Icons.account_balance_wallet_outlined)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSumCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w500)),
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
      (AnalysisPeriod.daily, 'Daily'),
      (AnalysisPeriod.weekly, 'Weekly'),
      (AnalysisPeriod.monthly, 'Monthly'),
      (AnalysisPeriod.all, 'All Time'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111315),
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
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color:
                                AppColors.primaryBlue.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF6B8FA6),
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
  Widget _buildBarChart(List<AppTransaction> txs) {
    // Build time-bucketed data
    final groups = _buildBarGroups(txs);

    if (groups.isEmpty || txs.isEmpty) {
      return _buildEmptyState('No transactions in this period');
    }

    final maxY =
        groups.expand((g) => g.barRods.map((r) => r.toY)).fold<double>(0, max);
    final yInterval = maxY > 0 ? (maxY / 4).ceilToDouble() : 1000.0;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1214),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  style: const TextStyle(color: Color(0xFF3D5566), fontSize: 9),
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
                            color: Color(0xFF3D5566), fontSize: 9)),
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
      case AnalysisPeriod.daily:
        return List.generate(24, (i) => i % 4 == 0 ? '$i' : '');
      case AnalysisPeriod.weekly:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case AnalysisPeriod.monthly:
        final daysInMonth =
            DateTime(DateTime.now().year, DateTime.now().month + 1, 0).day;
        return List.generate(
            daysInMonth, (i) => (i + 1) % 5 == 0 ? '${i + 1}' : '');
      case AnalysisPeriod.all:
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

  List<BarChartGroupData> _buildBarGroups(List<AppTransaction> txs) {
    switch (_period) {
      case AnalysisPeriod.daily:
        return _groupByHour(txs);
      case AnalysisPeriod.weekly:
        return _groupByWeekday(txs);
      case AnalysisPeriod.monthly:
        return _groupByDayOfMonth(txs);
      case AnalysisPeriod.all:
        return _groupByMonth(txs);
    }
  }

  BarChartGroupData _barGroup(int x, double income, double expense) {
    return BarChartGroupData(
      x: x,
      groupVertically: false,
      barRods: [
        BarChartRodData(
          toY: income,
          color: AppColors.mintGreen,
          width: 5,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 0,
            color: Colors.transparent,
          ),
        ),
        BarChartRodData(
          toY: expense,
          color: AppColors.alertRed.withValues(alpha: 0.85),
          width: 5,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
      barsSpace: 2,
    );
  }

  List<BarChartGroupData> _groupByHour(List<AppTransaction> txs) {
    Map<int, List<double>> map = {
      for (int i = 0; i < 24; i++) i: [0, 0]
    };
    for (var t in txs) {
      if (t.type == 'income') map[t.date.hour]![0] += t.amount;
      if (t.type == 'expense') map[t.date.hour]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByWeekday(List<AppTransaction> txs) {
    Map<int, List<double>> map = {
      for (int i = 0; i < 7; i++) i: [0, 0]
    };
    for (var t in txs) {
      final dow = (t.date.weekday - 1) % 7; // Mon=0
      if (t.type == 'income') map[dow]![0] += t.amount;
      if (t.type == 'expense') map[dow]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByDayOfMonth(List<AppTransaction> txs) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month + 1, 0).day;
    Map<int, List<double>> map = {
      for (int i = 1; i <= days; i++) i: [0, 0]
    };
    for (var t in txs) {
      if (t.type == 'income') map[t.date.day]![0] += t.amount;
      if (t.type == 'expense') map[t.date.day]![1] += t.amount;
    }
    return map.entries
        .map((e) => _barGroup(e.key - 1, e.value[0], e.value[1]))
        .toList();
  }

  List<BarChartGroupData> _groupByMonth(List<AppTransaction> txs) {
    Map<String, List<double>> map = {};
    for (var t in txs) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => [0, 0]);
      if (t.type == 'income') map[key]![0] += t.amount;
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
  Widget _buildRadarSection(List<AppTransaction> expenses) {
    final categoryTotals = <String, double>{};
    // Regular expenses
    for (var t in txs.where(
        (t) => t.type == 'expense' && t.reason?.toLowerCase() != 'cash')) {
      final cat = (t.resolvedReason?.isNotEmpty == true)
          ? t.resolvedReason!
          : t.category;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + t.amount;
    }
    // Cash spendings
    for (var tx in txs.where((t) => t.reason?.toLowerCase() == 'cash')) {
      final spendings = provider.spendingsForTransaction(tx.id!);
      for (final s in spendings) {
        final cat = s.expenseName;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + s.amount;
      }
    }

    if (categoryTotals.isEmpty) {
      return _buildEmptyState('No expense data for this period');
    }

    final sorted = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(6).toList(); // radar works best with 5-7 axes
    final maxVal = top.first.value;
    final totalExpense = top.fold<double>(0, (s, e) => s + e.value);

    return Column(
      children: [
        // ── Full Width Radar Chart ─────────────────
        Container(
          width: double.infinity,
          height: 280,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1214).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  color: Color(0xFF6B8FA6),
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
                  fillColor: AppColors.primaryBlue.withValues(alpha: 0.25),
                  borderColor: AppColors.accentBlue,
                  borderWidth: 2.5,
                  entryRadius: 4,
                ),
              ],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutQuart,
          ),
        ),

        const SizedBox(height: 24),

        // ── Descriptions Below (Legend) ─────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: top.asMap().entries.map((entry) {
            final pct = totalExpense > 0
                ? (entry.value.value / totalExpense * 100).toStringAsFixed(1)
                : '0';
            final color = _categoryColor(entry.key);

            return Container(
              width: (MediaQuery.of(context).size.width - 52) / 2, // 2 columns
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1214),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value.key,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${NumberFormat('#,##0').format(entry.value.value)} · $pct%',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10),
                        ),
                      ],
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
      AppColors.accentBlue,
      AppColors.mintGreen,
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
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
            color: const Color(0xFF0F1214),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                                color: Color(0xFF4A6572), fontSize: 11)),
                      ],
                    ),
                  ),
                  // Net badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (isPositive
                              ? AppColors.mintGreen
                              : AppColors.alertRed)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (isPositive
                                  ? AppColors.mintGreen
                                  : AppColors.alertRed)
                              .withValues(alpha: 0.25)),
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
                    backgroundColor: AppColors.alertRed.withValues(alpha: 0.35),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.mintGreen),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statChip('▲ ${fmt.format(s.income)}', AppColors.mintGreen),
                  _statChip('▼ ${fmt.format(s.expense)}', AppColors.alertRed),
                  if (s.balance > 0)
                    _statChip(
                        'Bal: ${fmt.format(s.balance)}', AppColors.accentBlue),
                ],
              ),
              // Share pill
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Activity share:',
                      style: TextStyle(color: Color(0xFF3D5566), fontSize: 10)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 4,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryBlue.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${(share * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Color(0xFF6B8FA6), fontSize: 10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    Widget logo;
    if (nameUp == 'CBE') {
      logo = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/CBE.png',
              width: 38, height: 38, fit: BoxFit.cover));
    } else if (nameUp == 'TELEBIRR') {
      logo = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/Telebirr.png',
              width: 38, height: 38, fit: BoxFit.cover));
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      logo = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/images/CBEBirr.png',
              width: 38, height: 38, fit: BoxFit.cover));
    } else {
      logo = Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Text(name.substring(0, min(2, name.length)).toUpperCase(),
                style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ));
    }
    return logo;
  }

  // ─── Reason Breakdown ────────────────────────────────────────────────────────
  Widget _buildReasonBreakdown(List<AppTransaction> expenses) {
    final Map<String, double> reasonTotals = {};
    // Regular
    for (var t in txs.where(
        (t) => t.type == 'expense' && t.reason?.toLowerCase() != 'cash')) {
      final label = (t.resolvedReason?.isNotEmpty == true)
          ? t.resolvedReason!
          : 'Uncategorized';
      reasonTotals[label] = (reasonTotals[label] ?? 0) + t.amount;
    }
    // Cash
    for (var tx in txs.where((t) => t.reason?.toLowerCase() == 'cash')) {
      final spendings = provider.spendingsForTransaction(tx.id!);
      for (final s in spendings) {
        final label = s.expenseName;
        reasonTotals[label] = (reasonTotals[label] ?? 0) + s.amount;
      }
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1214),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                            color: Color(0xFF3D5566), fontSize: 10)),
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
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0F1214),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_outlined,
              color: Colors.white.withValues(alpha: 0.12), size: 28),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(color: Color(0xFF3D5566), fontSize: 12)),
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
