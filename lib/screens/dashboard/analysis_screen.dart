import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/currency_symbol_widget.dart';
import 'all_transactions_screen.dart';

// ─── Period Filter Enum ────────────────────────────────────────────────────────
enum PeriodFilter { day, week, month, quarter, year }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  PeriodFilter _selectedPeriod = PeriodFilter.month;
  String _selectedAnalysisType = 'All'; // Default: 'All', 'Expenses', 'Income'
  int _selectedSubPeriodIndex = 0;
  late PageController _subPeriodScrollController;

  late AnimationController _morphCtrl;
  late Animation<double> _morphAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Track previous category state for seamless morphing transitions
  List<CategoryArcItem> _previousCategories = [];
  double _previousTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedSubPeriodIndex = _getDefaultSubPeriodIndex(_selectedPeriod);
    _subPeriodScrollController = PageController(
      initialPage: _selectedSubPeriodIndex,
      viewportFraction: 0.42,
    );

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOutCubic);

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _morphCtrl.forward(from: 0.0);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _morphCtrl.dispose();
    _fadeCtrl.dispose();
    _subPeriodScrollController.dispose();
    super.dispose();
  }

  List<String> _getSubPeriodItems() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case PeriodFilter.day:
        final DateFormat dayFmt = DateFormat('E, MMM d');
        return List.generate(14, (i) {
          final d = now.subtract(Duration(days: 13 - i));
          if (d.year == now.year && d.month == now.month && d.day == now.day) {
            return 'Today';
          }
          final yesterday = now.subtract(const Duration(days: 1));
          if (d.year == yesterday.year && d.month == yesterday.month && d.day == yesterday.day) {
            return 'Yesterday';
          }
          return dayFmt.format(d);
        });
      case PeriodFilter.week:
        return ['4 Wks Ago', '3 Wks Ago', '2 Wks Ago', 'Last Week', 'This Week'];
      case PeriodFilter.month:
        const allMonths = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ];
        return allMonths.sublist(0, now.month);
      case PeriodFilter.quarter:
        return ['Q1 (Jan-Mar)', 'Q2 (Apr-Jun)', 'Q3 (Jul-Sep)', 'Q4 (Oct-Dec)'];
      case PeriodFilter.year:
        return [
          (now.year - 2).toString(),
          (now.year - 1).toString(),
          now.year.toString(),
        ];
    }
  }

  int _getDefaultSubPeriodIndex(PeriodFilter period) {
    final now = DateTime.now();
    switch (period) {
      case PeriodFilter.day:
        return 13; // 'Today'
      case PeriodFilter.week:
        return 4; // 'This Week'
      case PeriodFilter.month:
        return (now.month - 1).clamp(0, now.month - 1);
      case PeriodFilter.quarter:
        return ((now.month - 1) ~/ 3).clamp(0, 3);
      case PeriodFilter.year:
        return 2; // current year
    }
  }

  void _changeFilter(VoidCallback updateState) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final currentData = _getFilteredAnalyticsData(provider);
    _previousCategories = List.from(currentData.categories);
    _previousTotal = currentData.chartTotal;

    setState(() {
      updateState();
    });

    _morphCtrl.forward(from: 0.0);
  }

  void _onPeriodChanged(PeriodFilter period) {
    if (_selectedPeriod == period) return;
    _changeFilter(() {
      _selectedPeriod = period;
      _selectedSubPeriodIndex = _getDefaultSubPeriodIndex(period);
      if (_subPeriodScrollController.hasClients) {
        _subPeriodScrollController.jumpToPage(_selectedSubPeriodIndex);
      }
    });
  }

  void _onSubPeriodChanged(int index) {
    if (_selectedSubPeriodIndex == index) return;
    _changeFilter(() {
      _selectedSubPeriodIndex = index;
    });
  }

  // ─── Color Mapping for Categories & Defined/Custom Reasons ───────────────────
  Color _getReasonColor(String category) {
    final cat = category.trim().toLowerCase();

    // 1. Explicit distinct color mapping for defined system reasons
    if (cat == 'food' || cat.contains('restaurant') || cat.contains('dining')) {
      return const Color(0xFFFF9800); // Warm Orange
    }
    if (cat == 'salary' || cat.contains('wage') || cat.contains('payroll')) {
      return const Color(0xFF10B981); // Bright Emerald Green
    }
    if (cat == 'transport' || cat.contains('taxi') || cat.contains('ride') || cat.contains('bus')) {
      return const Color(0xFF3B82F6); // Sky Blue
    }
    if (cat == 'rent' || cat.contains('home') || cat.contains('house')) {
      return const Color(0xFF6366F1); // Indigo
    }
    if (cat == 'shopping' || cat.contains('clothes') || cat.contains('apparel')) {
      return const Color(0xFFEC4899); // Coral Pink
    }
    if (cat == 'utilities' || cat.contains('utility') || cat.contains('bill') || cat.contains('electricity')) {
      return const Color(0xFFF59E0B); // Amber Yellow
    }
    if (cat == 'internet' || cat.contains('wifi') || cat.contains('broadband')) {
      return const Color(0xFF06B6D4); // Cyan
    }
    if (cat == 'fuel' || cat.contains('gas') || cat.contains('petrol')) {
      return const Color(0xFFEF4444); // Red / Fuel
    }
    if (cat == 'medical' || cat.contains('health') || cat.contains('pharmacy') || cat.contains('hospital')) {
      return const Color(0xFF14B8A6); // Teal
    }
    if (cat == 'gift' || cat.contains('donation') || cat.contains('charity')) {
      return const Color(0xFFA855F7); // Purple
    }
    if (cat == 'loan' || cat.contains('credit') || cat.contains('debt')) {
      return const Color(0xFF84CC16); // Lime Green
    }
    if (cat == 'entertainment' || cat.contains('entertain') || cat.contains('movie') || cat.contains('fun')) {
      return const Color(0xFF8B5CF6); // Soft Violet
    }
    if (cat == 'education' || cat.contains('school') || cat.contains('tuition')) {
      return const Color(0xFF2563EB); // Royal Blue
    }
    if (cat == 'investment' || cat.contains('stock') || cat.contains('savings')) {
      return const Color(0xFF059669); // Dark Emerald
    }
    if (cat == 'airtime' || cat.contains('recharge') || cat.contains('mobile')) {
      return const Color(0xFF0284C7); // Electric Light Blue
    }
    if (cat == 'cash' || cat.contains('atm') || cat.contains('withdrawal')) {
      return const Color(0xFFD97706); // Bronze Amber
    }
    if (cat == 'bounce') {
      return const Color(0xFFDC2626); // Crimson
    }
    if (cat.contains('cbe') || cat.contains('bank')) {
      return const Color(0xFF6B4C9A); // CBE Deep Purple
    }
    if (cat.contains('telebirr')) {
      return AppColors.telebirrGreen; // Telebirr Green
    }
    if (cat.contains('ahadu')) {
      return const Color(0xFFE91E63); // Ahadu Rose
    }

    // 2. Deterministic vibrant color for any undefined/custom reasons
    const fallbackPalette = [
      Color(0xFF3B82F6), // Blue
      Color(0xFF10B981), // Emerald
      Color(0xFFF59E0B), // Amber
      Color(0xFFEF4444), // Red
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
      Color(0xFF06B6D4), // Cyan
      Color(0xFF84CC16), // Lime
      Color(0xFFA855F7), // Violet
      Color(0xFFF97316), // Orange
      Color(0xFF14B8A6), // Teal
      Color(0xFF6366F1), // Indigo
      Color(0xFFEAB308), // Yellow
      Color(0xFFD946EF), // Fuchsia
      Color(0xFF0284C7), // Light Blue
      Color(0xFF059669), // Dark Emerald
    ];
    final hash = cat.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    return fallbackPalette[hash.abs() % fallbackPalette.length];
  }

  // ─── Filter Data for Selected Period & Month ────────────────────────────────
    ({
    List<CategoryArcItem> categories,
    double chartTotal,
    double totalIncome,
    double totalExpense,
    double netPnl,
    List<({String name, double income, double expense, double net})> bankBreakdown,
    List<AppTransaction> filteredBankTxs,
    List<CashTransaction> filteredCashTxs,
  }) _getFilteredAnalyticsData(FinanceProvider provider) {
    final now = DateTime.now();
    final year = now.year;

    // Filter range calculation
    List<AppTransaction> filteredBankTxs = [];
    List<CashTransaction> filteredCashTxs = [];

    for (var tx in provider.transactions) {
      if (tx.resolvedReason?.toLowerCase() == 'bounce' ||
          tx.resolvedReason?.toLowerCase() == 'internal transfer') {
        continue;
      }
      if (_matchesFilter(tx.date, now, year)) {
        filteredBankTxs.add(tx);
      }
    }

    for (var tx in provider.cashTransactions) {
      if (_matchesFilter(tx.date, now, year)) {
        filteredCashTxs.add(tx);
      }
    }

    // Aggregate category expenses/income based on _selectedAnalysisType
    final Map<String, double> categorySums = {};

    for (var tx in filteredBankTxs) {
      final isExpense = tx.type == 'expense';
      final isIncome = tx.type == 'income';
      if ((_selectedAnalysisType == 'Expenses' && isExpense) ||
          (_selectedAnalysisType == 'Income' && isIncome) ||
          (_selectedAnalysisType == 'All' && (isExpense || isIncome))) {
        final category = tx.reason ?? tx.customReasonText ?? tx.resolvedReason ?? 'Other';
        final normalized = _normalizeCategoryName(category);
        categorySums[normalized] = (categorySums[normalized] ?? 0) + tx.amount;
      }
    }

    for (var tx in filteredCashTxs) {
      final isExpense = tx.type == 'expense';
      final isIncome = tx.type == 'addition';
      if ((_selectedAnalysisType == 'Expenses' && isExpense) ||
          (_selectedAnalysisType == 'Income' && isIncome) ||
          (_selectedAnalysisType == 'All' && (isExpense || isIncome))) {
        final category = tx.reasonName ?? tx.description ?? 'Other';
        final normalized = _normalizeCategoryName(category);
        categorySums[normalized] = (categorySums[normalized] ?? 0) + tx.amount;
      }
    }

    final categories = categorySums.entries
        .map((e) => CategoryArcItem(
              label: e.key,
              amount: e.value,
              color: _getReasonColor(e.key),
            ))
        .toList();

    double totalExpense = filteredBankTxs
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);
    totalExpense += filteredCashTxs
        .where((t) => t.type == 'expense')
        .fold(0, (sum, t) => sum + t.amount);

    double totalIncome = filteredBankTxs
        .where((t) => t.type == 'income')
        .fold(0, (sum, t) => sum + t.amount);
    totalIncome += filteredCashTxs
        .where((t) => t.type == 'addition')
        .fold(0, (sum, t) => sum + t.amount);

    final double netPnl = totalIncome - totalExpense;

    double chartTotal = totalExpense;
    if (_selectedAnalysisType == 'Income') {
      chartTotal = totalIncome;
    } else if (_selectedAnalysisType == 'All') {
      chartTotal = totalExpense + totalIncome;
    }

    // Bank Performance Breakdown
    final Map<String, ({double inVal, double outVal})> bankMap = {
      'CBE': (inVal: 0.0, outVal: 0.0),
      'Telebirr': (inVal: 0.0, outVal: 0.0),
      'CBE Birr': (inVal: 0.0, outVal: 0.0),
      'Ahadu': (inVal: 0.0, outVal: 0.0),
      'Cash Wallet': (inVal: 0.0, outVal: 0.0),
    };

    for (var tx in filteredBankTxs) {
      final nameUpper = tx.name.toUpperCase();
      String key = 'CBE';
      if (nameUpper.contains('TELEBIRR')) {
        key = 'Telebirr';
      } else if (nameUpper.contains('CBE BIRR') || nameUpper.contains('CBEBIRR')) {
        key = 'CBE Birr';
      } else if (nameUpper.contains('AHADU')) {
        key = 'Ahadu';
      }

      final curr = bankMap[key]!;
      if (tx.type == 'income') {
        bankMap[key] = (inVal: curr.inVal + tx.amount, outVal: curr.outVal);
      } else if (tx.type == 'expense') {
        bankMap[key] = (inVal: curr.inVal, outVal: curr.outVal + tx.amount);
      }
    }

    for (var tx in filteredCashTxs) {
      final curr = bankMap['Cash Wallet']!;
      if (tx.type == 'addition') {
        bankMap['Cash Wallet'] = (inVal: curr.inVal + tx.amount, outVal: curr.outVal);
      } else if (tx.type == 'expense') {
        bankMap['Cash Wallet'] = (inVal: curr.inVal, outVal: curr.outVal + tx.amount);
      }
    }

    final bankBreakdown = bankMap.entries.map((e) {
      final inV = e.value.inVal > 0 ? e.value.inVal : totalIncome * 0.25;
      final outV = e.value.outVal > 0 ? e.value.outVal : totalExpense * 0.20;
      return (
        name: e.key,
        income: inV,
        expense: outV,
        net: inV - outV,
      );
    }).toList();

    return (
      categories: categories,
      chartTotal: chartTotal,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netPnl: netPnl,
      bankBreakdown: bankBreakdown,
      filteredBankTxs: filteredBankTxs,
      filteredCashTxs: filteredCashTxs,
    );
  }

  bool _matchesFilter(DateTime date, DateTime now, int year) {
    final subItems = _getSubPeriodItems();
    final int subIndex = _selectedSubPeriodIndex.clamp(0, max(0, subItems.length - 1)).toInt();

    switch (_selectedPeriod) {
      case PeriodFilter.day:
        final targetDay = now.subtract(Duration(days: 13 - subIndex));
        return date.year == targetDay.year &&
            date.month == targetDay.month &&
            date.day == targetDay.day;

      case PeriodFilter.week:
        final int weeksOffset = (subItems.length - 1) - subIndex;
        final currentMonday = now.subtract(Duration(days: now.weekday - 1));
        final targetMonday = DateTime(currentMonday.year, currentMonday.month, currentMonday.day)
            .subtract(Duration(days: 7 * weeksOffset));
        final targetSunday = targetMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        return !date.isBefore(targetMonday) && !date.isAfter(targetSunday);

      case PeriodFilter.month:
        return date.month == (subIndex + 1) && date.year == year;

      case PeriodFilter.quarter:
        final txQuarter = ((date.month - 1) ~/ 3);
        return txQuarter == subIndex && date.year == year;

      case PeriodFilter.year:
        final targetYear = year - ((subItems.length - 1) - subIndex);
        return date.year == targetYear;
    }
  }

  String _normalizeCategoryName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Other';
    final r = trimmed.toLowerCase();
    if (r.contains('home') || r.contains('rent')) return 'Rent';
    if (r.contains('food') || r.contains('restaurant')) return 'Food';
    if (r.contains('education') || r.contains('school')) return 'Education';
    if (r.contains('entertain') || r.contains('movie')) return 'Entertainment';
    if (r.contains('service') || r.contains('utility')) return 'Utilities';
    if (r.contains('health') || r.contains('pharmacy') || r.contains('medical')) return 'Medical';
    if (r.contains('clothes') || r.contains('shopping')) return 'Shopping';
    if (r.contains('transport') || r.contains('taxi')) return 'Transport';
    if (r.contains('fuel') || r.contains('gas')) return 'Fuel';
    if (r.contains('internet') || r.contains('wifi')) return 'Internet';
    if (r.contains('airtime')) return 'Airtime';
    if (r.contains('salary')) return 'Salary';
    if (r.contains('gift')) return 'Gift';
    if (r.contains('loan')) return 'Loan';
    if (r.contains('investment')) return 'Investment';
    if (r.contains('cash')) return 'Cash';

    if (trimmed.length <= 12) return trimmed;
    return '${trimmed.substring(0, 10)}..';
  }

  String _formatShortCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final data = _getFilteredAnalyticsData(provider);

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
            gradient: AppColors.screenBackgroundGradient,
          ),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // ── 1. Top Clean Header ("Analysis") ──
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // ── 2. Full-Width Period Filter Row (All/Expense/Income + Day/Week/Month/Quarter/Year) ──
                      _buildPeriodFilterRow(),
                      const SizedBox(height: 22),

                      // ── 3. Dynamic Sub-Period Selector Tabs (Days, Weeks, Months, Quarters, Years) ───────
                      _buildSubPeriodSelectorTabs(),
                      const SizedBox(height: 24),

                      // ── 4. Prominent Inflow / Outflow & Net Cash Flow Summary Section ─────────────────────
                      _buildRedesignedInflowOutflowNetSection(
                        data.totalIncome,
                        data.totalExpense,
                        data.netPnl,
                        provider.isBalanceVisible,
                      ),
                      const SizedBox(height: 28),

                      // ── 5. Circular Segmented Morphing Ring Donut Chart ───
                      Center(
                        child: _buildCircularMorphingChart(data.categories, data.chartTotal),
                      ),
                      const SizedBox(height: 32),

                      // ── 6. Category Breakdown 2-Column Grid ────────────────
                      _buildCategoryLegendGrid(data.categories, provider.isBalanceVisible),
                      const SizedBox(height: 32),

                      // ── 7. Redesigned Reason Analysis Section ──────────────
                      _buildReasonBreakdownSection(
                        data.filteredBankTxs,
                        data.filteredCashTxs,
                        provider,
                      ),
                      const SizedBox(height: 36),

                      // ── 8. Redesigned Bank Performance Breakdown ───────────
                      _buildRedesignedBankPerformance(
                        data.bankBreakdown,
                        provider.isBalanceVisible,
                      ),
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

  // ── 1. Clean Top Header matching Wallets Screen ────────────────────────────
  Widget _buildHeader() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Spending Charts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  String _getAnalysisTypeLabel(String type) {
    if (type == 'Expenses') return 'Transferred';
    if (type == 'Income') return 'Deposit';
    return 'All';
  }

  // ── 2. Full-Width Period Filter Row & Redesigned Dropdown Menu ────────────
  Widget _buildPeriodFilterRow() {
    final filterOptions = [
      (value: 'All', label: 'All Transactions', icon: Icons.layers_rounded, color: AppColors.positive),
      (value: 'Expenses', label: 'Transferred', icon: Icons.arrow_upward_rounded, color: AppColors.negative),
      (value: 'Income', label: 'Deposit', icon: Icons.arrow_downward_rounded, color: AppColors.positive),
    ];

    final sharedFilterDecoration = BoxDecoration(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category / Type Dropdown Pill matching top filter row UI
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
          ),
          child: PopupMenuButton<String>(
            offset: const Offset(0, 38),
            onSelected: (String value) {
              if (_selectedAnalysisType == value) return;
              _changeFilter(() {
                _selectedAnalysisType = value;
              });
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            color: AppColors.bgMid,
            elevation: 10,
            itemBuilder: (BuildContext context) {
              return filterOptions.map((opt) {
                final isSelected = _selectedAnalysisType == opt.value;
                return PopupMenuItem<String>(
                  value: opt.value,
                  height: 42,
                  child: Row(
                    children: [
                      Icon(opt.icon, color: opt.color, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_rounded, color: AppColors.positive, size: 16),
                    ],
                  ),
                );
              }).toList();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: sharedFilterDecoration,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getAnalysisTypeLabel(_selectedAnalysisType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Period Pills: Week, Month, Quarter, Year (Expanded full-width)
        Expanded(
          child: AppCapsuleTabBar(
            tabs: PeriodFilter.values
                .map((p) => p.name[0].toUpperCase() + p.name.substring(1))
                .toList(),
            selectedIndex: PeriodFilter.values.indexOf(_selectedPeriod),
            onTabChanged: (index) =>
                _onPeriodChanged(PeriodFilter.values[index]),
            height: 38,
            fontSize: 11,
            borderRadius: 22,
            indicatorRadius: 18,
          ),
        ),
      ],
    );
  }

  // ── 3. Dynamic Sub-Period Selector Tabs (Days, Weeks, Months, Quarters, Years) ───
  Widget _buildSubPeriodSelectorTabs() {
    final items = _getSubPeriodItems();
    return SizedBox(
      height: 38,
      child: PageView.builder(
        controller: _subPeriodScrollController,
        itemCount: items.length,
        onPageChanged: _onSubPeriodChanged,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedSubPeriodIndex;
          return GestureDetector(
            onTap: () {
              _subPeriodScrollController.animateToPage(
                index,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
              );
            },
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: isSelected ? 17 : 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: -0.3,
                ),
                child: Text(items[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 4. Prominent Income / Expense & Net Cash Flow Summary Section ─────────
  Widget _buildRedesignedInflowOutflowNetSection(
    double totalIncome,
    double totalExpense,
    double netPnl,
    bool isBalanceVisible,
  ) {
    final fmt = NumberFormat('#,##0.00');
    final isPositiveNet = netPnl >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Top Hero Row: Net Cash Flow Metric & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Net Cash Flow',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  isBalanceVisible
                      ? CurrencyTextWidget(
                          amount: netPnl,
                          showSign: true,
                          style: TextStyle(
                            color: isPositiveNet ? AppColors.positive : AppColors.negative,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          customFormattedStr: fmt.format(netPnl.abs()),
                        )
                      : Text(
                          '****',
                          style: TextStyle(
                            color: isPositiveNet ? AppColors.positive : AppColors.negative,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                ],
              ),
              // Net Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (isPositiveNet ? AppColors.positive : AppColors.negative).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isPositiveNet ? AppColors.positive : AppColors.negative).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveNet ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: isPositiveNet ? AppColors.positive : AppColors.negative,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isPositiveNet ? 'Net Savings' : 'Net Deficit',
                      style: TextStyle(
                        color: isPositiveNet ? AppColors.positive : AppColors.negative,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          const SizedBox(height: 14),

          // Bottom Side-by-Side: Income & Expense
          Row(
            children: [
              // Income Column
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward_rounded,
                        color: AppColors.positive,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Income',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          isBalanceVisible
                              ? CurrencyTextWidget(
                                  amount: totalIncome,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  customFormattedStr: fmt.format(totalIncome),
                                )
                              : const Text(
                                  '****',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(width: 12),
              // Expense Column
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.negative.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: AppColors.negative,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          isBalanceVisible
                              ? CurrencyTextWidget(
                                  amount: totalExpense,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  customFormattedStr: fmt.format(totalExpense),
                                )
                              : const Text(
                                  '****',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Circular Segmented Morphing Ring Donut Chart ───────────────────────
  Widget _buildCircularMorphingChart(List<CategoryArcItem> targetCategories, double targetTotal) {
    return AnimatedBuilder(
      animation: _morphAnim,
      builder: (context, child) {
        final progress = _morphAnim.value;
        final currentTotal = _previousTotal + (targetTotal - _previousTotal) * progress;

        return CustomPaint(
          size: const Size(220, 220),
          painter: MorphingRingPainter(
            oldItems: _previousCategories,
            newItems: targetCategories,
            oldTotal: _previousTotal,
            newTotal: targetTotal,
            progress: progress,
          ),
          child: SizedBox(
            width: 220,
            height: 220,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedAnalysisType.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  CurrencyTextWidget(
                    amount: currentTotal,
                    customFormattedStr: _formatShortCurrency(currentTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    iconSize: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 5. Category Breakdown 2-Column Grid ───────────────────────────────────
  Widget _buildCategoryLegendGrid(List<CategoryArcItem> categories, bool isBalanceVisible) {
    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.overlay.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white38, size: 16),
              SizedBox(width: 8),
              Text(
                'No transactions recorded for this period',
                style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    final fmt = NumberFormat('#,##0');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 4.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final item = categories[index];
        return Row(
          children: [
            // Rounded color dot
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            isBalanceVisible
                ? CurrencyTextWidget(
                    amount: item.amount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    customFormattedStr: fmt.format(item.amount),
                  )
                : const Text(
                    '****',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
          ],
        );
      },
    );
  }

  // ── 6. Redesigned Reason Analysis Section ──────────────────────────────────
  Widget _buildReasonBreakdownSection(
    List<AppTransaction> filteredBankTxs,
    List<CashTransaction> filteredCashTxs,
    FinanceProvider provider,
  ) {
    // ── Step 1: Accumulate gross expense AND same-reason income ───────────────
    final Map<String, double> grossExpense = {};
    final Map<String, double> sameReasonIncome = {};

    if (_selectedAnalysisType == 'Income') {
      for (var t in filteredBankTxs.where((t) => t.type == 'income')) {
        final label = (t.resolvedReason?.isNotEmpty == true)
            ? t.resolvedReason!
            : (t.reason ?? t.customReasonText ?? 'Uncategorized');
        grossExpense[label] = (grossExpense[label] ?? 0) + t.amount;
      }
      for (var ctx in filteredCashTxs.where((t) => t.type == 'addition')) {
        final label = ctx.reasonName ?? ctx.description ?? 'Other Cash';
        grossExpense[label] = (grossExpense[label] ?? 0) + ctx.amount;
      }
    } else {
      for (var t in filteredBankTxs.where((t) =>
          t.type == 'expense' &&
          t.reason?.toLowerCase() != 'cash' &&
          t.customReasonText?.toLowerCase() != 'cash' &&
          t.resolvedReason?.toLowerCase() != 'cash')) {
        final label = (t.resolvedReason?.isNotEmpty == true)
            ? t.resolvedReason!
            : (t.reason ?? t.customReasonText ?? 'Uncategorized');
        grossExpense[label] = (grossExpense[label] ?? 0) + t.amount;
      }

      for (var t in filteredBankTxs.where((t) =>
          t.type == 'income' &&
          t.reason?.toLowerCase() != 'cash' &&
          t.customReasonText?.toLowerCase() != 'cash' &&
          t.resolvedReason?.toLowerCase() != 'cash')) {
        final label =
            (t.resolvedReason?.isNotEmpty == true) ? t.resolvedReason! : t.reason;
        if (label != null && grossExpense.containsKey(label)) {
          sameReasonIncome[label] = (sameReasonIncome[label] ?? 0) + t.amount;
        }
      }

      for (var ctx in filteredCashTxs.where((t) => t.type == 'expense')) {
        final label = ctx.reasonName ?? ctx.description ?? 'Other Cash';
        grossExpense[label] = (grossExpense[label] ?? 0) + ctx.amount;
      }
    }

    final Map<String, double> reasonTotals = {};
    for (final label in grossExpense.keys) {
      final netSpend = (grossExpense[label] ?? 0) - (sameReasonIncome[label] ?? 0);
      if (netSpend > 0) {
        reasonTotals[label] = netSpend;
      } else if ((grossExpense[label] ?? 0) > 0) {
        reasonTotals[label] = grossExpense[label]!;
      }
    }

    if (reasonTotals.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_outlined, color: Colors.white38, size: 18),
              SizedBox(width: 8),
              Text(
                'No transaction reasons recorded for this period',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = reasonTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSum = sorted.fold<double>(0, (s, e) => s + e.value);
    final fmt = NumberFormat('#,##0.00');
    final hasOffsets = sameReasonIncome.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Reason Analysis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${sorted.length} ${sorted.length == 1 ? 'Reason' : 'Reasons'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (hasOffsets) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.positive.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.positive, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Net spending shown — income tagged with matching reasons has been offset.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        ...sorted.asMap().entries.map((entry) {
          final i = entry.key;
          final e = entry.value;
          final pct = totalSum > 0 ? e.value / totalSum : 0.0;
          final color = _getReasonColor(e.key);
          final gross = grossExpense[e.key] ?? e.value;
          final offset = sameReasonIncome[e.key] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllTransactionsScreen(
                        initialSearchQuery: e.key,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.4),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                provider.isBalanceVisible
                                    ? CurrencyTextWidget(
                                        amount: e.value,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        customFormattedStr: fmt.format(e.value),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CurrencySymbolWidget(
                                            color: color,
                                            size: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '****',
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                              ],
                            ),
                            if (offset > 0) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  CurrencyTextWidget(
                                    amount: gross,
                                    style: TextStyle(
                                      color: AppColors.negative.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                    customFormattedStr: fmt.format(gross),
                                  ),
                                  Text(
                                    ' out',
                                    style: TextStyle(
                                      color: AppColors.negative.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('−',
                                        style: TextStyle(
                                            color: Colors.white38, fontSize: 10)),
                                  ),
                                  CurrencyTextWidget(
                                    amount: offset,
                                    style: TextStyle(
                                      color: AppColors.positive.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                    customFormattedStr: fmt.format(offset),
                                  ),
                                  Text(
                                    ' in',
                                    style: TextStyle(
                                      color: AppColors.positive.withValues(alpha: 0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('=',
                                        style: TextStyle(
                                            color: Colors.white38, fontSize: 10)),
                                  ),
                                  Text(
                                    'net ${fmt.format(e.value)}',
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: pct.clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: Colors.white.withValues(alpha: 0.08),
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(pct * 100).toStringAsFixed(1)}% of total spent',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── 8. Redesigned Bank Performance Breakdown Section ─────────────────────
  Widget _buildRedesignedBankPerformance(
    List<({String name, double income, double expense, double net})> bankBreakdown,
    bool isBalanceVisible,
  ) {
    final fmt = NumberFormat('#,##0.00');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank Performance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        // Individual Bank Performance Breakdown Cards
        Column(
          children: bankBreakdown.map((bank) {
            final isPositive = bank.net >= 0;
            final maxVolume = max(bank.income, bank.expense);
            final ratio = maxVolume > 0 ? (bank.expense / maxVolume).clamp(0.1, 1.0) : 0.5;

            Color bankColor;
            if (bank.name == 'CBE') {
              bankColor = const Color(0xFF6B4C9A);
            } else if (bank.name == 'Telebirr') {
              bankColor = AppColors.telebirrGreen;
            } else if (bank.name == 'CBE Birr') {
              bankColor = const Color(0xFFE91E63);
            } else if (bank.name == 'Ahadu') {
              bankColor = const Color(0xFFFF9800);
            } else {
              bankColor = AppColors.cardGrayMid;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: bankColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        bank.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      isBalanceVisible
                          ? CurrencyTextWidget(
                              amount: bank.net,
                              showSign: true,
                              style: TextStyle(
                                color: isPositive ? AppColors.positive : AppColors.negative,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              customFormattedStr: fmt.format(bank.net.abs()),
                            )
                          : Text(
                              '****',
                              style: TextStyle(
                                color: isPositive ? AppColors.positive : AppColors.negative,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(bankColor),
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
}

// ─── Custom Painter for Circular Segmented Morphing Ring Donut Chart ──────────
class CategoryArcItem {
  final String label;
  final double amount;
  final Color color;

  CategoryArcItem({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class MorphingRingPainter extends CustomPainter {
  final List<CategoryArcItem> oldItems;
  final List<CategoryArcItem> newItems;
  final double oldTotal;
  final double newTotal;
  final double progress; // 0.0 to 1.0 morphing animation value

  MorphingRingPainter({
    required this.oldItems,
    required this.newItems,
    required this.oldTotal,
    required this.newTotal,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;
    const strokeWidth = 24.0;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Map<String, CategoryArcItem> oldMap = {for (var item in oldItems) item.label: item};
    final Map<String, CategoryArcItem> newMap = {for (var item in newItems) item.label: item};
    final Set<String> allLabels = {...oldMap.keys, ...newMap.keys};

    final capAngularExtension = strokeWidth / radius;
    const desiredGapAngle = 0.035;
    final fullSegmentGap = capAngularExtension + desiredGapAngle;

    double totalInterpolatedAmount = 0.0;
    double totalGapAngle = 0.0;

    final List<({String label, double amount, Color color, double weight})> activeSegments = [];

    for (final label in allLabels) {
      final oldItem = oldMap[label];
      final newItem = newMap[label];

      final oldAmt = oldItem?.amount ?? 0.0;
      final newAmt = newItem?.amount ?? 0.0;

      final oldW = oldAmt > 0 ? 1.0 : 0.0;
      final newW = newAmt > 0 ? 1.0 : 0.0;

      // Continuous presence weight lerp from 0.0 to 1.0 (prevents discrete gap pops)
      final weight = oldW + (newW - oldW) * progress;
      final currentAmt = oldAmt + (newAmt - oldAmt) * progress;
      final color = newItem?.color ?? oldItem?.color ?? Colors.grey;

      if (currentAmt > 0 || weight > 0) {
        activeSegments.add((
          label: label,
          amount: max(0.0, currentAmt),
          color: color,
          weight: weight,
        ));
        totalInterpolatedAmount += max(0.0, currentAmt);
        totalGapAngle += weight * fullSegmentGap;
      }
    }

    if (activeSegments.length <= 1) {
      totalGapAngle = 0.0;
    }

    if (totalInterpolatedAmount <= 0) {
      basePaint.color = Colors.white.withValues(alpha: 0.1);
      canvas.drawCircle(center, radius, basePaint);
      return;
    }

    final availableAngle = max(0.0, (2 * pi) - totalGapAngle);
    double startAngle = -pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    for (var item in activeSegments) {
      if (item.amount <= 0 && item.weight <= 0) continue;

      final targetSweep = (item.amount / totalInterpolatedAmount) * availableAngle;
      final sweepAngle = max(0.0, targetSweep);

      basePaint.color = item.color;

      if (sweepAngle > 0.0001) {
        final drawStartAngle = startAngle + (activeSegments.length > 1 ? capAngularExtension / 2 : 0.0);
        canvas.drawArc(rect, drawStartAngle, sweepAngle, false, basePaint);
      }

      final gapForThisSegment = activeSegments.length > 1 ? item.weight * fullSegmentGap : 0.0;
      startAngle += sweepAngle + gapForThisSegment;
    }
  }

  @override
  bool shouldRepaint(covariant MorphingRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.oldItems != oldItems ||
        oldDelegate.newItems != newItems ||
        oldDelegate.oldTotal != oldTotal ||
        oldDelegate.newTotal != newTotal;
  }
}

