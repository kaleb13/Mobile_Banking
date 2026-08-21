import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../models/reason.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/daily_net_heatmap_widget.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/interactive_drag_handle.dart';
import 'category_detail_screen.dart';
import 'all_transactions_screen.dart';

// ─── Period Filter Enum ────────────────────────────────────────────────────────
enum PeriodFilter { day, week, month, quarter, year }

class AnalysisScreen extends StatefulWidget {
  final String? initialBankFilter;

  const AnalysisScreen({super.key, this.initialBankFilter});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with TickerProviderStateMixin {
  late String _selectedBank;
  String? _selectedCounterparty;
  bool _isFilterExpanded = false;
  bool _isBankPerformanceExpanded = false;
  bool _isPersonContactExpanded = false;
  bool _isCategoryAnalysisExpanded = false;
  bool _isNetBreakdownExpanded = false;
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
  dynamic _cachedAnalyticsData;
  String _lastAnalyticsCacheKey = '';

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
    _selectedBank = _normalizeBankName(widget.initialBankFilter ?? 'All Wallets');
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

  String _normalizeBankName(String raw) {
    final up = raw.toUpperCase();
    if (up.contains('TELEBIRR')) return 'Telebirr';
    if (up.contains('CBE BIRR') || up.contains('CBEBIRR')) return 'CBE Birr';
    if (up == 'CBE' || up.contains('COMMERCIAL BANK')) return 'CBE';
    if (up.contains('AHADU')) return 'Ahadu';
    if (up.contains('DASHEN')) return 'Dashen';
    if (up.contains('BOA') || up.contains('ABYSSINIA')) return 'BOA';
    if (up.contains('CASH')) return 'Cash Wallet';
    if (up == 'ALL' || up == 'ALL BANKS' || up == 'ALL WALLETS') return 'All Wallets';
    return raw.trim();
  }

  bool _matchesBank(AppTransaction tx, String bank) {
    if (bank == 'All' || bank == 'All Banks' || bank == 'All Wallets') return true;
    final bUp = bank.toUpperCase();
    final tNameUp = tx.name.toUpperCase();
    final tSenderUp = tx.sender.toUpperCase();

    if (bUp.contains('TELEBIRR')) {
      return tNameUp.contains('TELEBIRR') || tSenderUp.contains('TELEBIRR');
    } else if (bUp == 'CBE BIRR' || bUp == 'CBEBIRR') {
      return tNameUp.contains('CBE BIRR') ||
          tNameUp.contains('CBEBIRR') ||
          tSenderUp.contains('CBE BIRR') ||
          tSenderUp.contains('CBEBIRR');
    } else if (bUp == 'CBE' || bUp.contains('COMMERCIAL BANK')) {
      return (tNameUp == 'CBE' ||
              tSenderUp == 'CBE' ||
              tNameUp.contains('COMMERCIAL BANK')) &&
          !tNameUp.contains('BIRR') &&
          !tSenderUp.contains('BIRR');
    } else if (bUp.contains('AHADU')) {
      return tNameUp.contains('AHADU') || tSenderUp.contains('AHADU');
    } else if (bUp.contains('DASHEN')) {
      return tNameUp.contains('DASHEN') || tSenderUp.contains('DASHEN');
    } else if (bUp.contains('BOA') || bUp.contains('ABYSSINIA')) {
      return tNameUp.contains('BOA') ||
          tSenderUp.contains('BOA') ||
          tNameUp.contains('ABYSSINIA') ||
          tSenderUp.contains('ABYSSINIA');
    }
    return tNameUp.contains(bUp) || tSenderUp.contains(bUp);
  }

  List<String> _getAvailableBanks(FinanceProvider provider) {
    final List<String> result = ['All Wallets'];
    final Set<String> seen = {'All Wallets'};

    for (final s in provider.senders) {
      final name = _normalizeBankName(s.senderName);
      if (name.isNotEmpty && seen.add(name)) {
        result.add(name);
      }
    }
    for (final tx in provider.transactions) {
      final name = _normalizeBankName(tx.name.isNotEmpty ? tx.name : tx.sender);
      if (name.isNotEmpty && seen.add(name)) {
        result.add(name);
      }
    }
    if (provider.cashTransactions.isNotEmpty && seen.add('Cash Wallet')) {
      result.add('Cash Wallet');
    }
    return result;
  }

  @override
  void dispose() {
    _morphCtrl.dispose();
    _fadeCtrl.dispose();
    _subPeriodScrollController.dispose();
    super.dispose();
  }

  List<({String label, String shortLabel})> _getSubPeriodItemsFormatted() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case PeriodFilter.day:
        final DateFormat dayFmt = DateFormat('E, MMM d');
        final DateFormat shortFmt = DateFormat('MMM d');
        return List.generate(14, (i) {
          final d = now.subtract(Duration(days: 13 - i));
          if (d.year == now.year && d.month == now.month && d.day == now.day) {
            return (label: 'Today', shortLabel: 'Today');
          }
          final yesterday = now.subtract(const Duration(days: 1));
          if (d.year == yesterday.year &&
              d.month == yesterday.month &&
              d.day == yesterday.day) {
            return (label: 'Yesterday', shortLabel: 'Yesterday');
          }
          return (label: dayFmt.format(d), shortLabel: shortFmt.format(d));
        });
      case PeriodFilter.week:
        return [
          (label: '4 Wks Ago', shortLabel: '4 Wks Ago'),
          (label: '3 Wks Ago', shortLabel: '3 Wks Ago'),
          (label: '2 Wks Ago', shortLabel: '2 Wks Ago'),
          (label: 'Last Week', shortLabel: 'Last Week'),
          (label: 'This Week', shortLabel: 'This Week'),
        ];
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
        const shortMonths = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return List.generate(now.month, (i) {
          return (label: allMonths[i], shortLabel: shortMonths[i]);
        });
      case PeriodFilter.quarter:
        return [
          (label: 'Q1 (Jan - Mar)', shortLabel: 'Q1'),
          (label: 'Q2 (Apr - Jun)', shortLabel: 'Q2'),
          (label: 'Q3 (Jul - Sep)', shortLabel: 'Q3'),
          (label: 'Q4 (Oct - Dec)', shortLabel: 'Q4'),
        ];
      case PeriodFilter.year:
        return [
          (
            label: (now.year - 2).toString(),
            shortLabel: (now.year - 2).toString()
          ),
          (
            label: (now.year - 1).toString(),
            shortLabel: (now.year - 1).toString()
          ),
          (label: now.year.toString(), shortLabel: now.year.toString()),
        ];
    }
  }

  Widget _buildSubPeriodSelector() {
    final items = _getSubPeriodItemsFormatted();
    if (items.isEmpty) return const SizedBox.shrink();

    final safeIndex = _selectedSubPeriodIndex.clamp(0, items.length - 1);

    return AppSecondaryTabBar(
      tabs: items.map((item) => item.label).toList(),
      selectedIndex: safeIndex,
      isScrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTabChanged: (index) {
        final isSelected = index == safeIndex;
        final defaultIdx = _getDefaultSubPeriodIndex(_selectedPeriod);
        final targetIdx =
            (isSelected && index != defaultIdx) ? defaultIdx : index;
        _onSubPeriodChanged(index);
        if (_subPeriodScrollController.hasClients) {
          _subPeriodScrollController.jumpToPage(targetIdx);
        }
      },
    );
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
          if (d.year == yesterday.year &&
              d.month == yesterday.month &&
              d.day == yesterday.day) {
            return 'Yesterday';
          }
          return dayFmt.format(d);
        });
      case PeriodFilter.week:
        return [
          '4 Wks Ago',
          '3 Wks Ago',
          '2 Wks Ago',
          'Last Week',
          'This Week'
        ];
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
        return [
          'Q1 (Jan-Mar)',
          'Q2 (Apr-Jun)',
          'Q3 (Jul-Sep)',
          'Q4 (Oct-Dec)'
        ];
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
    HapticFeedback.selectionClick();
    final defaultIndex = _getDefaultSubPeriodIndex(_selectedPeriod);
    _changeFilter(() {
      if (_selectedSubPeriodIndex == index && index != defaultIndex) {
        // Toggle off: revert back to current / default sub-period
        _selectedSubPeriodIndex = defaultIndex;
      } else {
        _selectedSubPeriodIndex = index;
      }
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

    final isCashOnly = _selectedBank == 'Cash Wallet';
    final isAll = _selectedBank == 'All Wallets' ||
        _selectedBank == 'All Banks' ||
        _selectedBank == 'All';

    if (!isCashOnly) {
      for (var tx in provider.transactions) {
        final reasonStr = (tx.reason ??
                tx.customReasonText ??
                tx.resolvedReason ??
                '')
            .trim()
            .toLowerCase();
        if (reasonStr == 'bounce' ||
            reasonStr == 'internal transfer' ||
            reasonStr == 'cash') {
          continue;
        }
        if (_matchesFilter(tx.date, now, year) && _matchesBank(tx, _selectedBank)) {
          filteredBankTxs.add(tx);
        }
      }
    }

    if (isAll || isCashOnly) {
      for (var tx in provider.cashTransactions) {
        if (_matchesFilter(tx.date, now, year)) {
          filteredCashTxs.add(tx);
        }
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
      'Dashen': (inVal: 0.0, outVal: 0.0),
      'BOA': (inVal: 0.0, outVal: 0.0),
      'Cash Wallet': (inVal: 0.0, outVal: 0.0),
    };

    for (var tx in filteredBankTxs) {
      final nameUpper = tx.name.toUpperCase();
      final senderUpper = tx.sender.toUpperCase();
      String key = 'CBE';
      if (nameUpper.contains('TELEBIRR') || senderUpper.contains('TELEBIRR')) {
        key = 'Telebirr';
      } else if (nameUpper.contains('CBE BIRR') ||
          nameUpper.contains('CBEBIRR') ||
          senderUpper.contains('CBE BIRR') ||
          senderUpper.contains('CBEBIRR')) {
        key = 'CBE Birr';
      } else if (nameUpper.contains('AHADU') || senderUpper.contains('AHADU')) {
        key = 'Ahadu';
      } else if (nameUpper.contains('DASHEN') || senderUpper.contains('DASHEN')) {
        key = 'Dashen';
      } else if (nameUpper.contains('BOA') ||
          nameUpper.contains('ABYSSINIA') ||
          senderUpper.contains('BOA') ||
          senderUpper.contains('ABYSSINIA')) {
        key = 'BOA';
      }

      final curr = bankMap[key] ?? (inVal: 0.0, outVal: 0.0);
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

    final bankBreakdown = bankMap.entries
        .where((e) => e.value.inVal > 0 || e.value.outVal > 0)
        .map((e) {
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

  dynamic _getCachedFilteredAnalyticsData(FinanceProvider provider) {
    final key = '${provider.transactions.length}_${provider.cashTransactions.length}_${_selectedPeriod.index}_${_selectedSubPeriodIndex}_${_selectedHeatmapDay?.millisecondsSinceEpoch}_${_selectedAnalysisType}_${_drilledCategory?.id}_$_selectedBank';
    if (_cachedAnalyticsData != null && _lastAnalyticsCacheKey == key) {
      return _cachedAnalyticsData;
    }
    _cachedAnalyticsData = _getFilteredAnalyticsData(provider);
    _lastAnalyticsCacheKey = key;
    return _cachedAnalyticsData;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final data = _getCachedFilteredAnalyticsData(provider);

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
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top Header & Filters Surface Section with Overscroll Stretch ──
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Upward extension filling the pull-down overscroll region seamlessly
                      Positioned(
                        top: -1000,
                        left: 0,
                        right: 0,
                        bottom: 28,
                        child: Container(
                          color: AppColors.surface,
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(28),
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header title & filter action button
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                child: AppHeader(
                                  title: _selectedBank != 'All Wallets' &&
                                          _selectedBank != 'All Banks' &&
                                          _selectedBank != 'All'
                                      ? '$_selectedBank Analytics'
                                      : 'Spending Charts',
                                  showBackButton: Navigator.canPop(context),
                                  padding: EdgeInsets.zero,
                                  trailing: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _isFilterExpanded = !_isFilterExpanded;
                                      });
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _isFilterExpanded
                                            ? AppColors.buttonPrimary
                                            : AppColors.heatmapNeutral,
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.filter_list_rounded,
                                          color: _isFilterExpanded
                                              ? AppColors.buttonPrimaryText
                                              : AppColors.textSoft,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Expandable dropdown filter pills
                              _buildDropdownFiltersSection(provider),
                              const SizedBox(height: 12),

                              // Reacting Sub-Period Filter Selector
                              _buildSubPeriodSelector(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 2. Daily Net Calendar Heatmap Card Section (Edge-to-Edge) ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DailyNetHeatmapWidget(
                          bankTransactions: data.filteredBankTxs,
                          cashTransactions: data.filteredCashTxs,
                          periodType:
                              HeatmapPeriodType.values[_selectedPeriod.index],
                          selectedDate: _getSynchronizedTargetDate(),
                          highlightedWeekRange: _getSynchronizedWeekRange(),
                          selectedQuarter: _selectedSubPeriodIndex.clamp(0, 3),
                          selectedYear: _selectedPeriod == PeriodFilter.year
                              ? (DateTime.now().year -
                                  (2 - _selectedSubPeriodIndex))
                              : DateTime.now().year,
                          selectedDay: _selectedHeatmapDay,
                          onDaySelected: (day) {
                            _changeFilter(() {
                              if (day != null &&
                                  _selectedPeriod == PeriodFilter.day) {
                                final now = DateTime.now();
                                final todayMidnight =
                                    DateTime(now.year, now.month, now.day);
                                final dayMidnight =
                                    DateTime(day.year, day.month, day.day);
                                final diff = todayMidnight
                                    .difference(dayMidnight)
                                    .inDays;
                                if (diff >= 0 && diff < 14) {
                                  _selectedSubPeriodIndex = 13 - diff;
                                  if (_subPeriodScrollController.hasClients) {
                                    _subPeriodScrollController
                                        .jumpToPage(_selectedSubPeriodIndex);
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
                                _subPeriodScrollController
                                    .jumpToPage(monthIndex);
                              }
                            });
                          },
                          isBalanceVisible: provider.isBalanceVisible,
                          userLevel: provider.userLevel,
                        ),
                        if (_selectedHeatmapDay != null) ...[
                          const SizedBox(height: 12),
                          _buildActiveDayFilterBanner(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 3. Prominent Inflow / Outflow & Net Cash Flow Summary Section ──
                  _buildRedesignedInflowOutflowNetSection(
                    data.totalIncome,
                    data.totalExpense,
                    data.netPnl,
                    provider.isBalanceVisible,
                    provider,
                  ),
                  const SizedBox(height: 14),

                  // ── 4. Unified White Net Breakdown & Distribution Card ──────────────
                  _buildUnifiedCategoryBreakdownCard(
                    data.categories,
                    data.chartTotal,
                    data.netPnl,
                    provider.isBalanceVisible,
                  ),
                  const SizedBox(height: 14),

                  // ── 6. Redesigned Category Analysis Card ──────────────────
                  _buildReasonBreakdownSection(
                    data.filteredBankTxs,
                    data.filteredCashTxs,
                    provider,
                  ),
                  const SizedBox(height: 14),

                  // ── 7. Person & Counterparty Analytics Section ────────────
                  _buildCounterpartyAnalyticsSection(
                    data.filteredBankTxs,
                    provider,
                  ),
                  const SizedBox(height: 14),

                  // ── 8. Redesigned Bank Performance Breakdown ──────────────
                  _buildRedesignedBankPerformance(
                    data.bankBreakdown,
                    data.filteredBankTxs,
                    data.filteredCashTxs,
                    provider.isBalanceVisible,
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Expandable Standardized Dropdown Filters Section ────────────────────
  Widget _buildDropdownFiltersSection(FinanceProvider provider) {
    final availableBanks = _getAvailableBanks(provider);
    final hasActiveFilters = (_selectedBank != 'All Wallets' &&
            _selectedBank != 'All Banks' &&
            _selectedBank != 'All') ||
        _selectedPeriod != PeriodFilter.month ||
        _selectedAnalysisType != 'All' ||
        _selectedSubPeriodIndex != _getDefaultSubPeriodIndex(_selectedPeriod);

    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 1. Period / Date Filter Dropdown (Day, Week, Month, Quarter, Year)
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
                isDefault: _selectedPeriod == PeriodFilter.month,
              ),
              const SizedBox(width: 8),

              // 3. Net / Transferred / Deposit Flow Filter
              AppDropdown<String>.dark(
                value: _selectedAnalysisType,
                items: const [
                  AppDropdownItem(value: 'All', label: 'Net'),
                  AppDropdownItem(value: 'Expenses', label: 'Transferred'),
                  AppDropdownItem(value: 'Income', label: 'Deposit'),
                ],
                onChanged: (String? val) {
                  if (val != null) {
                    _changeFilter(() {
                      _selectedAnalysisType = val;
                    });
                  }
                },
                isDefault: _selectedAnalysisType == 'All',
              ),
              const SizedBox(width: 8),

              // 4. Bank Filter Dropdown
              AppDropdown<String>.dark(
                value: _selectedBank,
                items: availableBanks.map((bank) {
                  return AppDropdownItem<String>(
                    value: bank,
                    label: bank,
                  );
                }).toList(),
                onChanged: (String? val) {
                  if (val != null && val != _selectedBank) {
                    HapticFeedback.selectionClick();
                    _changeFilter(() {
                      _selectedBank = val;
                      _drilledCategory = null;
                      _selectedCounterparty = null;
                    });
                  }
                },
                maxWidth: 140,
                isDefault: _selectedBank == 'All Wallets' || _selectedBank == 'All',
              ),

              // 5. Reset Filter Button
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                AppResetFilterButton(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _changeFilter(() {
                      _selectedBank = 'All Wallets';
                      _selectedPeriod = PeriodFilter.month;
                      _selectedSubPeriodIndex = _getDefaultSubPeriodIndex(PeriodFilter.month);
                      _selectedAnalysisType = 'All';
                      _selectedHeatmapDay = null;
                      _drilledCategory = null;
                      _selectedCounterparty = null;
                      if (_subPeriodScrollController.hasClients) {
                        _subPeriodScrollController.jumpToPage(_selectedSubPeriodIndex);
                      }
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      crossFadeState: _isFilterExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 250),
    );
  }

  String _getAnalysisTypeLabel(String type) {
    if (type == 'Expenses') return 'Transferred';
    if (type == 'Income') return 'Deposit';
    return 'Net';
  }

  Widget _buildActiveDayFilterBanner() {
    if (_selectedHeatmapDay == null) return const SizedBox.shrink();
    final fmtDate = DateFormat('EEEE, MMM d, yyyy').format(_selectedHeatmapDay!);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.heatmapNeutral,
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

  // ── 4. Dynamic Glass-Window Stacked Cards Net Cash Flow Hero Section ────────
  // ── 4. Branded Dark Emerald Ambient Gradient Net Cash Flow Section ────────
  Widget _buildRedesignedInflowOutflowNetSection(
    double totalIncome,
    double totalExpense,
    double netPnl,
    bool isBalanceVisible,
    FinanceProvider provider,
  ) {
    final fmt = NumberFormat('#,##0.00');
    final isPositiveNet = netPnl >= 0;

    // Construct sophisticated, executive-grade financial narrative
    String narrative;
    if (!isBalanceVisible) {
      narrative =
          'Net cash flow metrics across all monitored wallets remain secured in privacy mode. Tap balance toggle to inspect detailed liquidity.';
    } else if (totalIncome == 0 && totalExpense == 0) {
      narrative =
          'No transaction inflows or outflows recorded in this period. Real-time cash movement will dynamically update net liquidity.';
    } else if (isPositiveNet) {
      narrative =
          'Net surplus of +${fmt.format(netPnl)} ETB retained across active wallets, driven by +${fmt.format(totalIncome)} ETB in total deposits against -${fmt.format(totalExpense)} ETB in total outflows.';
    } else {
      narrative =
          'Net outflow deficit of -${fmt.format(netPnl.abs())} ETB recorded across active wallets, reflecting -${fmt.format(totalExpense)} ETB in total transfers against +${fmt.format(totalIncome)} ETB in deposited funds.';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const cardHeight = 180.0;

        return Container(
          height: cardHeight,
          width: totalW,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0C3025), // Deep emerald glow top-right
                Color(0xFF071F18), // Rich forest dark mid
                Color(0xFF0D151D), // Dark slate-charcoal bottom-left
              ],
              stops: [0.0, 0.45, 1.0],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              // ── Ambient Primary Brand Green Radial Glow (Top-Right Corner) ──
              Positioned(
                top: -70,
                right: -50,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.brandGreen.withValues(alpha: 0.38),
                        AppColors.brandGreen.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Subtle Secondary Glow at bottom left ──
              Positioned(
                bottom: -50,
                left: -40,
                width: 200,
                height: 200,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0E382C).withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Micro-Noise Frosted Grain Texture ──
              const Positioned.fill(
                child: CustomPaint(
                  painter: FrostedGlassNoisePainter(),
                ),
              ),

              // ── Centered Brand Content ──
              Positioned.fill(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.brandGreen.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'NET CASH FLOW',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        isBalanceVisible
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${isPositiveNet ? '+' : '-'}${fmt.format(netPnl.abs())}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 27,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                              )
                            : const Text(
                                '••••••••',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                ),
                              ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            narrative,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 10.5,
                              height: 1.35,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 4. Unified White Net Breakdown & Distribution Card ────────────────────
  Widget _buildUnifiedCategoryBreakdownCard(
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

        final double selectedPct = (targetTotal > 0 && selectedItem != null)
            ? (selectedItem.amount / targetTotal) * 100
            : 100.0;

        final fmt = NumberFormat('#,##0.00');

        final bool hasMoreThanSix = targetCategories.length > 6;
        final List<CategoryArcItem> visibleCategories = _isNetBreakdownExpanded
            ? targetCategories
            : targetCategories.take(6).toList();

        // Narrative text for the inner productivity-styled card
        String narrativeText;
        if (!isBalanceVisible) {
          narrativeText =
              'Category metrics and volume distribution remain masked in privacy mode.';
        } else if (targetCategories.isEmpty) {
          narrativeText =
              'No inflow or outflow transactions recorded for this selected time window.';
        } else if (selectedItem != null) {
          narrativeText =
              '${selectedItem.label} accounts for ${selectedPct.toStringAsFixed(1)}% (${fmt.format(selectedItem.amount)} ETB) of total ${_getAnalysisTypeLabel(_selectedAnalysisType).toLowerCase()} cash flow in this period.';
        } else {
          final topCategory = targetCategories.first;
          final topPct = targetTotal > 0
              ? (topCategory.amount / targetTotal * 100).toStringAsFixed(1)
              : '0.0';
          if (targetCategories.length >= 2) {
            final secondCategory = targetCategories[1];
            final combinedPct = targetTotal > 0
                ? ((topCategory.amount + secondCategory.amount) /
                        targetTotal *
                        100)
                    .toStringAsFixed(0)
                : '0';
            narrativeText =
                '${topCategory.label} and ${secondCategory.label} make up $combinedPct% of your active ${_getAnalysisTypeLabel(_selectedAnalysisType).toLowerCase()} distribution.';
          } else {
            narrativeText =
                '${topCategory.label} accounts for $topPct% of your active ${_getAnalysisTypeLabel(_selectedAnalysisType).toLowerCase()} distribution.';
          }
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.cardRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Top Interactive Drag / Expand Handle ──
                Center(
                  child: InteractiveDragHandle(
                    color: const Color(0xFFCBD5E1),
                    width: 36,
                    height: 4,
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    onTap: hasMoreThanSix
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isNetBreakdownExpanded =
                                  !_isNetBreakdownExpanded;
                            });
                          }
                        : null,
                  ),
                ),

                // ── 2. Top Reasons Grid Section (Inspired by Reference Design) ──
                if (targetCategories.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: const Text(
                      'No transactions recorded for this period',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else ...[
                  AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0;
                            i < visibleCategories.length;
                            i += 3) ...[
                          if (i > 0) const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _buildWhiteCategoryTile(
                                  item: visibleCategories[i],
                                  index: i,
                                  targetTotal: targetTotal,
                                  isBalanceVisible: isBalanceVisible,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (i + 1 < visibleCategories.length)
                                Expanded(
                                  child: _buildWhiteCategoryTile(
                                    item: visibleCategories[i + 1],
                                    index: i + 1,
                                    targetTotal: targetTotal,
                                    isBalanceVisible: isBalanceVisible,
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),
                              const SizedBox(width: 8),
                              if (i + 2 < visibleCategories.length)
                                Expanded(
                                  child: _buildWhiteCategoryTile(
                                    item: visibleCategories[i + 2],
                                    index: i + 2,
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
                  ),

                  // Expand / Collapse Action Text / Pill if > 6 categories
                  if (hasMoreThanSix) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _isNetBreakdownExpanded =
                                !_isNetBreakdownExpanded;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isNetBreakdownExpanded
                                    ? 'Show Less'
                                    : '+${targetCategories.length - 6} more categories',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _isNetBreakdownExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: const Color(0xFF64748B),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 14),

                // ── 3. Inner Slate Container (Segmented Bar & Narrative) ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Soft Slate 100
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Pill Header Row (✦ PRODUCTIVITY / NET BREAKDOWN Style)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(100),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
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
                                ] else ...[
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Color(0xFF0F172A),
                                    size: 11,
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  selectedItem != null
                                      ? selectedItem.label.toUpperCase()
                                      : (_drilledCategory != null
                                          ? _drilledCategory!.name.toUpperCase()
                                          : '${_getAnalysisTypeLabel(_selectedAnalysisType).toUpperCase()} DISTRIBUTION'),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Action items: Go Deeper button or Clear Selection button
                          if (selectedItem != null) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_drilledCategory == null)
                                  Builder(
                                    builder: (ctx) {
                                      final provider =
                                          Provider.of<FinanceProvider>(ctx,
                                              listen: false);
                                      final labelLower =
                                          selectedItem.label.toLowerCase();
                                      final isSpecial = [
                                        'loan',
                                        'bounce',
                                        'internal transfer',
                                        'cash',
                                        'uncategorized'
                                      ].contains(labelLower) ||
                                          provider.specialReasons.any((r) =>
                                              r.name.toLowerCase() ==
                                              labelLower);
                                      if (isSpecial) {
                                        return const SizedBox.shrink();
                                      }

                                      final foundReason = provider
                                          .topLevelCategories
                                          .firstWhere(
                                        (r) =>
                                            r.name.toLowerCase() == labelLower,
                                        orElse: () => AppReason(
                                            name: selectedItem.label),
                                      );
                                      final hasSubcategories =
                                          foundReason.id != null &&
                                              provider
                                                  .subcategoriesFor(
                                                      foundReason.id!)
                                                  .isNotEmpty;

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: AppButton.primary(
                                          text: 'Go Deeper',
                                          trailingIcon:
                                              Icons.chevron_right_rounded,
                                          height: 26,
                                          fontSize: 10,
                                          iconSize: 12,
                                          fullWidth: false,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 0),
                                          onPressed: () {
                                            if (!hasSubcategories) {
                                              AppToast.warning(
                                                ctx,
                                                message:
                                                    'No subcategories found for this category',
                                              );
                                              return;
                                            }
                                            _changeFilter(() {
                                              _drilledCategory = foundReason;
                                              _selectedArcIndex = null;
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _selectedArcIndex = null),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE2E8F0),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      color: Color(0xFF475569),
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (_drilledCategory != null) ...[
                            AppButton.primary(
                              text: 'Back',
                              icon: Icons.arrow_back_rounded,
                              height: 26,
                              fontSize: 10,
                              iconSize: 12,
                              fullWidth: false,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 0),
                              onPressed: () {
                                _changeFilter(() {
                                  _drilledCategory = null;
                                  _selectedArcIndex = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Segmented Bar inside the inner card
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final barWidth = constraints.maxWidth;
                          return GestureDetector(
                            onTapUp: (details) {
                              if (targetCategories.isEmpty) return;
                              final tapX = details.localPosition.dx
                                  .clamp(0.0, barWidth);
                              final totalAmt = targetCategories.fold<double>(
                                  0.0, (s, c) => s + c.amount);
                              if (totalAmt <= 0) return;

                              const double inset = 3.5;
                              const double gap = 3.5;
                              final double usableWidth =
                                  max(0.0, barWidth - (inset * 2));
                              final int validCount = targetCategories
                                  .where((s) => s.amount > 0.0001)
                                  .length;
                              final double totalGaps = validCount > 1
                                  ? (validCount - 1) * gap
                                  : 0.0;
                              final double availableWidth =
                                  max(0.0, usableWidth - totalGaps);

                              double cumX = inset;
                              int clickedIndex = -1;
                              for (int i = 0;
                                  i < targetCategories.length;
                                  i++) {
                                if (targetCategories[i].amount <= 0.0001) {
                                  continue;
                                }
                                final segW = (targetCategories[i].amount /
                                        totalAmt) *
                                    availableWidth;
                                if (tapX >= cumX &&
                                    tapX <= cumX + segW + gap) {
                                  clickedIndex = i;
                                  break;
                                }
                                cumX += segW + gap;
                              }

                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedArcIndex =
                                    (clickedIndex == _selectedArcIndex)
                                        ? null
                                        : clickedIndex;
                              });
                            },
                            child: CustomPaint(
                              size: Size(barWidth, 38),
                              painter: MorphingSegmentedBarPainter(
                                oldItems: _previousCategories,
                                newItems: targetCategories,
                                oldTotal: _previousTotal,
                                newTotal: targetTotal,
                                progress: progress,
                                selectedIndex: _selectedArcIndex,
                                trackColor: const Color(0xFFE2E8F0),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 10),

                      // Smart Financial Insight Text
                      Text(
                        narrativeText,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11.5,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatCompactAmount(double amt) {
    if (amt >= 1000000) {
      return '${(amt / 1000000).toStringAsFixed(1)}M';
    } else if (amt >= 100000) {
      return '${(amt / 1000).toStringAsFixed(0)}k';
    } else if (amt >= 1000) {
      return NumberFormat('#,##0').format(amt);
    } else {
      return NumberFormat('#,##0.00').format(amt);
    }
  }

  Widget _buildWhiteCategoryTile({
    required CategoryArcItem item,
    required int index,
    required double targetTotal,
    required bool isBalanceVisible,
  }) {
    final isSelected = _selectedArcIndex == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _selectedArcIndex = (_selectedArcIndex == index) ? null : index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? item.color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Row: Square Color Indicator + Bold Amount
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      isBalanceVisible
                          ? _formatCompactAmount(item.amount)
                          : '••••••••',
                      style: TextStyle(
                        color: isSelected
                            ? item.color
                            : const Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Subtitle: Category Label
              Text(
                item.label,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

    for (var t in filteredBankTxs) {
      if (t.reason?.toLowerCase() == 'cash' ||
          t.customReasonText?.toLowerCase() == 'cash' ||
          t.resolvedReason?.toLowerCase() == 'cash') {
        continue;
      }
      processBankTx(t);
    }
    for (var ctx in filteredCashTxs) {
      processCashTx(ctx);
    }

    if (categoryMap.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Analysis',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
            SizedBox(height: 14),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined,
                        color: AppColors.textDisabled, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'No transactions recorded for this period',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Convert accumulator map to sorted list
    final categoryList = categoryMap.values.map((acc) {
      final subList = acc.subcategories.values.map((sAcc) {
        double sExp = 0.0;
        double sInc = 0.0;

        for (final t in sAcc.bankTxs) {
          if (t.type == 'income') {
            sInc += t.amount;
          } else {
            sExp += t.amount;
          }
        }
        for (final ct in sAcc.cashTxs) {
          if (ct.type == 'addition' || ct.type == 'income') {
            sInc += ct.amount;
          } else {
            sExp += ct.amount;
          }
        }

        double sTotal = 0.0;
        if (_selectedAnalysisType == 'Income') {
          sTotal = sInc;
        } else if (_selectedAnalysisType == 'Expenses') {
          sTotal = sExp;
        } else {
          // 'All' mode: calculate net value (summing transactions and taking net difference)
          sTotal = (sExp - sInc).abs();
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

      double catExp = 0.0;
      double catInc = 0.0;

      for (final t in acc.allBankTxs) {
        if (t.type == 'income') {
          catInc += t.amount;
        } else {
          catExp += t.amount;
        }
      }
      for (final ct in acc.allCashTxs) {
        if (ct.type == 'addition' || ct.type == 'income') {
          catInc += ct.amount;
        } else {
          catExp += ct.amount;
        }
      }

      double catTotal = 0.0;
      if (_selectedAnalysisType == 'Income') {
        catTotal = catInc;
      } else if (_selectedAnalysisType == 'Expenses') {
        catTotal = catExp;
      } else {
        // 'All' mode: calculate net value for category
        catTotal = (catExp - catInc).abs();
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: Title, Badge, and Toggle Button ──
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isCategoryAnalysisExpanded = !_isCategoryAnalysisExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Category Analysis',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge.neutral(
                      text: '${categoryList.length}',
                      size: AppBadgeSize.micro,
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isCategoryAnalysisExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                for (int i = 0; i < categoryList.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final cat = categoryList[i];
                      final pct =
                          totalSum > 0 ? cat.totalAmount / totalSum : 0.0;
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

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
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
                            },
                            child: Row(
                              children: [
                                // Rank badge
                                Container(
                                  width: 32,
                                  height: 32,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cat.categoryName,
                                              style: const TextStyle(
                                                color: AppColors.textSoft,
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          provider.isBalanceVisible
                                              ? CurrencyTextWidget(
                                                  amount: cat.totalAmount,
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 13.5,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                  customFormattedStr:
                                                      fmt.format(cat.totalAmount),
                                                )
                                              : Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    CurrencySymbolWidget(
                                                      color: color,
                                                      size: 13.5,
                                                      fontWeight:
                                                        FontWeight.bold,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '••••••••',
                                                      style: TextStyle(
                                                        color: color,
                                                        fontSize: 13.5,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            color: Colors.white38,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitleText,
                                        style: const TextStyle(
                                          color: AppColors.textDisabled,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      CustomProgressBar(
                                        progress: pct,
                                        height: 8,
                                        progressColor: color,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _selectedAnalysisType == 'Income'
                                            ? '${(pct * 100).toStringAsFixed(1)}% of total received'
                                            : _selectedAnalysisType ==
                                                    'Expenses'
                                                ? '${(pct * 100).toStringAsFixed(1)}% of total spent'
                                                : '${(pct * 100).toStringAsFixed(1)}% of net total',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 9.5,
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
                      );
                    },
                  ),
                  if (i < categoryList.length - 1)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.05),
                      height: 1,
                    ),
                ],
              ],
            ),
            crossFadeState: _isCategoryAnalysisExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ── 8. Redesigned Bank Performance Breakdown Section ─────────────────────
  Widget _buildRedesignedBankPerformance(
    List<({String name, double income, double expense, double net})> bankBreakdown,
    List<AppTransaction> filteredBankTxs,
    List<CashTransaction> filteredCashTxs,
    bool isBalanceVisible,
  ) {
    final isBankSpecific = _selectedBank != 'All Wallets' &&
        _selectedBank != 'All Banks' &&
        _selectedBank != 'All';

    if (isBankSpecific) {
      return _buildSpecificBankInsights(
        filteredBankTxs,
        filteredCashTxs,
        isBalanceVisible,
      );
    }

    if (bankBreakdown.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat('#,##0.00');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: Title, Badge, and Toggle Button ──
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isBankPerformanceExpanded = !_isBankPerformanceExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Bank Performance',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge.neutral(
                      text: '${bankBreakdown.length}',
                      size: AppBadgeSize.micro,
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isBankPerformanceExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                for (int i = 0; i < bankBreakdown.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final bank = bankBreakdown[i];
                      final isPositive = bank.net >= 0;
                      final maxVolume = max(bank.income, bank.expense);
                      final ratio = maxVolume > 0 ? (bank.expense / maxVolume).clamp(0.1, 1.0) : 0.5;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // Official Bank Logo / Icon
                                BankCardWidget.bankLogo(bank.name, 22, AppColors.textSecondary),
                                const SizedBox(width: 10),
                                Text(
                                  bank.name,
                                  style: const TextStyle(
                                    color: AppColors.textSoft,
                                    fontSize: 13.5,
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
                                        '••••••••',
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
                    },
                  ),
                  if (i < bankBreakdown.length - 1)
                    Divider(
                      color: Colors.white.withValues(alpha: 0.05),
                      height: 1,
                    ),
                ],
              ],
            ),
            crossFadeState: _isBankPerformanceExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificBankInsights(
    List<AppTransaction> bankTxs,
    List<CashTransaction> cashTxs,
    bool isBalanceVisible,
  ) {
    final fmt = NumberFormat('#,##0.00');
    final totalCount = bankTxs.length + cashTxs.length;

    final incomeTxs = bankTxs.where((t) => t.type == 'income').toList();
    final expenseTxs = bankTxs.where((t) => t.type == 'expense').toList();

    final double maxExpense = expenseTxs.isEmpty
        ? 0.0
        : expenseTxs.map((t) => t.amount).reduce(max);
    final double maxIncome = incomeTxs.isEmpty
        ? 0.0
        : incomeTxs.map((t) => t.amount).reduce(max);

    final double totalExpense = expenseTxs.fold(0.0, (sum, t) => sum + t.amount);
    final double avgExpense =
        expenseTxs.isEmpty ? 0.0 : totalExpense / expenseTxs.length;

    // Find top counterparty for this bank
    final Map<String, int> partyCounts = {};
    for (var tx in bankTxs) {
      final s = tx.sender.trim();
      if (s.isNotEmpty) {
        partyCounts[s] = (partyCounts[s] ?? 0) + 1;
      }
    }
    String topParty = 'None';
    int topPartyCount = 0;
    partyCounts.forEach((k, v) {
      if (v > topPartyCount) {
        topParty = k;
        topPartyCount = v;
      }
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isBankPerformanceExpanded = !_isBankPerformanceExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '$_selectedBank Insights',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge.success(
                      text: '$totalCount tx',
                      size: AppBadgeSize.small,
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isBankPerformanceExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 16),
                // 2x2 Grid of Insight metrics
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.receipt_long_rounded,
                        iconColor: AppColors.positive,
                        title: 'Avg. Outflow',
                        value: isBalanceVisible
                            ? 'ETB ${fmt.format(avgExpense)}'
                            : 'ETB ••••••••',
                        subtitle: '${expenseTxs.length} outgoing txs',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.arrow_upward_rounded,
                        iconColor: AppColors.positive,
                        title: 'Peak Deposit',
                        value: isBalanceVisible
                            ? 'ETB ${fmt.format(maxIncome)}'
                            : 'ETB ••••••••',
                        subtitle: '${incomeTxs.length} incoming txs',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.arrow_downward_rounded,
                        iconColor: AppColors.negative,
                        title: 'Largest Expense',
                        value: isBalanceVisible
                            ? 'ETB ${fmt.format(maxExpense)}'
                            : 'ETB ••••••••',
                        subtitle: 'Single peak outgoing',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.infoLight,
                        title: 'Top Party',
                        value: topParty,
                        subtitle: topPartyCount > 0
                            ? '$topPartyCount transactions'
                            : 'No party data',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            crossFadeState: _isBankPerformanceExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 8. Person & Counterparty Analytics Section (One Big Unified Card) ─────
  Widget _buildCounterpartyAnalyticsSection(
    List<AppTransaction> transactions,
    FinanceProvider provider,
  ) {
    final bankNamesUpper = {
      'CBE',
      'TELEBIRR',
      'CBE BIRR',
      'CBEBIRR',
      'AHADU',
      'AHADU BANK',
      'DASHEN',
      'DASHEN BANK',
      'BOA',
      'ABYSSINIA',
      'BANK OF ABYSSINIA',
      'CASH',
      'MANUAL ENTRY',
      'UNKNOWN',
      ...provider.senders.map((s) => s.senderName.trim().toUpperCase()),
    };

    // Group by counterparty / sender
    final Map<String, List<AppTransaction>> groups = {};
    for (final tx in transactions) {
      final rawSender = tx.sender.trim();
      if (rawSender.isEmpty || bankNamesUpper.contains(rawSender.toUpperCase())) {
        continue;
      }
      groups.putIfAbsent(rawSender, () => []).add(tx);
    }

    if (groups.isEmpty) return const SizedBox.shrink();

    final List<CounterpartyInsight> list = groups.entries.map((e) {
      final name = e.key;
      final txs = e.value;
      final sentTxs = txs.where((t) => t.type == 'expense').toList();
      final rcvdTxs = txs.where((t) => t.type == 'income').toList();
      final totalSent = sentTxs.fold(0.0, (sum, t) => sum + t.amount);
      final totalReceived = rcvdTxs.fold(0.0, (sum, t) => sum + t.amount);
      final Set<String> banks = {};
      DateTime? latest;
      for (final t in txs) {
        if (t.name.isNotEmpty) banks.add(t.name);
        if (latest == null || t.date.isAfter(latest)) latest = t.date;
      }
      return CounterpartyInsight(
        name: name,
        totalSent: totalSent,
        totalReceived: totalReceived,
        sentCount: sentTxs.length,
        receivedCount: rcvdTxs.length,
        lastDate: latest,
        banks: banks,
      );
    }).toList();

    // Sort by activity (transaction count, then volume)
    list.sort((a, b) {
      final c = b.totalCount.compareTo(a.totalCount);
      if (c != 0) return c;
      return b.totalVolume.compareTo(a.totalVolume);
    });

    final activeInsight = list.firstWhere(
      (item) => item.name == _selectedCounterparty,
      orElse: () => list.first,
    );

    final isBalanceVisible = provider.isBalanceVisible;
    final fmt = NumberFormat('#,##0.00');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row: Title, Count Badge & Simple Expand Arrow ──
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isPersonContactExpanded = !_isPersonContactExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Person & Contact',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppBadge.neutral(
                      text: '${list.length}',
                      size: AppBadgeSize.micro,
                    ),
                  ],
                ),
                AnimatedRotation(
                  turns: _isPersonContactExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 14),

                // ── Streamlined Contact Selector (Inside Expanded Window) ──
                GestureDetector(
                  onTap: () => _showCounterpartyPickerSheet(list),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.heatmapNeutral,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      activeInsight.name,
                                      style: const TextStyle(
                                        color: AppColors.textSoft,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (list.first.name == activeInsight.name) ...[
                                    const SizedBox(width: 6),
                                    const AppBadge.warning(
                                      text: 'TOP',
                                      size: AppBadgeSize.micro,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${activeInsight.totalCount} transactions • ${isBalanceVisible ? '${fmt.format(activeInsight.totalVolume)} volume' : '••••••••'}',
                                style: const TextStyle(
                                  color: AppColors.textDisabled,
                                  fontSize: 10.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Minimalist 3-Stat Metric Row (No ETB prefix, smaller font) ──
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatTile(
                        label: 'Sent',
                        value: isBalanceVisible
                            ? fmt.format(activeInsight.totalSent)
                            : '••••••••',
                        color: AppColors.textSoft,
                        count: '${activeInsight.sentCount} out',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatTile(
                        label: 'Received',
                        value: isBalanceVisible
                            ? fmt.format(activeInsight.totalReceived)
                            : '••••••••',
                        color: AppColors.textSoft,
                        count: '${activeInsight.receivedCount} in',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatTile(
                        label: 'Net',
                        value: isBalanceVisible
                            ? '${activeInsight.netStanding >= 0 ? '+' : '-'}${fmt.format(activeInsight.netStanding.abs())}'
                            : '••••••••',
                        color: activeInsight.netStanding >= 0
                            ? AppColors.positive
                            : AppColors.negative,
                        count: activeInsight.netStanding >= 0
                            ? 'Surplus'
                            : 'Deficit',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── View All Transactions Button (100% Fully Rounded Pill) ──
                AppButton.secondary(
                  text: 'View ${activeInsight.totalCount} Transactions',
                  icon: Icons.receipt_long_rounded,
                  fullWidth: true,
                  height: 42,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllTransactionsScreen(
                          initialSenderFilter: activeInsight.name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            crossFadeState: _isPersonContactExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatTile({
    required String label,
    required String value,
    required Color color,
    required String count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.heatmapNeutral,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 9,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showCounterpartyPickerSheet(List<CounterpartyInsight> list) {
    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = list.where((c) {
              if (query.trim().isEmpty) return true;
              return c.name.toLowerCase().contains(query.trim().toLowerCase());
            }).toList();

            final provider = Provider.of<FinanceProvider>(context, listen: false);
            final fmt = NumberFormat('#,##0.00');
            final isBalanceVisible = provider.isBalanceVisible;

            return AppDrawer(
              heightFactor: 0.78,
              headerCard: AppDrawerHeaderCard(
                icon: Icons.person_search_rounded,
                iconColor: AppColors.positive,
                title: 'Select Contact',
                subtitle: '${list.length} total contacts recorded',
              ),
              child: Column(
                children: [
                  AppSearchBar(
                    mode: AppSearchBarMode.pill,
                    hint: 'Search contact name...',
                    onChanged: (val) {
                      setSheetState(() => query = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No contacts found matching search.',
                                style: TextStyle(color: AppColors.textSoft),
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, index) {
                              final item = filtered[index];
                              final isSelected = item.name == _selectedCounterparty ||
                                  (_selectedCounterparty == null && index == 0);

                              return Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.positive.withValues(alpha: 0.14)
                                      : AppColors.drawerCard,
                                  borderRadius: AppRadius.cardRadius,
                                ),
                                child: ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 2,
                                  ),
                                  leading: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.buttonPrimary
                                          : AppColors.surfaceElevated,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        item.name.isNotEmpty
                                            ? item.name.substring(0, 1).toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          color: isSelected
                                              ? AppColors.buttonPrimaryText
                                              : AppColors.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${item.totalCount} txs • ${isBalanceVisible ? 'ETB ${fmt.format(item.totalVolume)} volume' : '••••••••'}',
                                    style: const TextStyle(
                                      color: AppColors.textSoft,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.positive,
                                          size: 18,
                                        )
                                      : (index == 0 && query.isEmpty)
                                          ? const AppBadge.warning(
                                              text: 'TOP',
                                              size: AppBadgeSize.micro,
                                            )
                                          : null,
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _selectedCounterparty = item.name;
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CounterpartyInsight {
  final String name;
  final double totalSent;
  final double totalReceived;
  final int sentCount;
  final int receivedCount;
  final DateTime? lastDate;
  final Set<String> banks;

  CounterpartyInsight({
    required this.name,
    required this.totalSent,
    required this.totalReceived,
    required this.sentCount,
    required this.receivedCount,
    required this.lastDate,
    required this.banks,
  });

  int get totalCount => sentCount + receivedCount;
  double get totalVolume => totalSent + totalReceived;
  double get netStanding => totalReceived - totalSent;
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
  final Color? trackColor;

  MorphingSegmentedBarPainter({
    required this.oldItems,
    required this.newItems,
    required this.oldTotal,
    required this.newTotal,
    required this.progress,
    this.selectedIndex,
    this.trackColor,
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
      ..color = trackColor ?? AppColors.surface
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

// ── Frosted Glass Micro-Noise Grain Painter ─────────────────────────────────
class FrostedGlassNoisePainter extends CustomPainter {
  const FrostedGlassNoisePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(42);
    final paintLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;
    final paintDark = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final pointsLight = <Offset>[];
    final pointsDark = <Offset>[];

    for (int i = 0; i < 700; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      if (i % 2 == 0) {
        pointsLight.add(Offset(dx, dy));
      } else {
        pointsDark.add(Offset(dx, dy));
      }
    }

    canvas.drawPoints(PointMode.points, pointsLight, paintLight);
    canvas.drawPoints(PointMode.points, pointsDark, paintDark);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

