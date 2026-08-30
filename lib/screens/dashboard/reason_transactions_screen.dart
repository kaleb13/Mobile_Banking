import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_date_filter.dart';
import '../../widgets/bank_avatar.dart';
import 'transaction_detail_screen.dart';

/// Screen displaying all transactions associated with a specific reason or subcategory,
/// equipped with comprehensive filters, search tools, and bank brand avatars.
class ReasonTransactionsScreen extends StatefulWidget {
  final AppReason? reason;
  final String? title;
  final String? periodSubtitle;
  final List<AppTransaction>? transactions;
  final List<CashTransaction>? cashTransactions;

  const ReasonTransactionsScreen({
    super.key,
    this.reason,
    this.title,
    this.periodSubtitle,
    this.transactions,
    this.cashTransactions,
  });

  @override
  State<ReasonTransactionsScreen> createState() =>
      _ReasonTransactionsScreenState();
}

class _ReasonTransactionsScreenState extends State<ReasonTransactionsScreen> {
  String _searchQuery = '';
  bool _isSearchActive = false;
  bool _isFilterExpanded = false;
  bool _isBookmarkedOnly = false;
  String _typeFilter = 'All'; // 'All', 'Income', 'Expense', 'Bookmarked'
  String _sortBy = 'Date: Newest';
  AppDateFilterValue _dateFilterValue = const AppDateFilterValue.thisMonth();
  String _bankFilter = 'All Banks';
  String _senderFilter = 'All Senders';
  String _selectedSubcategory = 'All';
  int _displayLimit = 30;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _limitWords(String text, {int maxWords = 2}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return trimmed;
    return words.take(maxWords).join(' ');
  }

