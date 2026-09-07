import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/bank_avatar.dart';
import 'transaction_detail_screen.dart';

/// Unified representation of a transaction (Bank or Cash) for date drill-down listing
class _UnifiedDateTxItem {
  final AppTransaction? bankTx;
  final CashTransaction? cashTx;

  _UnifiedDateTxItem.bank(this.bankTx) : cashTx = null;
  _UnifiedDateTxItem.cash(this.cashTx) : bankTx = null;

  bool get isBank => bankTx != null;
  DateTime get date => isBank ? bankTx!.date : cashTx!.date;
  double get amount => isBank ? bankTx!.amount : cashTx!.amount;
  bool get isIncome => isBank ? bankTx!.isIncome : cashTx!.isIncome;

  String get displayName {
    if (isBank) {
      return bankTx!.counterparty.isNotEmpty ? bankTx!.counterparty : bankTx!.bankName;
    }
    return cashTx!.description ?? 'Cash Transaction';
  }

  String get bankOrWalletName {
    if (isBank) {
      return bankTx!.bankName.isNotEmpty ? bankTx!.bankName : 'Bank';
    }
    return 'Cash Wallet';
  }

  String get categoryName {
    if (isBank) {
      return bankTx!.resolvedCategory;
    }
    return cashTx!.reasonName ?? 'Uncategorized';
  }

  bool get isBookmarked => isBank ? bankTx!.isBookmarked : false;
}

/// Date-Specific Drill-Down Screen showing transactions for a specific date,
/// complete with top summary card, search bar, and filter suite matching CategoryDetailScreen.
class DateTransactionsScreen extends StatefulWidget {
  final DateTime date;
  final List<AppTransaction>? initialBankTransactions;
  final List<CashTransaction>? initialCashTransactions;

  const DateTransactionsScreen({
    super.key,
    required this.date,
    this.initialBankTransactions,
    this.initialCashTransactions,
  });

  @override
  State<DateTransactionsScreen> createState() => _DateTransactionsScreenState();
}

