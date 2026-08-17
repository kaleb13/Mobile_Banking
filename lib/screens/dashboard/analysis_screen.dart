import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../models/reason.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/daily_net_heatmap_widget.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import 'category_detail_screen.dart';
import 'reason_transactions_screen.dart';

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

  DateTime? _selectedHeatmapDay;

  int? _selectedArcIndex;
  AppReason? _drilledCategory;

  late AnimationController _morphCtrl;
  late Animation<double> _morphAnim;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // Track previous category state for seamless morphing transitions
  List<CategoryArcItem> _previousCategories = [];
  double _previousTotal = 0.0;

  DateTime _getSynchronizedTargetDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case PeriodFilter.day:
        return now.subtract(Duration(days: 13 - _selectedSubPeriodIndex));
      case PeriodFilter.week:
        final subItems = _getSubPeriodItems();
        final int weeksOffset = (subItems.length - 1) - _selectedSubPeriodIndex;
        final currentMonday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(currentMonday.year, currentMonday.month, currentMonday.day)
            .subtract(Duration(days: 7 * weeksOffset));
      case PeriodFilter.month:
        return DateTime(now.year, _selectedSubPeriodIndex + 1, 1);
      case PeriodFilter.quarter:
        final startMonth = (_selectedSubPeriodIndex * 3) + 1;
        return DateTime(now.year, startMonth, 1);
      case PeriodFilter.year:
        final targetYear = now.year - (2 - _selectedSubPeriodIndex);
        return DateTime(targetYear, 1, 1);
    }
  }

  DateTimeRange? _getSynchronizedWeekRange() {
    if (_selectedPeriod != PeriodFilter.week) return null;
    final now = DateTime.now();
    final subItems = _getSubPeriodItems();
    final int weeksOffset = (subItems.length - 1) - _selectedSubPeriodIndex;
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final targetMonday = DateTime(currentMonday.year, currentMonday.month, currentMonday.day)
        .subtract(Duration(days: 7 * weeksOffset));
    final targetSunday = targetMonday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return DateTimeRange(start: targetMonday, end: targetSunday);
  }

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
    HapticFeedback.selectionClick();
    _changeFilter(() {
      _selectedPeriod = period;
      _selectedHeatmapDay = null;
      _selectedSubPeriodIndex = _getDefaultSubPeriodIndex(period);
      if (_subPeriodScrollController.hasClients) {
        _subPeriodScrollController.jumpToPage(_selectedSubPeriodIndex);
      }
    });
  }

  void _onSubPeriodChanged(int index) {
    if (_selectedSubPeriodIndex == index) return;
    HapticFeedback.selectionClick();
    _changeFilter(() {
      _selectedSubPeriodIndex = index;
      _selectedHeatmapDay = null;
    });
  }

  // ─── Color Mapping for Categories & Defined/Custom Reasons ───────────────────
  Color _getReasonColor(String category) {
    final cat = category.trim().toLowerCase();

    // 0. Uncategorized & other fallback color
    if (cat == 'uncategorized' || cat == 'other' || cat == 'other cash' || cat.isEmpty) {
      return const Color(0xFF64748B); // Slate Gray
    }

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

  String _resolveTxCategoryName(AppTransaction tx, FinanceProvider provider) {
    if (tx.categoryId != null) {
      final cat = provider.reasons.where((r) => r.id == tx.categoryId).firstOrNull;
      if (cat != null) return cat.name;
    }

    if (tx.reasonId != null) {
      final r = provider.reasons.where((r) => r.id == tx.reasonId).firstOrNull;
      if (r != null) {
        if (r.isSubcategory && r.parentId != null) {
          final p = provider.reasons.where((pr) => pr.id == r.parentId).firstOrNull;
          if (p != null) return p.name;
        }
        return r.name;
      }
    }

    final raw = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '').trim();
    if (raw.isNotEmpty) {
      final matchedReason = provider.reasons
          .where((r) => r.name.toLowerCase() == raw.toLowerCase())
          .firstOrNull;
      if (matchedReason != null) {
        if (matchedReason.isSubcategory && matchedReason.parentId != null) {
          final p = provider.reasons
              .where((pr) => pr.id == matchedReason.parentId)
              .firstOrNull;
          if (p != null) return p.name;
        }
        return matchedReason.name;
      }
      return _normalizeCategoryName(raw);
    }

    return 'Uncategorized';
  }

  String _resolveCashTxCategoryName(CashTransaction ctx, FinanceProvider provider) {
    if (ctx.reasonId != null) {
      final r = provider.reasons.where((res) => res.id == ctx.reasonId).firstOrNull;
      if (r != null) {
        if (r.isSubcategory && r.parentId != null) {
          final p = provider.reasons.where((pr) => pr.id == r.parentId).firstOrNull;
          if (p != null) return p.name;
        }
        return r.name;
      }
    }

    final raw = (ctx.reasonName ?? ctx.description ?? '').trim();
    if (raw.isNotEmpty) {
      final matchedReason = provider.reasons
          .where((r) => r.name.toLowerCase() == raw.toLowerCase())
          .firstOrNull;
      if (matchedReason != null) {
        if (matchedReason.isSubcategory && matchedReason.parentId != null) {
          final p = provider.reasons
              .where((pr) => pr.id == matchedReason.parentId)
              .firstOrNull;
          if (p != null) return p.name;
        }
        return matchedReason.name;
      }
      return _normalizeCategoryName(raw);
    }

    return 'Uncategorized';
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
      final reasonStr = (tx.reason ?? tx.customReasonText ?? tx.resolvedReason ?? '').trim().toLowerCase();
      if (reasonStr == 'bounce' ||
          reasonStr == 'internal transfer' ||
          reasonStr == 'cash') {
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

    // Separate gross category expenses and income
    final Map<String, double> categoryExpenses = {};
    final Map<String, double> categoryIncome = {};

    if (_drilledCategory == null) {
      // Level 1: Top-Level Categories ONLY (Uncategorized always included)
      for (var tx in filteredBankTxs) {
        final categoryLabel = _resolveTxCategoryName(tx, provider);

        if (tx.type == 'expense') {
          categoryExpenses[categoryLabel] = (categoryExpenses[categoryLabel] ?? 0) + tx.amount;
        } else if (tx.type == 'income') {
          categoryIncome[categoryLabel] = (categoryIncome[categoryLabel] ?? 0) + tx.amount;
        }
      }

      for (var tx in filteredCashTxs) {
        final categoryLabel = _resolveCashTxCategoryName(tx, provider);

        if (tx.type == 'expense') {
          categoryExpenses[categoryLabel] = (categoryExpenses[categoryLabel] ?? 0) + tx.amount;
        } else if (tx.type == 'addition') {
          categoryIncome[categoryLabel] = (categoryIncome[categoryLabel] ?? 0) + tx.amount;
        }
      }
    } else {
      // Level 2: Subcategories inside _drilledCategory
      final categoryName = _drilledCategory!.name.toLowerCase();
      for (var tx in filteredBankTxs) {
        final parentCat = _resolveTxCategoryName(tx, provider);
        if (parentCat.toLowerCase() == categoryName) {
          String subName = (tx.reason ?? tx.customReasonText ?? tx.resolvedReason ?? 'General').trim();
          if (subName.isEmpty || subName.toLowerCase() == categoryName) {
            subName = 'General';
          }
          if (tx.type == 'expense') {
            categoryExpenses[subName] = (categoryExpenses[subName] ?? 0) + tx.amount;
          } else if (tx.type == 'income') {
            categoryIncome[subName] = (categoryIncome[subName] ?? 0) + tx.amount;
          }
        }
      }

      for (var tx in filteredCashTxs) {
        final parentCat = _resolveCashTxCategoryName(tx, provider);
        if (parentCat.toLowerCase() == categoryName) {
          String subName = (tx.reasonName ?? tx.description ?? 'General').trim();
          if (subName.isEmpty || subName.toLowerCase() == categoryName) {
            subName = 'General';
          }
          if (tx.type == 'expense') {
            categoryExpenses[subName] = (categoryExpenses[subName] ?? 0) + tx.amount;
          } else if (tx.type == 'addition') {
            categoryIncome[subName] = (categoryIncome[subName] ?? 0) + tx.amount;
          }
        }
      }
    }

    final Map<String, double> categorySums = {};

    if (_selectedAnalysisType == 'Expenses') {
      categorySums.addAll(categoryExpenses);
    } else if (_selectedAnalysisType == 'Income') {
      categorySums.addAll(categoryIncome);
    } else {
      // 'All' mode -> Net mode: Gross Expense minus Matching Category Income (always include active categories)
      final allCategories = {...categoryExpenses.keys, ...categoryIncome.keys};
      for (final cat in allCategories) {
        final exp = categoryExpenses[cat] ?? 0.0;
        final inc = categoryIncome[cat] ?? 0.0;
        final net = exp - inc;
        if (net > 0) {
          categorySums[cat] = net;
        } else if (exp > 0) {
          categorySums[cat] = exp;
        } else if (inc > 0) {
          categorySums[cat] = inc;
        }
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
      chartTotal = categorySums.values.fold(0.0, (sum, val) => sum + val);
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
      final inV = e.value.inVal;
      final outV = e.value.outVal;
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
    if (_selectedHeatmapDay != null) {
      return date.year == _selectedHeatmapDay!.year &&
          date.month == _selectedHeatmapDay!.month &&
          date.day == _selectedHeatmapDay!.day;
    }

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
    if (trimmed.isEmpty ||
        trimmed.toLowerCase() == 'other' ||
        trimmed.toLowerCase() == 'other cash' ||
        trimmed.toLowerCase() == 'uncategorized' ||
        trimmed.toLowerCase() == 'none') {
      return 'Uncategorized';
    }

    final r = trimmed.toLowerCase();

    // Food
    if (r.contains('food') ||
        r.contains('restaurant') ||
        r.contains('grocer') ||
        r.contains('lunch') ||
        r.contains('breakfast') ||
        r.contains('dinner') ||
        r.contains('bakery') ||
        r.contains('snack') ||
        r.contains('meal')) {
      return 'Food';
    }

    // Drink
    if (r.contains('drink') ||
        r.contains('coffee') ||
        r.contains('tea') ||
        r.contains('keshir') ||
        r.contains('cafe') ||
        r.contains('beer') ||
        r.contains('alcohol') ||
        r.contains('soda') ||
        r.contains('juice')) {
      return 'Drink';
    }

    // Transportation
    if (r.contains('transport') ||
        r.contains('taxi') ||
        r.contains('uber') ||
        r.contains('ride') ||
        r.contains('fuel') ||
        r.contains('gas') ||
        r.contains('bus') ||
        r.contains('parking') ||
        r.contains('transit')) {
      return 'Transportation';
    }

    // Utilities
    if (r.contains('utilities') ||
        r.contains('water') ||
        r.contains('electric') ||
        r.contains('garbage') ||
        r.contains('sewer')) {
      return 'Utilities';
    }

    // Housing
    if (r.contains('housing') ||
        r.contains('rent') ||
        r.contains('mortgage') ||
        r.contains('home')) {
      return 'Housing';
    }

    // Mobile & Internet
    if (r.contains('mobile') ||
        r.contains('internet') ||
        r.contains('wifi') ||
        r.contains('airtime') ||
        r.contains('data')) {
      return 'Mobile & Internet';
    }

    // Health & Personal Care
    if (r.contains('health') ||
        r.contains('pharmacy') ||
        r.contains('medical') ||
        r.contains('doctor') ||
        r.contains('hospital') ||
        r.contains('medicine') ||
        r.contains('salon') ||
        r.contains('spa') ||
        r.contains('gym')) {
      return 'Health & Personal Care';
    }

    // Goods
    if (r.contains('goods') ||
        r.contains('clothes') ||
        r.contains('clothing') ||
        r.contains('shopping') ||
        r.contains('gift') ||
        r.contains('supermarket') ||
        r.contains('electronics')) {
      return 'Goods';
    }

    // Entertainment
    if (r.contains('entertainment') ||
        r.contains('movie') ||
        r.contains('game') ||
        r.contains('event') ||
        r.contains('cinema') ||
        r.contains('concert')) {
      return 'Entertainment';
    }

    // Education
    if (r.contains('education') ||
        r.contains('school') ||
        r.contains('tuition') ||
        r.contains('course') ||
        r.contains('book')) {
      return 'Education';
    }

    // Investment & Savings
    if (r.contains('investment') ||
        r.contains('savings') ||
        r.contains('stock') ||
        r.contains('crypto')) {
      return 'Investment & Savings';
    }

    // Salary
    if (r.contains('salary') ||
        r.contains('wage') ||
        r.contains('payroll') ||
        r.contains('bonus') ||
        r.contains('commission')) {
      return 'Salary';
    }

    // Loan
    if (r.contains('loan')) return 'Loan';

    if (trimmed.length <= 16) return trimmed;
    return '${trimmed.substring(0, 14)}..';
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

                      // ── 4. Daily Net Calendar Heatmap Grid Section ───────
                      DailyNetHeatmapWidget(
                        bankTransactions: provider.transactions,
                        cashTransactions: provider.cashTransactions,
                        periodType: HeatmapPeriodType.values[_selectedPeriod.index],
                        selectedDate: _getSynchronizedTargetDate(),
                        highlightedWeekRange: _getSynchronizedWeekRange(),
                        selectedQuarter: _selectedSubPeriodIndex.clamp(0, 3),
                        selectedYear: _selectedPeriod == PeriodFilter.year
                            ? (DateTime.now().year - (2 - _selectedSubPeriodIndex))
                            : DateTime.now().year,
                        selectedDay: _selectedHeatmapDay,
                        onDaySelected: (day) {
                          _changeFilter(() {
                            if (day != null && _selectedPeriod == PeriodFilter.day) {
                              final now = DateTime.now();
                              final diff = now.difference(day).inDays;
                              if (diff >= 0 && diff < 14) {
                                _selectedSubPeriodIndex = 13 - diff;
                                if (_subPeriodScrollController.hasClients) {
                                  _subPeriodScrollController.jumpToPage(_selectedSubPeriodIndex);
                                }
                              }
                            } else {
                              _selectedHeatmapDay = day;
                            }
                          });
                        },
                        onMonthSelected: (monthIndex) {
                          _changeFilter(() {
                            _selectedPeriod = PeriodFilter.month;
                            _selectedSubPeriodIndex = monthIndex;
                            _selectedHeatmapDay = null;
                            if (_subPeriodScrollController.hasClients) {
                              _subPeriodScrollController.jumpToPage(monthIndex);
                            }
                          });
                        },
                        isBalanceVisible: provider.isBalanceVisible,
                        userLevel: provider.userLevel,
                      ),
                      if (_selectedHeatmapDay != null)
                        _buildActiveDayFilterBanner(),
                      const SizedBox(height: 24),

                      // ── 5. Prominent Inflow / Outflow & Net Cash Flow Summary Section ─────────────────────
                      _buildRedesignedInflowOutflowNetSection(
                        data.totalIncome,
                        data.totalExpense,
                        data.netPnl,
                        provider.isBalanceVisible,
                      ),
                      const SizedBox(height: 28),

                      // ── 5. Standalone Segmented Distribution Bar ──────────────────────────
                      _buildStandaloneSegmentedBar(
                        data.categories,
                        data.chartTotal,
                      ),
                      const SizedBox(height: 14),

                      // ── 6. Category Breakdown & Go Deeper Card ────────────────────────────
                      _buildCategoryBreakdownCard(
                        data.categories,
                        data.chartTotal,
                        data.netPnl,
                        provider.isBalanceVisible,
                      ),
                      const SizedBox(height: 28),

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
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActiveDayFilterBanner() {
    if (_selectedHeatmapDay == null) return const SizedBox.shrink();
    final fmtDate = DateFormat('EEEE, MMM d, yyyy').format(_selectedHeatmapDay!);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, color: AppColors.textPrimary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Filtered for $fmtDate',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              _changeFilter(() {
                _selectedHeatmapDay = null;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _getAnalysisTypeLabel(String type) {
    if (type == 'Expenses') return 'Transferred';
    if (type == 'Income') return 'Deposit';
    return 'Net';
  }

  // ── 2. Full-Width Period Filter Row & Redesigned Dropdown Menu ────────────
  Widget _buildPeriodFilterRow() {
    final analysisTypeIndex = switch (_selectedAnalysisType) {
      'Expenses' => 1,
      'Income' => 2,
      _ => 0, // 'All' / Net
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. Period Dropdown Menu (Left) - Uses AppDropdown
        AppDropdown<PeriodFilter>.dark(
          value: _selectedPeriod,
          items: const [
            AppDropdownItem(value: PeriodFilter.day, label: 'Day'),
            AppDropdownItem(value: PeriodFilter.week, label: 'Week'),
            AppDropdownItem(value: PeriodFilter.month, label: 'Month'),
            AppDropdownItem(value: PeriodFilter.quarter, label: 'Quarter'),
            AppDropdownItem(value: PeriodFilter.year, label: 'Year'),
          ],
          onChanged: (PeriodFilter? val) {
            if (val != null) _onPeriodChanged(val);
          },
          height: 38,
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          backgroundColor: AppColors.surface,
          dropdownColor: AppColors.surfaceElevated,
          isDefault: false,
        ),
        const SizedBox(width: 10),

        // 2. Analysis Type Capsule Tab Bar (Right) - Net, Transferred, Deposit
        Expanded(
          child: AppCapsuleTabBar(
            tabs: const ['Net', 'Transferred', 'Deposit'],
            selectedIndex: analysisTypeIndex,
            onTabChanged: (index) {
              final newType = switch (index) {
                1 => 'Expenses',
                2 => 'Income',
                _ => 'All',
              };
              if (_selectedAnalysisType == newType) return;
              _changeFilter(() {
                _selectedAnalysisType = newType;
              });
            },
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
        color: AppColors.surface,
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

  // ── 4. Standalone Segmented Morphing Distribution Bar ──────────────────────
  Widget _buildStandaloneSegmentedBar(
    List<CategoryArcItem> targetCategories,
    double targetTotal,
  ) {
    return AnimatedBuilder(
      animation: _morphAnim,
      builder: (context, child) {
        final progress = _morphAnim.value;

        return Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;

              return GestureDetector(
                onTapUp: (details) {
                  if (targetCategories.isEmpty) return;
                  final tapX = details.localPosition.dx.clamp(0.0, barWidth);

                  final totalAmt = targetCategories.fold<double>(
                      0.0, (s, c) => s + c.amount);
                  if (totalAmt <= 0) return;

                  const double inset = 3.5;
                  const double gap = 3.5;
                  final double usableWidth = max(0.0, barWidth - (inset * 2));
                  final int validCount =
                      targetCategories.where((s) => s.amount > 0.0001).length;
                  final double totalGaps =
                      validCount > 1 ? (validCount - 1) * gap : 0.0;
                  final double availableWidth =
                      max(0.0, usableWidth - totalGaps);

                  double cumX = inset;
                  int clickedIndex = -1;
                  for (int i = 0; i < targetCategories.length; i++) {
                    if (targetCategories[i].amount <= 0.0001) continue;
                    final segW = (targetCategories[i].amount / totalAmt) *
                        availableWidth;
                    if (tapX >= cumX && tapX <= cumX + segW + gap) {
                      clickedIndex = i;
                      break;
                    }
                    cumX += segW + gap;
                  }

                  setState(() {
                    _selectedArcIndex = (clickedIndex == _selectedArcIndex)
                        ? null
                        : clickedIndex;
                  });
                },
                child: CustomPaint(
                  size: Size(barWidth, 48),
                  painter: MorphingSegmentedBarPainter(
                    oldItems: _previousCategories,
                    newItems: targetCategories,
                    oldTotal: _previousTotal,
                    newTotal: targetTotal,
                    progress: progress,
                    selectedIndex: _selectedArcIndex,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── 5. Category Breakdown & Go Deeper Card ────────────────────────────────
  Widget _buildCategoryBreakdownCard(
    List<CategoryArcItem> targetCategories,
    double targetTotal,
    double netPnl,
    bool isBalanceVisible,
  ) {
    return AnimatedBuilder(
      animation: _morphAnim,
      builder: (context, child) {
        final progress = _morphAnim.value;
        final currentTotal =
            _previousTotal + (targetTotal - _previousTotal) * progress;

        final isCategorySelected = _selectedArcIndex != null &&
            _selectedArcIndex! < targetCategories.length;
        final selectedItem =
            isCategorySelected ? targetCategories[_selectedArcIndex!] : null;

        final displayTotal =
            selectedItem != null ? selectedItem.amount : currentTotal;
        final displayLabel = selectedItem != null
            ? selectedItem.label
            : (_drilledCategory != null
                ? _drilledCategory!.name
                : '${_getAnalysisTypeLabel(_selectedAnalysisType).toUpperCase()} BREAKDOWN');

        final double selectedPct = (targetTotal > 0 && selectedItem != null)
            ? (selectedItem.amount / targetTotal) * 100
            : 100.0;

        final fmt = NumberFormat('#,##0.00');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header / Hero Row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Side: Back button (if drilled) OR selected item / title
                  if (_drilledCategory != null) ...[
                    AppButton.secondary(
                      text: '← Top Categories',
                      height: 28,
                      fontSize: 10.5,
                      fullWidth: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onPressed: () {
                        _changeFilter(() {
                          _drilledCategory = null;
                          _selectedArcIndex = null;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (selectedItem != null) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: selectedItem.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Flexible(
                              child: Text(
                                displayLabel,
                                style: TextStyle(
                                  color: selectedItem != null
                                      ? selectedItem.color
                                      : AppColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selectedItem != null) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: selectedItem.color
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  '${selectedPct.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: selectedItem.color,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        isBalanceVisible
                            ? CurrencyTextWidget(
                                amount: displayTotal,
                                customFormattedStr: fmt.format(displayTotal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                                iconSize: 14,
                              )
                            : const Text(
                                '****',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                      ],
                    ),
                  ),

                  // Right Side: Go Deeper Button or Clear Selection
                  if (selectedItem != null) ...[
                    if (_drilledCategory == null)
                      Builder(
                        builder: (ctx) {
                          final provider =
                              Provider.of<FinanceProvider>(ctx, listen: false);
                          final labelLower = selectedItem.label.toLowerCase();

                          final isSpecial = ['loan', 'bounce', 'internal transfer', 'cash', 'uncategorized']
                                  .contains(labelLower) ||
                              provider.specialReasons.any(
                                  (r) => r.name.toLowerCase() == labelLower);

                          if (isSpecial) return const SizedBox.shrink();

                          final foundReason =
                              provider.topLevelCategories.firstWhere(
                            (r) => r.name.toLowerCase() == labelLower,
                            orElse: () => AppReason(name: selectedItem.label),
                          );

                          final hasSubcategories = foundReason.id != null &&
                              provider
                                  .subcategoriesFor(foundReason.id!)
                                  .isNotEmpty;

                          return AppButton.primary(
                            text: 'Go Deeper',
                            trailingIcon: Icons.chevron_right_rounded,
                            height: 28,
                            fontSize: 10.5,
                            iconSize: 13,
                            fullWidth: false,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            onPressed: () {
                              if (!hasSubcategories) {
                                AppToast.warning(
                                  ctx,
                                  message: 'No subcategories found for this category',
                                );
                                return;
                              }
                              _changeFilter(() {
                                _drilledCategory = foundReason;
                                _selectedArcIndex = null;
                              });
                            },
                          );
                        },
                      ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => _selectedArcIndex = null),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.buttonSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // ── 2-Column Breakdown List (Hugs Content Naturally) ──
              if (targetCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  child: const Text(
                    'No transactions recorded for this period',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < targetCategories.length; i += 2) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildBreakdownTile(
                              item: targetCategories[i],
                              index: i,
                              targetTotal: targetTotal,
                              isBalanceVisible: isBalanceVisible,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (i + 1 < targetCategories.length)
                            Expanded(
                              child: _buildBreakdownTile(
                                item: targetCategories[i + 1],
                                index: i + 1,
                                targetTotal: targetTotal,
                                isBalanceVisible: isBalanceVisible,
                              ),
                            )
                          else
                            const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                    ],
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBreakdownTile({
    required CategoryArcItem item,
    required int index,
    required double targetTotal,
    required bool isBalanceVisible,
  }) {
    final isSelected = _selectedArcIndex == index;
    final double pct =
        targetTotal > 0 ? (item.amount / targetTotal) * 100 : 0.0;
    final String pctStr = pct.toStringAsFixed(1);
    final String numStr = NumberFormat('#,##0.00').format(item.amount);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedArcIndex =
                (_selectedArcIndex == index) ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Vertical Line Indicator
              Container(
                width: 3.0,
                height: 20,
                decoration: BoxDecoration(
                  color: item.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              // Name and Amount (NO currency symbol)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSoft,
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isBalanceVisible ? numStr : '****',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Percentage Pill Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? item.color.withValues(alpha: 0.25)
                      : AppColors.buttonSecondary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$pctStr %',
                  style: TextStyle(
                    color:
                        isSelected ? Colors.white : AppColors.textSoft,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 6. Redesigned Reason Analysis Section ──────────────────────────────────
  String _getPeriodSubtitle() {
    final subItems = _getSubPeriodItems();
    final int subIndex =
        _selectedSubPeriodIndex.clamp(0, max(0, subItems.length - 1)).toInt();
    if (subIndex >= 0 && subIndex < subItems.length) {
      return subItems[subIndex];
    }
    return '';
  }

  Widget _buildReasonBreakdownSection(
    List<AppTransaction> filteredBankTxs,
    List<CashTransaction> filteredCashTxs,
    FinanceProvider provider,
  ) {
    // ── Group transactions by Top-Level Category ──────────────────────────────
    final Map<String, _CategoryDataAccumulator> categoryMap = {};

    void processBankTx(AppTransaction tx) {
      String? categoryName;
      AppReason? categoryReason;
      String? subName;
      AppReason? subReason;

      if (tx.categoryId != null) {
        final cat = provider.reasons
            .where((r) => r.id == tx.categoryId)
            .firstOrNull;
        if (cat != null) {
          categoryName = cat.name;
          categoryReason = cat;
        }
      }

      if (categoryName == null && tx.reasonId != null) {
        final r = provider.reasons
            .where((r) => r.id == tx.reasonId)
            .firstOrNull;
        if (r != null) {
          if (r.isSubcategory && r.parentId != null) {
            final p = provider.reasons
                .where((pr) => pr.id == r.parentId)
                .firstOrNull;
            if (p != null) {
              categoryName = p.name;
              categoryReason = p;
              subName = r.name;
              subReason = r;
            }
          } else {
            categoryName = r.name;
            categoryReason = r;
          }
        }
      }

      if (categoryName == null) {
        final raw =
            (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '').trim();
        if (raw.isNotEmpty) {
          final matchedReason = provider.reasons
              .where((r) => r.name.toLowerCase() == raw.toLowerCase())
              .firstOrNull;
          if (matchedReason != null) {
            if (matchedReason.isSubcategory && matchedReason.parentId != null) {
              final p = provider.reasons
                  .where((pr) => pr.id == matchedReason.parentId)
                  .firstOrNull;
              if (p != null) {
                categoryName = p.name;
                categoryReason = p;
                subName = matchedReason.name;
                subReason = matchedReason;
              }
            } else {
              categoryName = matchedReason.name;
              categoryReason = matchedReason;
            }
          } else {
            categoryName = _normalizeCategoryName(raw);
            if (raw.toLowerCase() != categoryName.toLowerCase()) {
              subName = raw;
            }
          }
        } else {
          categoryName = 'Uncategorized';
        }
      }

      final normalizedCat = categoryName ?? 'Uncategorized';
      final acc = categoryMap.putIfAbsent(
        normalizedCat,
        () => _CategoryDataAccumulator(
          categoryName: normalizedCat,
          categoryReason: categoryReason,
        ),
      );

      acc.allBankTxs.add(tx);

      if (subName != null &&
          subName.trim().isNotEmpty &&
          subName.trim().toLowerCase() != normalizedCat.toLowerCase() &&
          subName.trim().toLowerCase() != 'general') {
        final sub = subName;
        final subAcc = acc.subcategories.putIfAbsent(
          sub,
          () => _SubcategoryDataAccumulator(
            name: sub,
            reason: subReason,
          ),
        );
        subAcc.bankTxs.add(tx);
      } else {
        acc.directBankTxs.add(tx);
      }
    }

    void processCashTx(CashTransaction ctx) {
      final raw = (ctx.reasonName ?? ctx.description ?? 'Other Cash').trim();
      String? categoryName;
      AppReason? categoryReason;
      String? subName;
      AppReason? subReason;

      final matchedReason = provider.reasons
          .where((r) => r.name.toLowerCase() == raw.toLowerCase())
          .firstOrNull;
      if (matchedReason != null) {
        if (matchedReason.isSubcategory && matchedReason.parentId != null) {
          final p = provider.reasons
              .where((pr) => pr.id == matchedReason.parentId)
              .firstOrNull;
          if (p != null) {
            categoryName = p.name;
            categoryReason = p;
            subName = matchedReason.name;
            subReason = matchedReason;
          }
        } else {
          categoryName = matchedReason.name;
          categoryReason = matchedReason;
        }
      } else {
        categoryName = _normalizeCategoryName(raw);
        if (raw.toLowerCase() != categoryName.toLowerCase()) {
          subName = raw;
        }
      }

      final normalizedCat = categoryName ?? 'Other Cash';
      final acc = categoryMap.putIfAbsent(
        normalizedCat,
        () => _CategoryDataAccumulator(
          categoryName: normalizedCat,
          categoryReason: categoryReason,
        ),
      );

      acc.allCashTxs.add(ctx);

      if (subName != null &&
          subName.trim().isNotEmpty &&
          subName.trim().toLowerCase() != normalizedCat.toLowerCase() &&
          subName.trim().toLowerCase() != 'general') {
        final sub = subName;
        final subAcc = acc.subcategories.putIfAbsent(
          sub,
          () => _SubcategoryDataAccumulator(
            name: sub,
            reason: subReason,
          ),
        );
        subAcc.cashTxs.add(ctx);
      } else {
        acc.directCashTxs.add(ctx);
      }
    }

    if (_selectedAnalysisType == 'Income') {
      for (var t in filteredBankTxs.where((t) => t.type == 'income')) {
        processBankTx(t);
      }
      for (var ctx in filteredCashTxs.where((t) => t.type == 'addition')) {
        processCashTx(ctx);
      }
    } else {
      for (var t in filteredBankTxs.where((t) =>
          t.type == 'expense' &&
          t.reason?.toLowerCase() != 'cash' &&
          t.customReasonText?.toLowerCase() != 'cash' &&
          t.resolvedReason?.toLowerCase() != 'cash')) {
        processBankTx(t);
      }
      for (var ctx in filteredCashTxs.where((t) => t.type == 'expense')) {
        processCashTx(ctx);
      }
    }

    if (categoryMap.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_outlined, color: Colors.white38, size: 18),
              SizedBox(width: 8),
              Text(
                'No transaction categories recorded for this period',
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

    // Convert accumulator map to sorted list
    final categoryList = categoryMap.values.map((acc) {
      final subList = acc.subcategories.values.map((sAcc) {
        double sTotal = 0.0;
        for (final t in sAcc.bankTxs) {
          sTotal += t.amount;
        }
        for (final ct in sAcc.cashTxs) {
          sTotal += ct.amount;
        }
        return SubcategoryAnalysisItem(
          name: sAcc.name,
          reason: sAcc.reason,
          totalAmount: sTotal,
          bankTransactions: sAcc.bankTxs,
          cashTransactions: sAcc.cashTxs,
        );
      }).where((s) => s.totalCount > 0).toList()
        ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

      double catTotal = 0.0;
      for (final t in acc.allBankTxs) {
        catTotal += t.amount;
      }
      for (final ct in acc.allCashTxs) {
        catTotal += ct.amount;
      }

      return (
        categoryName: acc.categoryName,
        categoryReason: acc.categoryReason,
        color: _getReasonColor(acc.categoryName),
        totalAmount: catTotal,
        allBankTxs: acc.allBankTxs,
        allCashTxs: acc.allCashTxs,
        directBankTxs: acc.directBankTxs,
        directCashTxs: acc.directCashTxs,
        subcategories: subList,
        totalTxCount: acc.allBankTxs.length + acc.allCashTxs.length,
      );
    }).where((c) => c.totalTxCount > 0).toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final totalSum = categoryList.fold<double>(0, (s, e) => s + e.totalAmount);
    final fmt = NumberFormat('#,##0.00');
    final periodSubtitle = _getPeriodSubtitle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Category Analysis',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              '${categoryList.length} ${categoryList.length == 1 ? 'Category' : 'Categories'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        ...categoryList.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final pct = totalSum > 0 ? cat.totalAmount / totalSum : 0.0;
          final color = cat.color;
          final hasSubcategories = cat.subcategories.isNotEmpty;

          String subtitleText;
          if (hasSubcategories) {
            final subCount = cat.subcategories.length;
            subtitleText =
                '$subCount ${subCount == 1 ? 'subcategory' : 'subcategories'} • ${cat.totalTxCount} ${cat.totalTxCount == 1 ? 'transaction' : 'transactions'}';
          } else {
            subtitleText =
                '${cat.totalTxCount} ${cat.totalTxCount == 1 ? 'transaction' : 'transactions'}';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (hasSubcategories) {
                    // Scenario 1: Category HAS subcategories -> Open CategoryDetailScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailScreen(
                          categoryName: cat.categoryName,
                          categoryReason: cat.categoryReason,
                          categoryColor: color,
                          totalAmount: cat.totalAmount,
                          periodLabel: periodSubtitle,
                          directBankTransactions: cat.directBankTxs,
                          directCashTransactions: cat.directCashTxs,
                          allBankTransactions: cat.allBankTxs,
                          allCashTransactions: cat.allCashTxs,
                          subcategories: cat.subcategories,
                        ),
                      ),
                    );
                  } else {
                    // Scenario 2: Category has NO subcategories -> Go straight to ReasonTransactionsScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReasonTransactionsScreen(
                          title: cat.categoryName,
                          reason: cat.categoryReason,
                          periodSubtitle: periodSubtitle,
                          transactions: cat.allBankTxs,
                          cashTransactions: cat.allCashTxs,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
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
                                    cat.categoryName,
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
                                        amount: cat.totalAmount,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        customFormattedStr:
                                            fmt.format(cat.totalAmount),
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
                            const SizedBox(height: 2),
                            Text(
                              subtitleText,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CustomProgressBar(
                              progress: pct,
                              height: 10,
                              progressColor: color,
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
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 14),

        // High-contrast, clean monochrome performance cards
        Column(
          children: bankBreakdown.map((bank) {
            final isPositive = bank.net >= 0;
            final maxVolume = max(bank.income, bank.expense);
            final ratio = maxVolume > 0 ? (bank.expense / maxVolume).clamp(0.1, 1.0) : 0.5;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Official Bank Logo / Icon
                      BankCardWidget.bankLogo(bank.name, 22, AppColors.textPrimary),
                      const SizedBox(width: 10),
                      Text(
                        bank.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
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
                          : const Text(
                              '****',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  CustomProgressBar(
                    progress: ratio,
                    height: 10,
                    progressColor:
                        isPositive ? AppColors.positive : AppColors.negative,
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

class MorphingSegmentedBarPainter extends CustomPainter {
  final List<CategoryArcItem> oldItems;
  final List<CategoryArcItem> newItems;
  final double oldTotal;
  final double newTotal;
  final double progress; // 0.0 to 1.0 morphing animation value
  final int? selectedIndex;

  MorphingSegmentedBarPainter({
    required this.oldItems,
    required this.newItems,
    required this.oldTotal,
    required this.newTotal,
    required this.progress,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, CategoryArcItem> oldMap = {
      for (var item in oldItems) item.label: item
    };
    final Map<String, CategoryArcItem> newMap = {
      for (var item in newItems) item.label: item
    };
    final Set<String> allLabels = {...oldMap.keys, ...newMap.keys};

    final List<({String label, double amount, Color color, double weight})>
        activeSegments = [];
    double totalInterpolatedAmount = 0.0;

    for (final label in allLabels) {
      final oldItem = oldMap[label];
      final newItem = newMap[label];

      final oldAmt = oldItem?.amount ?? 0.0;
      final newAmt = newItem?.amount ?? 0.0;

      final oldW = oldAmt > 0 ? 1.0 : 0.0;
      final newW = newAmt > 0 ? 1.0 : 0.0;

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
      }
    }

    // Outer container background (rounded capsule track)
    const double barCornerRadius = 14.0;
    final trackRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(barCornerRadius),
    );

    final bgPaint = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, bgPaint);

    if (totalInterpolatedAmount <= 0 || activeSegments.isEmpty) {
      return;
    }

    // Clip to track capsule
    canvas.save();
    canvas.clipRRect(trackRRect);

    // Padding inside the track so segments sit cleanly inside
    const double inset = 3.5;
    const double gap = 3.5;
    final double usableWidth = max(0.0, size.width - (inset * 2));
    final double usableHeight = max(0.0, size.height - (inset * 2));

    final int validCount =
        activeSegments.where((s) => s.amount > 0.0001).length;
    final double totalGaps = validCount > 1 ? (validCount - 1) * gap : 0.0;
    final double availableWidth = max(0.0, usableWidth - totalGaps);

    double currentX = inset;

    for (int i = 0; i < activeSegments.length; i++) {
      final item = activeSegments[i];
      if (item.amount <= 0.0001 && item.weight <= 0.0001) continue;

      final double segWidth =
          (item.amount / totalInterpolatedAmount) * availableWidth;
      if (segWidth <= 0.001) continue;

      final isSelected = selectedIndex == i;
      final isAnySelected = selectedIndex != null;

      final segPaint = Paint()
        ..color = isSelected
            ? item.color
            : (isAnySelected
                ? item.color.withValues(alpha: 0.35)
                : item.color)
        ..style = PaintingStyle.fill;

      final segRect = Rect.fromLTWH(currentX, inset, segWidth, usableHeight);
      final segRRect = RRect.fromRectAndRadius(
        segRect,
        const Radius.circular(8),
      );

      canvas.drawRRect(segRRect, segPaint);

      currentX += segWidth + gap;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MorphingSegmentedBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.oldItems != oldItems ||
        oldDelegate.newItems != newItems ||
        oldDelegate.oldTotal != oldTotal ||
        oldDelegate.newTotal != newTotal ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

class _CategoryDataAccumulator {
  final String categoryName;
  final AppReason? categoryReason;
  final List<AppTransaction> allBankTxs = [];
  final List<CashTransaction> allCashTxs = [];
  final List<AppTransaction> directBankTxs = [];
  final List<CashTransaction> directCashTxs = [];
  final Map<String, _SubcategoryDataAccumulator> subcategories = {};

  _CategoryDataAccumulator({
    required this.categoryName,
    this.categoryReason,
  });
}

class _SubcategoryDataAccumulator {
  final String name;
  final AppReason? reason;
  final List<AppTransaction> bankTxs = [];
  final List<CashTransaction> cashTxs = [];

  _SubcategoryDataAccumulator({
    required this.name,
    this.reason,
  });
}

