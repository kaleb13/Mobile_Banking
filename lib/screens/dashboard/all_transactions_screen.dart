import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_date_filter.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../widgets/app_empty_state.dart';
import '../../domain/usecases/transactions/filter_transactions_usecase.dart';
import 'transaction_detail_screen.dart';

class AllTransactionsScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialSenderFilter;

  const AllTransactionsScreen({
    super.key,
    this.initialSearchQuery,
    this.initialSenderFilter,
  });

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  late String _selectedSender;
  AppDateFilterValue _dateFilterValue = const AppDateFilterValue.anyTime();
  String _selectedType = 'All';
  bool _isBookmarkedOnly = false;
  String _sortBy = 'Date: Newest';

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _selectedSender = widget.initialSenderFilter ?? 'All';
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

    // Unique sender / bank names for the dropdown
    final Set<String> senderNamesSet = {
      'All',
      ...txVM.senders.map((s) => s.senderName),
    };
    if (_selectedSender != 'All') {
      senderNamesSet.add(_selectedSender);
    }
    final senderNames = senderNamesSet.toList();

    final isBank = txVM.senders.any(
      (s) => s.senderName.trim().toUpperCase() == _selectedSender.trim().toUpperCase(),
    );

    // Filter logic using domain usecase
    final filteredTransactions = const FilterTransactionsUseCase().execute(
      transactions: allTransactions,
      params: FilterTransactionsParams(
        bankFilter: isBank ? _selectedSender : null,
        senderFilter: !isBank && _selectedSender != 'All' ? _selectedSender : null,
        typeFilter: _selectedType,
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
              senderNames,
              filteredTransactions.length,
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
    List<String> senderNames,
    int count,
  ) {
    final bool isReasonFilter =
        widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty;
    final bool isFiltered = _searchQuery.isNotEmpty ||
        _selectedSender != 'All' ||
        _selectedType != 'All' ||
        !_dateFilterValue.isDefault ||
        _isBookmarkedOnly ||
        _sortBy != 'Date: Newest';

    return Container(
      color: AppColors.background,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
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
                      isReasonFilter ? widget.initialSearchQuery! : 'Transactions',
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
                      isReasonFilter
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _selectedSender = 'All';
                      _selectedType = 'All';
                      _sortBy = 'Date: Newest';
                      _isBookmarkedOnly = false;
                      _dateFilterValue = const AppDateFilterValue.anyTime();
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 12),

          // ── Selection Filter Chips Horizontal Scroll ────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // ── Bookmark Filter Toggle Pill ──
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _isBookmarkedOnly = !_isBookmarkedOnly;
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
                    setState(() => _dateFilterValue = val);
                  },
                ),
                const SizedBox(width: 8),

                // ── Sender / Account Dropdown ──
                _buildSenderDropdown(senderNames),
                const SizedBox(width: 8),

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
                        _dateFilterValue = const AppDateFilterValue.anyTime();
                        _selectedSender = 'All';
                        _sortBy = 'Date: Newest';
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
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
        if (val != null) setState(() => _sortBy = val);
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 130,
      borderRadius: 100,
      prefix: Icon(
        Icons.sort_rounded,
        size: 14,
        color: _sortBy != 'Date: Newest' ? Colors.white : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSenderDropdown(List<String> senderNames) {
    return AppDropdown.simple(
      value: _selectedSender,
      items: senderNames,
      onChanged: (name) {
        if (name != null) setState(() => _selectedSender = name);
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 120,
      borderRadius: 100,
      prefix: Icon(
        Icons.account_balance_wallet_rounded,
        size: 14,
        color: _selectedSender != 'All' ? Colors.white : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return AppDropdown.simple(
      value: _selectedType,
      items: const ['All', 'Income', 'Expense'],
      onChanged: (type) {
        if (type != null) setState(() => _selectedType = type);
      },
      variant: AppDropdownVariant.dark,
      maxWidth: 100,
      borderRadius: 100,
      prefix: Icon(
        Icons.swap_vert_rounded,
        size: 14,
        color: _selectedType != 'All' ? Colors.white : AppColors.textSecondary,
      ),
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
          padding: const EdgeInsets.only(top: 80, bottom: 40),
          child: AppEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No transactions found',
            subtitle: 'Try adjusting your filters or search query',
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.5,
        indent: 66,
        endIndent: 16,
        color: Colors.white.withValues(alpha: 0.05),
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _buildTransactionRowItem(context, tx, settingsVM);
      },
    );
  }

  Widget _buildTransactionRowItem(
    BuildContext context,
    AppTransaction tx,
    SettingsViewModel settingsVM,
  ) {
    final bool isIncome = tx.type == 'income';
    final String label = isIncome ? 'Deposit' : 'Transferred';
    final String subLabel = isIncome ? 'From ${tx.sender}' : 'To ${tx.sender}';

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
              _buildDarkBankAvatar(tx.name),
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
                        if (tx.reasonId == null &&
                            (tx.customReasonText == null ||
                                tx.customReasonText!.isEmpty) &&
                            (tx.reason == null || tx.reason!.isEmpty))
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
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAmountText(tx, settingsVM),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, HH:mm').format(tx.date),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkBankAvatar(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    Color bgColor = AppColors.buttonSecondary;

    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL')) {
      img = Image.asset(
        'assets/images/CBE logo 1.webp',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cbePurple.withValues(alpha: 0.20);
    } else if (nameUp == 'TELEBIRR') {
      img = Image.asset(
        'assets/images/Telebirr Logo.png',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.telebirrGreen.withValues(alpha: 0.20);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset(
        'assets/images/CBEBirr Logo.png',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cbeBirrMagenta.withValues(alpha: 0.20);
    } else if (nameUp.contains('AHADU')) {
      img = SvgPicture.asset(
        'assets/images/Ahadu_Logo.svg',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cardAhaduRed.withValues(alpha: 0.20);
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      img = SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      img = SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      bgColor = AppColors.cardDashenDark.withValues(alpha: 0.35);
    } else if (nameUp.contains('CASH')) {
      img = SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: 18,
        height: 18,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.positive, BlendMode.srcIn),
      );
      bgColor = AppColors.positive.withValues(alpha: 0.15);
    } else {
      img = Text(
        bankName.substring(0, min(1, bankName.length)).toUpperCase(),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: img),
    );
  }

  Widget _buildAmountText(AppTransaction tx, SettingsViewModel settingsVM) {
    if (!settingsVM.isBalanceVisible) {
      return const Text(
        '••••••••',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final String amountStr = NumberFormat('#,##0.00').format(tx.amount);
    final amountParts = amountStr.split('.');

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${tx.type == 'income' ? '+' : '-'}${amountParts[0]}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '.${amountParts[1]}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
