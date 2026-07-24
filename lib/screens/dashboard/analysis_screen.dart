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

// ─── Period Filter Enum ────────────────────────────────────────────────────────
enum PeriodFilter { week, month, quarter, year }

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  PeriodFilter _selectedPeriod = PeriodFilter.month;
  String _selectedAnalysisType = 'All'; // Default: 'All', 'Expenses', 'Income'
  int _selectedMonthIndex = DateTime.now().month - 1; // 0 = Jan, 8 = Sep, etc.
  late PageController _monthScrollController;

  late AnimationController _morphCtrl;
  late Animation<double> _morphAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  late List<String> _monthsList;

  // Track previous category state for seamless morphing transitions
  List<CategoryArcItem> _previousCategories = [];
  double _previousTotal = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
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
    _monthsList = allMonths.sublist(0, now.month);
    _selectedMonthIndex = (now.month - 1).clamp(0, _monthsList.length - 1);
    _monthScrollController = PageController(
      initialPage: _selectedMonthIndex,
      viewportFraction: 0.38,
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
    _monthScrollController.dispose();
    super.dispose();
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
    });
  }

  void _onMonthChanged(int index) {
    if (_selectedMonthIndex == index) return;
    _changeFilter(() {
      _selectedMonthIndex = index;
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
    );
  }

  bool _matchesFilter(DateTime date, DateTime now, int year) {
    switch (_selectedPeriod) {
      case PeriodFilter.week:
        return now.difference(date).inDays <= 7;
      case PeriodFilter.month:
        return date.month == (_selectedMonthIndex + 1);
      case PeriodFilter.quarter:
        final currentQuarter = ((_selectedMonthIndex) / 3).floor();
        final txQuarter = ((date.month - 1) / 3).floor();
        return txQuarter == currentQuarter;
      case PeriodFilter.year:
        return date.year == year;
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
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '\$${amount.toStringAsFixed(0)}';
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
                      // ── 1. Top Clean Header ("Analysis" only) ──
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // ── 2. Full-Width Period Filter Row & Dropdown Menu ──
                      _buildPeriodFilterRow(),
                      const SizedBox(height: 22),

                      // ── 3. Sub-Tabs Horizontal Month Selector ─────────────
                      _buildMonthSelectorTabs(),
                      const SizedBox(height: 28),

                      // ── 4. Circular Segmented Morphing Ring Donut Chart ───
                      Center(
                        child: _buildCircularMorphingChart(data.categories, data.chartTotal),
                      ),
                      const SizedBox(height: 32),

                      // ── 5. Category Breakdown 2-Column Grid ────────────────
                      _buildCategoryLegendGrid(data.categories, provider.isBalanceVisible),
                      const SizedBox(height: 36),

                      // ── 6. Redesigned Bank Performance & Summary Section ──
                      _buildRedesignedBankPerformance(
                        data.totalIncome,
                        data.totalExpense,
                        data.netPnl,
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
          'Analysis',
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

  // ── 3. Sub-Tabs Horizontal Month Selector ─────────────────────────────────
  Widget _buildMonthSelectorTabs() {
    return SizedBox(
      height: 38,
      child: PageView.builder(
        controller: _monthScrollController,
        itemCount: _monthsList.length,
        onPageChanged: _onMonthChanged,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedMonthIndex;
          return GestureDetector(
            onTap: () {
              _monthScrollController.animateToPage(
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
                  fontSize: isSelected ? 18 : 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: -0.3,
                ),
                child: Text(_monthsList[index]),
              ),
            ),
          );
        },
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
                  Text(
                    _formatShortCurrency(currentTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
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
            Text(
              isBalanceVisible ? '\$${fmt.format(item.amount)}' : '\$****',
              style: const TextStyle(
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

  // ── 6. Redesigned Bank Performance Section ────────────────────────────────
  Widget _buildRedesignedBankPerformance(
    double totalIncome,
    double totalExpense,
    double netPnl,
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

        // Summary Row: In | Out | Net P/L
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                label: 'Inflow',
                val: totalIncome,
                fmt: fmt,
                color: AppColors.positive,
                icon: Icons.arrow_downward_rounded,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                label: 'Outflow',
                val: totalExpense,
                fmt: fmt,
                color: AppColors.negative,
                icon: Icons.arrow_upward_rounded,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                label: 'Net P/L',
                val: netPnl,
                fmt: fmt,
                color: netPnl >= 0 ? AppColors.positive : AppColors.negative,
                icon: netPnl >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                isBalanceVisible: isBalanceVisible,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                color: AppColors.overlay.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                      Text(
                        isBalanceVisible ? '${isPositive ? '+' : ''}\$${fmt.format(bank.net)}' : '\$****',
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

  Widget _buildMetricTile({
    required String label,
    required double val,
    required NumberFormat fmt,
    required Color color,
    required IconData icon,
    required bool isBalanceVisible,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overlay.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isBalanceVisible ? '\$${fmt.format(val.abs())}' : '\$****',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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

