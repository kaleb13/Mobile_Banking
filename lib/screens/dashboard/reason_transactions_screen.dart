import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badges.dart';
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
  String _typeFilter = 'All'; // 'All', 'Withdrawals', 'Deposits', 'Bookmarked'
  String _sortBy = 'Date: Newest';
  AppDateFilterValue _dateFilterValue = const AppDateFilterValue.anyTime();
  String _bankFilter = 'All Banks';
  String _senderFilter = 'All Senders';

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
    final provider = Provider.of<FinanceProvider>(context);
    final displayTitle = widget.title ?? widget.reason?.name ?? 'Transactions';
    final fmt = NumberFormat('#,##0.00');
    final isBalanceVisible = provider.isBalanceVisible;

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
        final subs = provider.subcategoriesFor(widget.reason!.id!);
        for (final sub in subs) {
          targetReasonNames.add(sub.name.toLowerCase().trim());
        }
      }

      rawBankTransactions = provider.transactions.where((tx) {
        final rName =
            (tx.resolvedReason ?? tx.reason ?? '').toLowerCase().trim();
        if (rName.isEmpty) return false;
        return targetReasonNames.contains(rName);
      }).toList();

      rawCashTransactions = provider.cashTransactions.where((ctx) {
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

    // Filter Bank Transactions
    final filteredBankTxs = rawBankTransactions.where((tx) {
      if (_isBookmarkedOnly && !tx.isBookmarked) return false;
      if (_typeFilter == 'Withdrawals' && tx.type != 'expense') return false;
      if (_typeFilter == 'Deposits' && tx.type != 'income') return false;

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
      if (_isBookmarkedOnly) return false;
      final isAddition = ctx.type == 'addition' || ctx.type == 'income';
      if (_typeFilter == 'Withdrawals' && isAddition) return false;
      if (_typeFilter == 'Deposits' && !isAddition) return false;

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
          titleSpacing: 0,
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
          leading: const AppBackButton(),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Summary Header Banner ─────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
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
                                            'Outflow / Spent',
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
                                            : '****',
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
                                            'Inflow / Received',
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
                                            : '****',
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

                    // ── 2. Search & Filter Bar ───────────────────────────────
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
                        });
                      },
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      onClear: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                      onClose: () {
                        setState(() {
                          _isSearchActive = false;
                          _searchQuery = '';
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
                        child: Row(
                          children: [
                            // Bookmark Toggle Pill
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isBookmarkedOnly = !_isBookmarkedOnly;
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
                                'Withdrawals',
                                'Deposits',
                              ],
                              variant: AppDropdownVariant.dark,
                              maxWidth: 120,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _typeFilter = val;
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
                    else
                      ...combinedItems.map((item) {
                        return _buildTransactionItem(item, fmt, isBalanceVisible);
                      }),
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
    final amountStr = isBalanceVisible ? fmt.format(item.amount) : '****';
    final String label = isIncome ? 'Deposit' : 'Transferred';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
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
