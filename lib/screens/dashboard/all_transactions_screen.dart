import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../utils/counterparty_matcher.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_date_filter.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../domain/usecases/transactions/filter_transactions_usecase.dart';
import '../../services/bank_senders.dart';
import '../../widgets/bank_avatar.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialBankFilter;
  final String? initialCounterpartyFilter;
  final String? initialSenderFilter; // Backward-compatibility alias
  final AppDateFilterValue? initialDateFilter;

  const AllTransactionsScreen({
    super.key,
    this.initialSearchQuery,
    this.initialBankFilter,
    this.initialCounterpartyFilter,
    this.initialSenderFilter,
    this.initialDateFilter,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  late String _selectedBank;
  String? _selectedCounterparty;
  int? _selectedSimSlot; // null = All SIMs, 0 = SIM 1, 1 = SIM 2
  late AppDateFilterValue _dateFilterValue;
  String _selectedType = 'All';
  String _selectedCategory = 'All';
  bool _isBookmarkedOnly = false;
  String _sortBy = 'Date: Newest';
  int _displayLimit = 30;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _selectedBank = widget.initialBankFilter ?? 'All Banks';
    _selectedCounterparty = widget.initialCounterpartyFilter;

    // Backward-compatibility bridge for initialSenderFilter
    if (widget.initialSenderFilter != null &&
        widget.initialSenderFilter!.isNotEmpty &&
        widget.initialSenderFilter != 'All' &&
        widget.initialSenderFilter != 'All Senders') {
      final senderVal = widget.initialSenderFilter!;
      final isKnownBank = BankSenders.match(senderVal) != null;
      if (isKnownBank) {
        if (_selectedBank == 'All Banks' || _selectedBank == 'All') {
          _selectedBank = senderVal;
        }
      } else {
        _selectedCounterparty ??= senderVal;
      }
    }

    _dateFilterValue =
        widget.initialDateFilter ?? const AppDateFilterValue.anyTime();
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final allTransactions = txVM.transactions;
    final fmt = NumberFormat('#,##0.00');

    // Unique bank names for the dropdown (strictly banks only)
    final Set<String> bankNamesSet = {
      'All Banks',
      ...txVM.senders.map((s) => s.senderName),
    };
    if (_selectedBank != 'All Banks' && _selectedBank != 'All') {
      bankNamesSet.add(_selectedBank);
    }
    final bankNames = bankNamesSet.toList();

    final bool isCounterpartyView = _selectedCounterparty != null &&
        _selectedCounterparty!.trim().isNotEmpty &&
        _selectedCounterparty != 'All' &&
        _selectedCounterparty != 'All Counterparties' &&
        _selectedCounterparty != 'All Senders';

    // 1. Compute full category inventory for this counterparty across active date & search
    final counterpartyTxs = isCounterpartyView
        ? const FilterTransactionsUseCase().execute(
            transactions: allTransactions,
            params: FilterTransactionsParams(
              bankFilter: (_selectedBank != 'All Banks' && _selectedBank != 'All')
                  ? _selectedBank
                  : null,
              counterpartyFilter: _selectedCounterparty,
              simSlotFilter: _selectedSimSlot,
              dateFilter: _dateFilterValue,
              searchQuery: _searchQuery,
              onlyBookmarked: _isBookmarkedOnly,
            ),
          )
        : const <AppTransaction>[];

    final Map<String, int> categoryCounts = {};
    if (isCounterpartyView) {
      for (final tx in counterpartyTxs) {
        final rawCat = tx.resolvedCategory.trim();
        final cat = rawCat.isNotEmpty ? rawCat : 'General';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
    }

    // 2. Filter logic using domain usecase
    final filteredTransactions = const FilterTransactionsUseCase().execute(
      transactions: allTransactions,
      params: FilterTransactionsParams(
        bankFilter: (_selectedBank != 'All Banks' && _selectedBank != 'All')
            ? _selectedBank
            : null,
        counterpartyFilter: isCounterpartyView ? _selectedCounterparty : null,
        categoryFilter:
            _selectedCategory != 'All' ? _selectedCategory : null,
        typeFilter: _selectedType,
        simSlotFilter: _selectedSimSlot,
        dateFilter: _dateFilterValue,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
        onlyBookmarked: _isBookmarkedOnly,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildTopHeaderAndSearch(
              context,
              txVM,
              bankNames,
              filteredTransactions.length,
              isCounterpartyView: isCounterpartyView,
              counterpartyTxs: counterpartyTxs,
              categoryCounts: categoryCounts,
              filteredTransactions: filteredTransactions,
              isBalanceVisible: settingsVM.isBalanceVisible,
              fmt: fmt,
            ),
            Expanded(
              child: _buildTransactionList(filteredTransactions, settingsVM),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seamless Top Header & Search/Filter Section ────────────────────────────
  Widget _buildTopHeaderAndSearch(
    BuildContext context,
    TransactionsViewModel txVM,
    List<String> bankNames,
    int count, {
    required bool isCounterpartyView,
    required List<AppTransaction> counterpartyTxs,
    required Map<String, int> categoryCounts,
    required List<AppTransaction> filteredTransactions,
    required bool isBalanceVisible,
    required NumberFormat fmt,
  }) {
    final bool isReasonFilter =
        widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty;
    final bool isFiltered = _searchQuery.isNotEmpty ||
        (_selectedBank != 'All' && _selectedBank != 'All Banks') ||
        isCounterpartyView ||
        _selectedType != 'All' ||
        _selectedCategory != 'All' ||
        _selectedSimSlot != null ||
        !_dateFilterValue.isDefault ||
        _isBookmarkedOnly ||
        _sortBy != 'Date: Newest';

    final cleanCounterpartyName = isCounterpartyView
        ? (CounterpartyMatcher.normalize(_selectedCounterparty!).isNotEmpty
            ? CounterpartyMatcher.normalize(_selectedCounterparty!)
            : _selectedCounterparty!)
        : '';

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 10,
        left: 14,
        right: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Clean Back Button + Title + Clear Button
          Row(
            children: [
              const AppBackButton(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCounterpartyView
                          ? cleanCounterpartyName
                          : isReasonFilter
                              ? widget.initialSearchQuery!
                              : 'Transactions',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isCounterpartyView
                          ? '$count transactions with this counterparty'
                          : isReasonFilter
                              ? 'Reason Analysis Detail'
                              : '$count transactions recorded',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (isFiltered)
                AppButton.destructive(
                  text: 'Clear',
                  fullWidth: false,
                  height: 28,
                  fontSize: 11,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedBank = 'All Banks';
                      _selectedCounterparty = null;
                      _selectedType = 'All';
                      _selectedCategory = 'All';
                      _selectedSimSlot = null;
                      _sortBy = 'Date: Newest';
                      _isBookmarkedOnly = false;
                      _dateFilterValue = const AppDateFilterValue.anyTime();
                      _displayLimit = 30;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Standard Search Bar (100% Fully Rounded Pill) ───────────────────
          AppSearchBar(
            mode: AppSearchBarMode.bar,
            controller: _searchController,
            hint: 'Search transactions...',
            height: 46,
            borderRadius: 100,
            onChanged: (value) => setState(() => _searchQuery = value),
            onClear: () => setState(() => _searchQuery = ''),
            backgroundColor: AppColors.surface,
            textColor: AppColors.textPrimary,
            hintColor: AppColors.textSecondary,
            iconColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),

          // ── Selection Filter Chips Horizontal Scroll ────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // ── Active Counterparty Filter Pill (Dismissible) ──
                if (isCounterpartyView) ...[
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedCounterparty = null;
                        _selectedCategory = 'All';
                        _displayLimit = 30;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 15,
                            color: AppColors.brandGreen,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 130),
                            child: Text(
                              cleanCounterpartyName,
                              style: const TextStyle(
                                color: AppColors.brandGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: AppColors.brandGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // ── Bookmark Filter Toggle Pill ──
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isBookmarkedOnly = !_isBookmarkedOnly;
                      _displayLimit = 30;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 36,
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
                                : AppColors.textPrimary,
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

                // ── Sort Dropdown ──
                _buildSortDropdown(),
                const SizedBox(width: 8),

                // ── Date Range Filter ──
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

                // ── Bank / Account Dropdown ──
                _buildBankDropdown(bankNames),
                const SizedBox(width: 8),

                // ── Dynamic SIM Dropdown (Dual-SIM only) ──
                if (txVM.hasMultipleSims) ...[
                  _buildSimDropdown(txVM),
                  const SizedBox(width: 8),
                ],

                // ── Type Dropdown (Income / Expense) ──
                _buildTypeDropdown(),

                // ── Reset Filters Button ──
                if (isFiltered) ...[
                  const SizedBox(width: 8),
                  AppResetFilterButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _isBookmarkedOnly = false;
                        _selectedType = 'All';
                        _selectedCategory = 'All';
                        _selectedSimSlot = null;
                        _dateFilterValue =
                            const AppDateFilterValue.anyTime();
                        _selectedBank = 'All Banks';
                        _selectedCounterparty = null;
                        _sortBy = 'Date: Newest';
                        _searchQuery = '';
                        _displayLimit = 30;
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // ── Counterparty Net Flow Summary Card (When Counterparty Selected) ──
          if (isCounterpartyView) ...[
            const SizedBox(height: 12),
            _buildCounterpartyNetFlowCard(
              filteredTransactions,
              cleanCounterpartyName,
              isBalanceVisible,
              fmt,
            ),
          ],

          // ── Counterparty Categories Horizontal Filter Pills ─────────────────
          if (isCounterpartyView && categoryCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildCounterpartyCategoryPills(
              categoryCounts,
              counterpartyTxs.length,
            ),
          ],
        ],
      ),
    );
  }

  // ── Dynamic Counterparty Net Flow Summary Card ─────────────────────────────
  Widget _buildCounterpartyNetFlowCard(
    List<AppTransaction> txs,
    String counterpartyName,
    bool isBalanceVisible,
    NumberFormat fmt,
  ) {
    final double totalSent = txs
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);
    final double totalReceived = txs
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final double netStanding = totalReceived - totalSent;
    final double totalTurnover = totalSent + totalReceived;
    final double sentRatio = totalTurnover > 0
        ? (totalSent / totalTurnover).clamp(0.0, 1.0)
        : 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 14,
                    color: AppColors.textSoft,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Net Standing (${_dateFilterValue.label})',
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (netStanding > 0)
                const AppBadge.success(
                  text: 'Net From',
                  size: AppBadgeSize.micro,
                )
              else if (netStanding < 0)
                const AppBadge.destructive(
                  text: 'Net To',
                  size: AppBadgeSize.micro,
                )
              else
                const AppBadge.neutral(
                  text: 'Even',
                  size: AppBadgeSize.micro,
                ),
            ],
          ),
          const SizedBox(height: 4),
          CurrencyTextWidget(
            amount: netStanding,
            showSign: true,
            style: TextStyle(
              color: netStanding >= 0
                  ? AppColors.positive
                  : AppColors.negative,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            customFormattedStr: fmt.format(netStanding.abs()),
          ),
          const SizedBox(height: 8),

          // Distribution Ratio Bar
          CustomProgressBar(
            progress: sentRatio,
            height: 6,
            backgroundColor: AppColors.positive.withValues(alpha: 0.3),
            progressColor: AppColors.negative,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To: ETB ${fmt.format(totalSent)} (${(sentRatio * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppColors.negative,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'From: ETB ${fmt.format(totalReceived)} (${((1.0 - sentRatio) * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppColors.positive,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Counterparty Category Filter Pills ─────────────────────────────────────
  Widget _buildCounterpartyCategoryPills(
    Map<String, int> categoryCounts,
    int totalCount,
  ) {
    final sortedCategories = categoryCounts.keys.toList()
      ..sort((a, b) =>
          (categoryCounts[b] ?? 0).compareTo(categoryCounts[a] ?? 0));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // "All" Pill
          _buildCategoryPill(
            label: 'All Categories',
            count: totalCount,
            isSelected: _selectedCategory == 'All',
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedCategory = 'All';
                _displayLimit = 30;
              });
            },
          ),
          const SizedBox(width: 6),

          // Category Pills
          for (final cat in sortedCategories) ...[
            _buildCategoryPill(
              label: cat,
              count: categoryCounts[cat] ?? 0,
              isSelected: _selectedCategory == cat,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = _selectedCategory == cat ? 'All' : cat;
                  _displayLimit = 30;
                });
              },
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.buttonPrimary
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? AppColors.buttonPrimaryText
                    : AppColors.textPrimary,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.buttonPrimaryText.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.buttonPrimaryText
                      : AppColors.textSecondary,
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

  Widget _buildSortDropdown() {
    return AppDropdown.simple(
      value: _sortBy,
      items: const [
        'Date: Newest',
        'Date: Oldest',
        'Amount: High-Low',
        'Amount: Low-High',
        'Name: A-Z',
      ],
      onChanged: (val) {
        if (val != null) {
          setState(() {
            _sortBy = val;
            _displayLimit = 30;
          });
        }
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 130,
      borderRadius: 100,
      prefix: Icon(
        Icons.sort_rounded,
        size: 14,
        color:
            _sortBy != 'Date: Newest' ? Colors.white : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildBankDropdown(List<String> bankNames) {
    return AppDropdown.simple(
      value: _selectedBank,
      items: bankNames,
      onChanged: (name) {
        if (name != null) {
          setState(() {
            _selectedBank = name;
            _displayLimit = 30;
          });
        }
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 130,
      borderRadius: 100,
      prefix: Icon(
        Icons.account_balance_wallet_rounded,
        size: 14,
        color: (_selectedBank != 'All' && _selectedBank != 'All Banks')
            ? Colors.white
            : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return AppDropdown.simple(
      value: _selectedType,
      items: const ['All', 'Income', 'Expense'],
      onChanged: (type) {
        if (type != null) {
          setState(() {
            _selectedType = type;
            _displayLimit = 30;
          });
        }
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 100,
      borderRadius: 100,
      prefix: Icon(
        Icons.swap_vert_rounded,
        size: 14,
        color:
            _selectedType != 'All' ? Colors.white : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSimDropdown(TransactionsViewModel txVM) {
    return AppDropdown<int?>.dark(
      value: _selectedSimSlot,
      items: [
        const AppDropdownItem(value: null, label: 'All SIMs'),
        ...txVM.detectedSimSlots.map((slot) {
          final sim =
              txVM.simCards.where((s) => s.simSlot == slot).firstOrNull;
          final label = (sim != null && sim.displayName.isNotEmpty)
              ? 'SIM ${slot + 1} (${sim.displayName})'
              : 'SIM ${slot + 1}';
          return AppDropdownItem<int?>(value: slot, label: label);
        }),
      ],
      onChanged: (val) {
        setState(() {
          _selectedSimSlot = val;
          _displayLimit = 30;
        });
      },
      maxWidth: 130,
      isDefault: _selectedSimSlot == null,
    );
  }

  // ── Standard Cardless Transaction List ─────────────────────────────────────
  Widget _buildTransactionList(
    List<AppTransaction> transactions,
    SettingsViewModel settingsVM,
  ) {
    if (transactions.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 60, bottom: 40),
          child: AppEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Transactions Found',
            subtitle: _searchQuery.isNotEmpty ||
                    (_selectedBank != 'All' && _selectedBank != 'All Banks') ||
                    _selectedCounterparty != null ||
                    _selectedCategory != 'All' ||
                    _selectedType != 'All' ||
                    !_dateFilterValue.isDefault ||
                    _isBookmarkedOnly
                ? 'Try adjusting your filters or search terms to see matching records.'
                : 'No transactions recorded within the active scan range (${settingsVM.scanWindowOption.title}).',
          ),
        ),
      );
    }

    final hasMore = transactions.length > _displayLimit;
    final displayedTransactions = transactions.take(_displayLimit).toList();

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: displayedTransactions.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.04),
        indent: 68,
      ),
      itemBuilder: (context, index) {
        if (index == displayedTransactions.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppButton.secondary(
              text:
                  'Load More (+${min(30, transactions.length - _displayLimit)})',
              icon: Icons.expand_more_rounded,
              height: 44,
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _displayLimit += 30;
                });
              },
            ),
          );
        }
        final tx = displayedTransactions[index];
        final bool isLatest = index == 0;
        return _buildTransactionRowItem(context, tx, settingsVM, isLatest);
      },
    );
  }

  Widget _buildTransactionRowItem(
    BuildContext context,
    AppTransaction tx,
    SettingsViewModel settingsVM,
    bool isLatest,
  ) {
    final bool isIncome = tx.type == 'income';
    final String label = isIncome ? 'Income' : 'Expense';
    final String subLabel =
        isIncome ? 'From ${tx.counterparty}' : 'To ${tx.counterparty}';
    final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
    final bool hasReason = tx.reasonId != null ||
        (tx.customReasonText != null &&
            tx.customReasonText!.trim().isNotEmpty) ||
        (tx.reason != null && tx.reason!.trim().isNotEmpty) ||
        txVM.hasSplits(tx.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionDetailScreen(transaction: tx),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildDarkBankAvatar(tx.bankName),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tx.isBookmarked)
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0),
                            child: BookmarkBadge(),
                          ),
                        if (txVM.accountsForBank(tx.bankName).length > 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 6.0),
                            child: SimBadge(simSlot: tx.simSlot),
                          ),
                        if (tx.isAutoDetected && isLatest && !hasReason)
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0),
                            child: NewBadge(),
                          ),
                        if (!hasReason)
                          const Padding(
                            padding: EdgeInsets.only(left: 6.0),
                            child: ReasonBadge(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(tx.date),
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ETB ${NumberFormat('#,##0.00').format(tx.amount)}',
                    style: TextStyle(
                      color: isIncome ? AppColors.positive : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (tx.totalBalance > 0) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Bal: ETB ${NumberFormat('#,##0.00').format(tx.totalBalance)}',
                      style: const TextStyle(
                        color: AppColors.textDisabled,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkBankAvatar(String bankName) {
    return BankAvatar(bankName: bankName, size: 42, iconSize: 22);
  }
}