  bool _matchesDateFilter(DateTime date, AppDateFilterValue filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final txDate = DateTime(date.year, date.month, date.day);

    switch (filter.preset) {
      case AppDateFilterPreset.anyTime:
        return true;
      case AppDateFilterPreset.today:
        return txDate.isAtSameMomentAs(today);
      case AppDateFilterPreset.yesterday:
        final yesterday = today.subtract(const Duration(days: 1));
        return txDate.isAtSameMomentAs(yesterday);
      case AppDateFilterPreset.thisWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        return !txDate.isBefore(startOfWeek) && !txDate.isAfter(today);
      case AppDateFilterPreset.thisMonth:
        return date.year == now.year && date.month == now.month;
      case AppDateFilterPreset.last30Days:
        final thirtyDaysAgo = today.subtract(const Duration(days: 30));
        return !txDate.isBefore(thirtyDaysAgo) && !txDate.isAfter(today);
      case AppDateFilterPreset.thisYear:
        return date.year == now.year;
      case AppDateFilterPreset.customDate:
        if (filter.customDate == null) return true;
        final cDate = DateTime(filter.customDate!.year,
            filter.customDate!.month, filter.customDate!.day);
        return txDate.isAtSameMomentAs(cDate);
      case AppDateFilterPreset.customRange:
        if (filter.customRange == null) return true;
        final start = DateTime(filter.customRange!.start.year,
            filter.customRange!.start.month, filter.customRange!.start.day);
        final end = DateTime(filter.customRange!.end.year,
            filter.customRange!.end.month, filter.customRange!.end.day);
        return !txDate.isBefore(start) && !txDate.isAfter(end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final txVM = Provider.of<TransactionsViewModel>(context);
    final cashVM = Provider.of<CashWalletViewModel>(context);
    final displayTitle = widget.title ?? widget.reason?.name ?? 'Transactions';
    final fmt = NumberFormat('#,##0.00');
    final isBalanceVisible = settingsVM.isBalanceVisible;

    // Collect base source transactions
    List<AppTransaction> rawBankTransactions;
    List<CashTransaction> rawCashTransactions;

    if (widget.transactions != null) {
      rawBankTransactions = List.from(widget.transactions!);
      rawCashTransactions = widget.cashTransactions != null
          ? List.from(widget.cashTransactions!)
          : [];
    } else if (widget.reason != null) {
      final Set<String> targetReasonNames = {
        widget.reason!.name.toLowerCase().trim()
      };
      if (widget.reason!.id != null) {
        final subs = txVM.subcategoriesFor(widget.reason!.id!);
        for (final sub in subs) {
          targetReasonNames.add(sub.name.toLowerCase().trim());
        }
      }

      rawBankTransactions = txVM.transactions.where((tx) {
        final rName =
            (tx.resolvedReason ?? tx.reason ?? '').toLowerCase().trim();
        if (rName.isEmpty) return false;
        return targetReasonNames.contains(rName);
      }).toList();

      rawCashTransactions = cashVM.cashTransactions.where((ctx) {
        final rName =
            (ctx.reasonName ?? ctx.description ?? '').toLowerCase().trim();
        if (rName.isEmpty) return false;
        return targetReasonNames.contains(rName);
      }).toList();
    } else {
      rawBankTransactions = [];
      rawCashTransactions = [];
    }

    // Compute Totals
    double totalOutflow = 0.0;
    double totalInflow = 0.0;

    for (final tx in rawBankTransactions) {
      if (tx.type == 'income') {
        totalInflow += tx.amount;
      } else {
        totalOutflow += tx.amount;
      }
    }
    for (final ctx in rawCashTransactions) {
      if (ctx.type == 'addition' || ctx.type == 'income') {
        totalInflow += ctx.amount;
      } else {
        totalOutflow += ctx.amount;
      }
    }

    // Collect Available Bank & Sender Filter Options
    final Set<String> banks = {'All Banks'};
    final Set<String> senders = {'All Senders'};

    for (final tx in rawBankTransactions) {
      if (tx.name.isNotEmpty) banks.add(tx.name);
      if (tx.sender.isNotEmpty) senders.add(tx.sender);
    }
    if (rawCashTransactions.isNotEmpty) {
      banks.add('Cash');
      for (final ctx in rawCashTransactions) {
        if (ctx.description != null && ctx.description!.isNotEmpty) {
          senders.add(ctx.description!);
        }
      }
    }

    final allBanksList = banks.toList()..sort();
    if (!allBanksList.contains(_bankFilter)) _bankFilter = 'All Banks';

    final allSendersList = senders.toList()..sort();
    if (!allSendersList.contains(_senderFilter)) _senderFilter = 'All Senders';

    // Collect and count active subcategories
    final List<({String name, int count, double totalAmount})> activeSubcategories = [];
    final Map<String, ({int count, double totalAmount})> subCounts = {};

    // ── Build Fast O(1) Lookup Maps ONCE ─────────────────────────────────────
    final Map<int, AppReason> reasonsById = {};
    final Map<String, AppReason> reasonsByNameLower = {};
    final Map<String, String> subcategoryNameExactMap = {};

    for (final r in txVM.reasons) {
      if (r.id != null) {
        reasonsById[r.id!] = r;
      }
      reasonsByNameLower[r.name.trim().toLowerCase()] = r;
    }

    if (widget.reason != null && widget.reason!.id != null) {
      final subs = txVM.subcategoriesFor(widget.reason!.id!);
      for (final s in subs) {
        final cleanName = s.name.trim();
        subCounts[cleanName] = (count: 0, totalAmount: 0.0);
        subcategoryNameExactMap[cleanName.toLowerCase()] = cleanName;
      }
    }

    for (final tx in rawBankTransactions) {
      String? matchedSub;
      if (tx.subcategoryId != null) {
        matchedSub = reasonsById[tx.subcategoryId!]?.name;
      }
      if (matchedSub == null && tx.reasonId != null) {
        final r = reasonsById[tx.reasonId!];
        if (r != null && r.isSubcategory) {
          matchedSub = r.name;
        }
      }
      if (matchedSub == null) {
        final raw = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '').trim();
        if (raw.isNotEmpty) {
          matchedSub = subcategoryNameExactMap[raw.toLowerCase()];
        }
      }
      if (matchedSub != null) {
        final curr = subCounts[matchedSub] ?? (count: 0, totalAmount: 0.0);
        subCounts[matchedSub] = (count: curr.count + 1, totalAmount: curr.totalAmount + tx.amount);
      }
    }

    for (final ctx in rawCashTransactions) {
      String? matchedSub;
      if (ctx.reasonId != null) {
        final r = reasonsById[ctx.reasonId!];
        if (r != null && r.isSubcategory) {
          matchedSub = r.name;
        }
      }
      if (matchedSub == null) {
        final raw = (ctx.reasonName ?? ctx.description ?? '').trim();
        if (raw.isNotEmpty) {
          matchedSub = subcategoryNameExactMap[raw.toLowerCase()];
        }
      }
      if (matchedSub != null) {
        final curr = subCounts[matchedSub] ?? (count: 0, totalAmount: 0.0);
        subCounts[matchedSub] = (count: curr.count + 1, totalAmount: curr.totalAmount + ctx.amount);
      }
    }

    subCounts.forEach((name, data) {
      if (data.count > 0) {
        activeSubcategories.add((name: name, count: data.count, totalAmount: data.totalAmount));
      }
    });
    activeSubcategories.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Filter Bank Transactions
    final filteredBankTxs = rawBankTransactions.where((tx) {
      if (_selectedSubcategory != 'All') {
        final subLower = _selectedSubcategory.toLowerCase().trim();
        String? txSub;
        if (tx.subcategoryId != null) {
          txSub = reasonsById[tx.subcategoryId!]?.name;
        }
        if (txSub == null && tx.reasonId != null) {
          final r = reasonsById[tx.reasonId!];
          if (r != null && r.isSubcategory) {
            txSub = r.name;
          }
        }
        if (txSub == null) {
          final raw = (tx.resolvedReason ?? tx.reason ?? tx.customReasonText ?? '').trim();
          if (raw.isNotEmpty) txSub = raw;
        }
        if ((txSub ?? '').toLowerCase().trim() != subLower) return false;
      }

      if (_isBookmarkedOnly && !tx.isBookmarked) return false;
      if (_typeFilter == 'Expense' && tx.type != 'expense') return false;
      if (_typeFilter == 'Income' && tx.type != 'income') return false;

      if (_bankFilter != 'All Banks' &&
          tx.name.toLowerCase() != _bankFilter.toLowerCase()) {
        return false;
      }
      if (_senderFilter != 'All Senders' &&
          tx.sender.toLowerCase() != _senderFilter.toLowerCase()) {
        return false;
      }
      if (!_matchesDateFilter(tx.date, _dateFilterValue)) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchSender = tx.sender.toLowerCase().contains(query);
        final matchBank = tx.name.toLowerCase().contains(query);
        final matchReason = (tx.resolvedReason ?? tx.reason ?? '')
            .toLowerCase()
            .contains(query);
        final matchCustom =
            (tx.customReasonText ?? '').toLowerCase().contains(query);
        final matchNote = (tx.note ?? '').toLowerCase().contains(query);
        final matchRef =
            (tx.bankReference ?? '').toLowerCase().contains(query);

        if (!matchSender &&
            !matchBank &&
            !matchReason &&
            !matchCustom &&
            !matchNote &&
            !matchRef) {
          return false;
        }
      }
      return true;
    }).toList();

    // Filter Cash Transactions
    final filteredCashTxs = rawCashTransactions.where((ctx) {
      if (_selectedSubcategory != 'All') {
        final subLower = _selectedSubcategory.toLowerCase().trim();
        String? ctxSub;
        if (ctx.reasonId != null) {
          final r = reasonsById[ctx.reasonId!];
          if (r != null && r.isSubcategory) {
            ctxSub = r.name;
          }
        }
        if (ctxSub == null) {
          final raw = (ctx.reasonName ?? ctx.description ?? '').trim();
          if (raw.isNotEmpty) ctxSub = raw;
        }
        if ((ctxSub ?? '').toLowerCase().trim() != subLower) return false;
      }

      if (_isBookmarkedOnly) return false;
      final isAddition = ctx.type == 'addition' || ctx.type == 'income';
      if (_typeFilter == 'Expense' && isAddition) return false;
      if (_typeFilter == 'Income' && !isAddition) return false;

      if (_bankFilter != 'All Banks' && _bankFilter != 'Cash') return false;
      if (_senderFilter != 'All Senders' &&
          (ctx.description ?? '').toLowerCase() != _senderFilter.toLowerCase()) {
        return false;
      }
      if (!_matchesDateFilter(ctx.date, _dateFilterValue)) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchDesc =
            (ctx.description ?? '').toLowerCase().contains(query);
        final matchReason =
            (ctx.reasonName ?? '').toLowerCase().contains(query);
        if (!matchDesc && !matchReason && !query.contains('cash')) return false;
      }
      return true;
    }).toList();

