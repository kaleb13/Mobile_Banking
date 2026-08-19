import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../models/transaction.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_date_filter.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../domain/usecases/transactions/filter_transactions_usecase.dart';
import 'transaction_detail_screen.dart';
import 'dart:math';

class TransactionSearchScreen extends StatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  State<TransactionSearchScreen> createState() =>
      _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends State<TransactionSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _typeFilter = 'All';
  bool _isBookmarkedOnly = false;
  AppDateFilterValue _dateFilterValue = const AppDateFilterValue.anyTime();
  String _senderFilter = 'All Senders';
  String _bankFilter = 'All Banks';
  String _sortBy = 'Date: Newest';

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _isBookmarkedOnly ||
      _typeFilter != 'All' ||
      _sortBy != 'Date: Newest' ||
      !_dateFilterValue.isDefault ||
      _senderFilter != 'All Senders' ||
      _bankFilter != 'All Banks';

  void _clearAllFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _isBookmarkedOnly = false;
      _typeFilter = 'All';
      _sortBy = 'Date: Newest';
      _dateFilterValue = const AppDateFilterValue.anyTime();
      _senderFilter = 'All Senders';
      _bankFilter = 'All Banks';
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final allTransactions = provider.transactions;
    final allSenders = ['All Senders'];
    allSenders
        .addAll(allTransactions.map((t) => t.sender).toSet().toList()..sort());

    if (!allSenders.contains(_senderFilter)) {
      _senderFilter = 'All Senders';
    }

    final allBanks = ['All Banks'];
    allBanks
        .addAll(allTransactions.map((t) => t.name).toSet().toList()..sort());

    if (!allBanks.contains(_bankFilter)) {
      _bankFilter = 'All Banks';
    }

    final filteredTransactions = const FilterTransactionsUseCase().execute(
      transactions: allTransactions,
      params: FilterTransactionsParams(
        bankFilter: _bankFilter,
        senderFilter: _senderFilter,
        typeFilter: _typeFilter,
        dateFilter: _dateFilterValue,
        searchQuery: _searchQuery,
        sortBy: _sortBy,
        onlyBookmarked: _isBookmarkedOnly,
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildSearchHeader(context),
              _buildFilterRow(allSenders, allBanks),
              const SizedBox(height: 6),
              Expanded(
                child: !_hasActiveFilters && filteredTransactions.isEmpty
                    ? _buildInitialState()
                    : _buildSearchResults(filteredTransactions, provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.lightGreyBackground,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.darkCharcoal,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AppSearchBar(
              mode: AppSearchBarMode.bar,
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              hint: 'Search by sender, bank, or reason...',
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
              backgroundColor: AppColors.lightGreyBackground,
              textColor: AppColors.darkCharcoal,
              hintColor: AppColors.greyText,
              iconColor: AppColors.darkGreyText,
              height: 44,
              borderRadius: 22,
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearAllFilters,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lightGreyBackground,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                    color: AppColors.negative,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterRow(List<String> senders, List<String> banks) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // ── Bookmark Toggle Filter Pill ──
            GestureDetector(
              onTap: () {
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
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : AppColors.lightGreyBackground,
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
                          : AppColors.darkGreyText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Bookmarked',
                      style: TextStyle(
                        color: _isBookmarkedOnly
                            ? AppColors.gold
                            : AppColors.darkCharcoal,
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
            _buildWhiteFilterDropdown(
              value: _sortBy,
              items: const [
                'Date: Newest',
                'Date: Oldest',
                'Amount: High-Low',
                'Amount: Low-High',
                'Name: A-Z',
              ],
              maxWidth: 130,
              onChanged: (val) {
                if (val != null) setState(() => _sortBy = val);
              },
            ),
            const SizedBox(width: 8),
            _buildWhiteFilterDropdown(
              value: _typeFilter,
              items: const ['All', 'Incoming', 'Outgoing'],
              onChanged: (val) {
                if (val != null) setState(() => _typeFilter = val);
              },
            ),
            const SizedBox(width: 8),
            AppDateFilter.light(
              value: _dateFilterValue,
              onChanged: (val) {
                setState(() => _dateFilterValue = val);
              },
            ),
            const SizedBox(width: 8),
            _buildWhiteFilterDropdown(
              value: _bankFilter,
              items: banks,
              maxWidth: 90,
              onChanged: (val) {
                if (val != null) setState(() => _bankFilter = val);
              },
            ),
            const SizedBox(width: 8),
            _buildWhiteFilterDropdown(
              value: _senderFilter,
              items: senders,
              maxWidth: 100,
              onChanged: (val) {
                if (val != null) setState(() => _senderFilter = val);
              },
            ),
            if (_isBookmarkedOnly ||
                _typeFilter != 'All' ||
                !_dateFilterValue.isDefault ||
                _bankFilter != 'All Banks' ||
                _senderFilter != 'All Senders' ||
                _sortBy != 'Date: Newest') ...[
              const SizedBox(width: 8),
              AppResetFilterButton(
                onTap: () {
                  setState(() {
                    _isBookmarkedOnly = false;
                    _typeFilter = 'All';
                    _dateFilterValue = const AppDateFilterValue.anyTime();
                    _bankFilter = 'All Banks';
                    _senderFilter = 'All Senders';
                    _sortBy = 'Date: Newest';
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? maxWidth,
  }) {
    return AppDropdown.simple(
      value: value,
      items: items,
      onChanged: onChanged,
      variant: AppDropdownVariant.light,
      maxWidth: maxWidth,
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 56,
            color: AppColors.mediumGreyText.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          const Text(
            'Search by name, amount, or reason',
            style: TextStyle(
              color: AppColors.mediumGreyText,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
      List<AppTransaction> transactions, FinanceProvider provider) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.mediumGreyText.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            const Text(
              'No transactions found',
              style: TextStyle(
                color: AppColors.greyText,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 72,
        endIndent: 20,
        color: AppColors.lightGreySurface,
      ),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final bool isLatest = index == 0;
        return _buildWhiteTransactionItem(context, tx, isLatest);
      },
    );
  }

  Widget _buildWhiteTransactionItem(
      BuildContext context, AppTransaction tx, bool isLatest) {
    final bool isIncome = tx.type == 'income';
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final String amountStr = provider.isBalanceVisible
        ? NumberFormat('#,##0.1').format(tx.amount)
        : '****';
    final String label = isIncome ? 'Deposit' : 'Transferred';
    final subLabel = isIncome ? 'From ${tx.sender}' : 'To ${tx.sender}';

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: tx),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        color: Colors.white,
        child: Row(
          children: [
            _buildBankAvatarSmallWhite(tx.name),
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
                            color: AppColors.darkCharcoal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (tx.isBookmarked)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: BookmarkBadge(),
                        ),
                      if (tx.isAutoDetected && isLatest)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: NewBadge(),
                        ),
                      if (tx.reasonId == null &&
                          (tx.customReasonText == null ||
                              tx.customReasonText!.isEmpty) &&
                          (tx.reason == null || tx.reason!.isEmpty))
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: ReasonBadge(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: const TextStyle(
                      color: AppColors.mediumGreyText,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${isIncome ? '+' : '-'}$amountStr',
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, HH:mm').format(tx.date),
                  style: const TextStyle(
                    color: AppColors.mediumGreyText,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAvatarSmallWhite(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    Color bgColor = AppColors.lightGreyBackground;

    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL')) {
      img = Image.asset('assets/images/CBE logo 1.webp', width: 22, height: 22);
      bgColor = AppColors.slackPurple.withValues(alpha: 0.12);
    } else if (nameUp == 'TELEBIRR') {
      img = Image.asset(
        'assets/images/Telebirr Logo.png',
        width: 22,
        height: 22,
        color: AppColors.telebirrGreen,
        colorBlendMode: BlendMode.srcIn,
      );
      bgColor = AppColors.telebirrGreenSoft;
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
      bgColor = AppColors.cbeBirrPink.withValues(alpha: 0.10);
    } else if (nameUp.contains('AHADU')) {
      img = SvgPicture.asset('assets/images/Ahadu_Logo.svg',
          width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cardAhaduRed.withValues(alpha: 0.10);
    } else if (nameUp.contains('ABYSSINIA') ||
        nameUp == 'BOA' ||
        nameUp.contains('BOA')) {
      img = SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg',
          width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      img = SvgPicture.asset('assets/images/Dashen_Bank_Logo.svg',
          width: 25, height: 25, fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(AppColors.cardDashenDark, BlendMode.srcIn));
      bgColor = AppColors.cardDashenLight.withValues(alpha: 0.15);
    } else if (nameUp.contains('CASH')) {
      img = SvgPicture.asset('assets/images/Wallet Icon.svg',
          width: 20, height: 20, fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(AppColors.positive, BlendMode.srcIn));
      bgColor = AppColors.positive.withValues(alpha: 0.12);
    } else {
      img = Text(
        bankName.substring(0, min(1, bankName.length)).toUpperCase(),
        style: const TextStyle(
            color: AppColors.darkCharcoal,
            fontSize: 11,
            fontWeight: FontWeight.bold),
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
}