class _DateTransactionsScreenState extends State<DateTransactionsScreen> {
  // Search & Filter State
  String _searchQuery = '';
  bool _isSearchActive = false;
  bool _isFilterExpanded = false;
  bool _isBookmarkedOnly = false;
  String _typeFilter = 'All'; // 'All', 'Expense', 'Income'
  String _sortBy = 'Date: Newest';
  String _bankFilter = 'All Banks';
  String _counterpartyFilter = 'All Counterparties';
  String _categoryFilter = 'All Categories';
  int _displayLimit = 30;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);
    final cashVM = Provider.of<CashWalletViewModel>(context);

    // 1. Source all transactions for the target date
    final List<AppTransaction> dayBankTxs = widget.initialBankTransactions ??
        txVM.transactions.where((t) =>
            t.date.year == widget.date.year &&
            t.date.month == widget.date.month &&
            t.date.day == widget.date.day).toList();

    final List<CashTransaction> dayCashTxs = widget.initialCashTransactions ??
        cashVM.cashTransactions.where((c) =>
            c.date.year == widget.date.year &&
            c.date.month == widget.date.month &&
            c.date.day == widget.date.day).toList();

    // 2. Compute Summary Totals for the date
    double totalInflow = 0.0;
    double totalOutflow = 0.0;
    for (final t in dayBankTxs) {
      if (t.isIncome) {
        totalInflow += t.amount;
      } else {
        totalOutflow += t.amount;
      }
    }
    for (final c in dayCashTxs) {
      if (c.isIncome) {
        totalInflow += c.amount;
      } else {
        totalOutflow += c.amount;
      }
    }
    final double netTotalFlow = totalInflow - totalOutflow;

    // 3. Extract Dynamic Filter Options
    final Set<String> banks = {'All Banks'};
    final Set<String> counterparties = {'All Counterparties'};
    final Set<String> categories = {'All Categories'};

    for (final t in dayBankTxs) {
      if (t.bankName.isNotEmpty) banks.add(t.bankName);
      if (t.counterparty.isNotEmpty) counterparties.add(t.counterparty);
      final cat = t.resolvedCategory;
      if (cat.isNotEmpty && cat != 'Uncategorized') categories.add(cat);
    }
    if (dayCashTxs.isNotEmpty) {
      banks.add('Cash');
      for (final c in dayCashTxs) {
        if (c.description != null && c.description!.isNotEmpty) {
          counterparties.add(c.description!);
        }
        final cat = c.reasonName;
        if (cat != null && cat.isNotEmpty && cat != 'Uncategorized') {
          categories.add(cat);
        }
      }
    }

    // 4. Apply Filters
    final filteredBankTxs = dayBankTxs.where((tx) {
      if (_isBookmarkedOnly && !tx.isBookmarked) return false;
      if (_typeFilter == 'Expense' && tx.isIncome) return false;
      if (_typeFilter == 'Income' && !tx.isIncome) return false;
      if (_bankFilter != 'All Banks' && tx.bankName != _bankFilter) return false;
      if (_counterpartyFilter != 'All Counterparties' &&
          _counterpartyFilter != 'All Senders' &&
          tx.counterparty != _counterpartyFilter) {
        return false;
      }
      if (_categoryFilter != 'All Categories' && tx.resolvedCategory != _categoryFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchParty = tx.counterparty.toLowerCase().contains(query);
        final matchBank = tx.bankName.toLowerCase().contains(query);
        final matchReason = (tx.reason ?? '').toLowerCase().contains(query);
        final matchCustom = (tx.customReasonText ?? '').toLowerCase().contains(query);
        final matchNote = (tx.note ?? '').toLowerCase().contains(query);
        final matchRef = (tx.bankReference ?? '').toLowerCase().contains(query);
        final matchAmount = tx.amount.toString().contains(query);

        if (!matchParty && !matchBank && !matchReason && !matchCustom && !matchNote && !matchRef && !matchAmount) {
          return false;
        }
      }
      return true;
    }).toList();

    final filteredCashTxs = dayCashTxs.where((ctx) {
      if (_isBookmarkedOnly) return false;
      final isIncome = ctx.isIncome;
      if (_typeFilter == 'Expense' && isIncome) return false;
      if (_typeFilter == 'Income' && !isIncome) return false;
      if (_bankFilter != 'All Banks' && _bankFilter != 'Cash') return false;
      if (_counterpartyFilter != 'All Counterparties' &&
          _counterpartyFilter != 'All Senders' &&
          (ctx.description ?? '') != _counterpartyFilter) {
        return false;
      }
      final cat = ctx.reasonName ?? 'Uncategorized';
      if (_categoryFilter != 'All Categories' && cat != _categoryFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final matchDesc = (ctx.description ?? '').toLowerCase().contains(query);
        final matchReason = (ctx.reasonName ?? '').toLowerCase().contains(query);
        final matchAmount = ctx.amount.toString().contains(query);
        if (!matchDesc && !matchReason && !matchAmount && !query.contains('cash')) {
          return false;
        }
      }
      return true;
    }).toList();

    // 5. Combine & Sort
    final List<_UnifiedDateTxItem> combinedItems = [
      ...filteredBankTxs.map((t) => _UnifiedDateTxItem.bank(t)),
      ...filteredCashTxs.map((c) => _UnifiedDateTxItem.cash(c)),
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

    final fmt = NumberFormat('#,##0.00');
    final formattedDateTitle = DateFormat('EEEE, MMM d, yyyy').format(widget.date);

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
            DateFormat('MMM d, yyyy').format(widget.date),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Top Summary Banner Card ───────────────────────────
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
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
                                  color: AppColors.brandGreen.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  color: AppColors.brandGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formattedDateTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dayBankTxs.length + dayCashTxs.length} Total Transactions',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AppBadge.neutral(
                                text: 'Day View',
                                size: AppBadgeSize.small,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Net Total Flow Hero Metric ───────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Net Daily Flow',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${netTotalFlow >= 0 ? '+' : ''}${fmt.format(netTotalFlow)} ETB',
                                    style: TextStyle(
                                      color: netTotalFlow >= 0
                                          ? AppColors.positive
                                          : AppColors.negative,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: netTotalFlow >= 0
                                      ? AppColors.positive.withValues(alpha: 0.15)
                                      : AppColors.negative.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      netTotalFlow >= 0
                                          ? Icons.trending_up_rounded
                                          : Icons.trending_down_rounded,
                                      color: netTotalFlow >= 0
                                          ? AppColors.positive
                                          : AppColors.negative,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      netTotalFlow >= 0 ? 'Surplus' : 'Deficit',
                                      style: TextStyle(
                                        color: netTotalFlow >= 0
                                            ? AppColors.positive
                                            : AppColors.negative,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Breakdown Cards: Expense vs Income ────────────────
                          Row(
                            children: [
                              // Outflow (Expense)
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
                                        '${fmt.format(totalOutflow)} ETB',
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

                              // Inflow (Income)
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
                                        '${fmt.format(totalInflow)} ETB',
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

                    // ── 2. Search & Comprehensive Filter Bar ──────────────────
                    AppSearchBar(
                      mode: AppSearchBarMode.icon,
                      isExpanded: _isSearchActive,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      hint: 'Search counterparty, bank, notes...',
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
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            // ── Bookmark Toggle Pill ──
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
                                padding: const EdgeInsets.symmetric(horizontal: 12),
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

                            // ── Type Dropdown (All, Expense, Income) ──
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
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // ── Bank Filter Dropdown ──
                            AppDropdown.simple(
                              value: _bankFilter,
                              items: banks.toList(),
                              variant: AppDropdownVariant.dark,
                              maxWidth: 140,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _bankFilter = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),

                            // ── Counterparty Filter Dropdown ──
                            if (counterparties.length > 2) ...[
                              AppDropdown.simple(
                                value: _counterpartyFilter,
                                items: counterparties.toList(),
                                variant: AppDropdownVariant.dark,
                                maxWidth: 150,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _counterpartyFilter = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                            ],

                            // ── Category Filter Dropdown ──
                            if (categories.length > 2) ...[
                              AppDropdown.simple(
                                value: _categoryFilter,
                                items: categories.toList(),
                                variant: AppDropdownVariant.dark,
                                maxWidth: 150,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _categoryFilter = val;
                                    });
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                            ],

                            // ── Sort Dropdown ──
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
                              maxWidth: 160,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _sortBy = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // ── 3. Transaction List Header & Items ────────────────────
                    if (combinedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: const AppEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No Transactions Found',
                          subtitle: 'Try adjusting your filters or search terms.',
                        ),
                      )
                    else ...[
                      ...combinedItems.take(_displayLimit).map((item) {
                        return _buildTransactionItem(item, fmt);
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
    _UnifiedDateTxItem item,
    NumberFormat fmt,
  ) {
    final isIncome = item.isIncome;
    final amountStr = fmt.format(item.amount);
    final formattedTime = DateFormat('h:mm a').format(item.date);

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Avatar
                if (item.isBank)
                  BankAvatar(
                    bankName: item.bankTx!.bankName,
                    size: 40,
                  )
                else
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payments_rounded,
                      color: AppColors.textPrimary,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 12),

                // Title, Subtitle, Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.displayName,
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
                              size: 14,
                              color: AppColors.gold,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            item.bankOrWalletName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            '•',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedTime,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      if (item.categoryName.isNotEmpty &&
                          item.categoryName != 'Uncategorized') ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            item.categoryName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}$amountStr ETB',
                      style: TextStyle(
                        color: isIncome ? AppColors.positive : AppColors.negative,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isIncome ? 'Income' : 'Expense',
                      style: TextStyle(
                        color: isIncome ? AppColors.positive : AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