    // Combine and Sort
    final List<_UnifiedReasonTxItem> combinedItems = [
      ...filteredBankTxs.map((t) => _UnifiedReasonTxItem.bank(t)),
      ...filteredCashTxs.map((c) => _UnifiedReasonTxItem.cash(c)),
    ];

    switch (_sortBy) {
      case 'Date: Newest':
        combinedItems.sort((a, b) => b.date.compareTo(a.date));
        break;
      case 'Date: Oldest':
        combinedItems.sort((a, b) => a.date.compareTo(b.date));
        break;
      case 'Amount: High-Low':
        combinedItems.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Amount: Low-High':
        combinedItems.sort((a, b) => a.amount.compareTo(b.amount));
        break;
      case 'Name: A-Z':
        combinedItems.sort((a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
        break;
      default:
        combinedItems.sort((a, b) => b.date.compareTo(a.date));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 10,
          leadingWidth: 48,
          title: Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: AppBackButton(),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Summary Header Banner ─────────────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadius.cardRadius,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.positive.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: AppColors.positive,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${rawBankTransactions.length + rawCashTransactions.length} Total Items',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.periodSubtitle != null)
                                AppBadge.neutral(
                                  text: widget.periodSubtitle!,
                                  size: AppBadgeSize.small,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Inflow / Outflow summary pills
                          Row(
                            children: [
                              // Outflow
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_upward_rounded,
                                            color: AppColors.negative,
                                            size: 13,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Expense',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isBalanceVisible
                                            ? '${fmt.format(totalOutflow)} ETB'
                                            : '••••••••',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Inflow
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.arrow_downward_rounded,
                                            color: AppColors.positive,
                                            size: 13,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Income',
                                            style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isBalanceVisible
                                            ? '${fmt.format(totalInflow)} ETB'
                                            : '••••••••',
                                        style: const TextStyle(
                                          color: AppColors.positive,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── 2. Subcategories Horizontal Filter Bar (If available) ─
                    if (activeSubcategories.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SUBCATEGORIES',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${activeSubcategories.length} Subcategories',
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // "All" Pill
                            _buildSubcategoryChip(
                              label: 'All Subcategories',
                              count: rawBankTransactions.length +
                                  rawCashTransactions.length,
                              isSelected: _selectedSubcategory == 'All',
                              onTap: () {
                                setState(() {
                                  _selectedSubcategory = 'All';
                                  _displayLimit = 30;
                                });
                              },
                            ),
                            const SizedBox(width: 8),

                            // Individual Subcategory Chips
                            ...activeSubcategories.map((sub) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildSubcategoryChip(
                                  label: sub.name,
                                  count: sub.count,
                                  netAmount: sub.totalAmount,
                                  isSelected: _selectedSubcategory == sub.name,
                                  onTap: () {
                                    setState(() {
                                      _selectedSubcategory = sub.name;
                                      _displayLimit = 30;
                                    });
                                  },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── 3. Search & Filter Bar ───────────────────────────────
                    AppSearchBar(
                      mode: AppSearchBarMode.icon,
                      isExpanded: _isSearchActive,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hint: 'Search by sender, bank, or notes...',
                      title: 'Transactions (${combinedItems.length})',
                      leading: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isFilterExpanded = !_isFilterExpanded;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.filter_list_rounded,
                            color: _isFilterExpanded
                                ? AppColors.positive
                                : Colors.white70,
                            size: 22,
                          ),
                        ),
                      ),
                      onExpandChanged: (expanded) {
                        setState(() {
                          _isSearchActive = expanded;
                          _displayLimit = 30;
                        });
                      },
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                          _displayLimit = 30;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                          _displayLimit = 30;
                        });
                      },
                      onClose: () {
                        setState(() {
                          _isSearchActive = false;
                          _searchQuery = '';
                          _displayLimit = 30;
                        });
                      },
                      backgroundColor: AppColors.surface,
                      textColor: Colors.white,
                      hintColor: AppColors.textSecondary,
                      iconColor: Colors.white70,
                      closeIconColor: Colors.white,
                    ),

                    // Filter Row Dropdowns
                    if (_isSearchActive || _isFilterExpanded) ...[
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            // Bookmark Toggle Pill
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isBookmarkedOnly = !_isBookmarkedOnly;
                                  _displayLimit = 30;
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 34,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _isBookmarkedOnly
                                      ? AppColors.gold.withValues(alpha: 0.18)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isBookmarkedOnly
                                          ? Icons.bookmark_rounded
                                          : Icons.bookmark_border_rounded,
                                      size: 15,
                                      color: _isBookmarkedOnly
                                          ? AppColors.gold
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Bookmarked',
                                      style: TextStyle(
                                        color: _isBookmarkedOnly
                                            ? AppColors.gold
                                            : Colors.white,
                                        fontSize: 12,
                                        fontWeight: _isBookmarkedOnly
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Type Dropdown
                            AppDropdown.simple(
                              value: _typeFilter,
                              items: const [
                                'All',
                                'Expense',
                                'Income',
                              ],
                              variant: AppDropdownVariant.dark,
                              maxWidth: 120,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _typeFilter = val;
                                    _displayLimit = 30;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Sort Dropdown
                            AppDropdown.simple(
                              value: _sortBy,
                              items: const [
                                'Date: Newest',
                                'Date: Oldest',
                                'Amount: High-Low',
                                'Amount: Low-High',
                                'Name: A-Z',
                              ],
                              variant: AppDropdownVariant.dark,
                              maxWidth: 130,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _sortBy = val;
                                    _displayLimit = 30;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Date Filter
                            AppDateFilter.dark(
                              value: _dateFilterValue,
                              onChanged: (val) {
                                setState(() {
                                  _dateFilterValue = val;
                                  _displayLimit = 30;
                                });
                              },
                            ),
                            const SizedBox(width: 8),

                            // Bank Filter
                            AppDropdown.simple(
                              value: _bankFilter,
                              items: allBanksList,
                              variant: AppDropdownVariant.dark,
                              maxWidth: 100,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _bankFilter = val;
                                    _displayLimit = 30;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // Sender Filter
                            AppDropdown.simple(
                              value: _senderFilter,
                              items: allSendersList,
                              variant: AppDropdownVariant.dark,
                              maxWidth: 110,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _senderFilter = val;
                                    _displayLimit = 30;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ── 3. Transaction List with Bank Logos ──────────────────
                    if (combinedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 42,
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No matching transactions found in "$displayTitle"',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...combinedItems.take(_displayLimit).map((item) {
                        return _buildTransactionItem(item, fmt, isBalanceVisible);
                      }),
                      if (combinedItems.length > _displayLimit)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: AppButton.secondary(
                              text: 'Load More (+${(combinedItems.length - _displayLimit) > 30 ? 30 : (combinedItems.length - _displayLimit)} of ${combinedItems.length - _displayLimit})',
                              icon: Icons.expand_more_rounded,
                              height: 42,
                              fullWidth: true,
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _displayLimit += 30);
                              },
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(
    _UnifiedReasonTxItem item,
    NumberFormat fmt,
    bool isBalanceVisible,
  ) {
    final isIncome = item.isIncome;
    final amountStr = isBalanceVisible ? fmt.format(item.amount) : '••••••••';
    final String label = isIncome ? 'Income' : 'Expense';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: item.isBank
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionDetailScreen(transaction: item.bankTx!),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ── Bank Brand Logo Avatar ──
                BankAvatar(
                  bankName: item.bankName,
                  size: 38,
                  iconSize: 20,
                  isLight: false,
                ),
                const SizedBox(width: 12),

                // ── Title, Subtitle ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _limitWords(
                                item.displayName.isNotEmpty
                                    ? item.displayName
                                    : label,
                                maxWords: 2,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.isBookmarked) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.bookmark_rounded,
                              color: AppColors.gold,
                              size: 13,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy • HH:mm').format(item.date),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          if (item.reasonTag != null &&
                              item.reasonTag!.isNotEmpty &&
                              item.reasonTag != widget.title) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                item.reasonTag!,
                                style: const TextStyle(
                                  color: AppColors.textSoft,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Amount & Chevron ──
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}$amountStr ETB',
                      style: TextStyle(
                        color: isIncome ? AppColors.positive : Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.isBank) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubcategoryChip({
    required String label,
    required int count,
    double? netAmount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
    final fmt = NumberFormat('#,##0');
    final String countLabel = netAmount != null && netAmount > 0
        ? (settingsVM.isBalanceVisible
            ? '$count • ${fmt.format(netAmount)} ETB'
            : '$count')
        : '$count';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brandGreen.withValues(alpha: 0.20)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.brandGreen : Colors.white,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandGreen.withValues(alpha: 0.25)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                countLabel,
                style: TextStyle(
                  color: isSelected ? AppColors.brandGreen : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedReasonTxItem {
  final bool isBank;
  final AppTransaction? bankTx;
  final CashTransaction? cashTx;

  _UnifiedReasonTxItem.bank(this.bankTx)
      : isBank = true,
        cashTx = null;

  _UnifiedReasonTxItem.cash(this.cashTx)
      : isBank = false,
        bankTx = null;

  DateTime get date => isBank ? bankTx!.date : cashTx!.date;
  double get amount => isBank ? bankTx!.amount : cashTx!.amount;
  bool get isIncome =>
      isBank ? bankTx!.type == 'income' : (cashTx!.type == 'addition' || cashTx!.type == 'income');
  String get bankName => isBank ? bankTx!.name : 'CASH';
  String get displayName => isBank
      ? (bankTx!.sender.isNotEmpty ? bankTx!.sender : bankTx!.name)
      : (cashTx!.description ?? 'Cash');
  bool get isBookmarked => isBank ? bankTx!.isBookmarked : false;
  String? get reasonTag => isBank
      ? (bankTx!.resolvedReason ?? bankTx!.reason ?? bankTx!.customReasonText)
      : (cashTx!.reasonName ?? cashTx!.description);
}
