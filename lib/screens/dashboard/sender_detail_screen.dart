import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../widgets/interactive_balance_chart.dart';
import 'manual_transaction_sheet.dart';
import '../../models/sender.dart';
import '../../models/transaction.dart';
import '../../models/scan_window_option.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../widgets/bank_card_widget.dart';
import 'bank_detail/bank_detail_header.dart';
import 'transaction_detail_screen.dart';
import 'analysis_screen.dart';

class SenderDetailScreen extends StatefulWidget {
  final AppSender sender;

  const SenderDetailScreen({super.key, required this.sender});

  @override
  State<SenderDetailScreen> createState() => _SenderDetailScreenState();
}

class _SenderDetailScreenState extends State<SenderDetailScreen> {
  String _chartFilter = '30D'; // 1D, 7D, 30D, 180D, 360D
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Income, Expense
  String _senderFilter = 'All Senders';
  bool _isBookmarkedOnly = false;
  String _sortBy = 'Date: Newest';
  String _dateRangeFilter = 'All Time'; // Default to All Time so multi-SIM history is visible
  int _displayLimit = 30; // Progressive virtualized page limit
  final TextEditingController _searchController = TextEditingController();
  bool _isChartVisible = false;
  int _selectedAccountIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPNLInfo(BuildContext context) {
    AppDrawer.show(
      context: context,
      builder: (context) {
        return AppDrawer(
          headerCard: const AppDrawerHeaderCard(
            icon: Icons.analytics_outlined,
            title: "30D PnL",
          ),
          bottomAction: AppButton.primary(
            text: "OK",
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "This 30-Day Profit or Loss calculation for this specific account = (Income) - (Expense) over the last 30 days.\n\nIt reflects the recent net performance of this wallet or account.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;

    // Get latest sender info from provider to reflect linked status
    final currentSender = txVM.senders.firstWhere(
      (s) => s.id == widget.sender.id,
      orElse: () => widget.sender,
    );

    // Multi-Account / Dual-SIM items detection via ViewModel
    final accountItems = txVM.getBankDetailAccounts(widget.sender.senderName);

    if (_selectedAccountIndex >= accountItems.length && accountItems.isNotEmpty) {
      _selectedAccountIndex = 0;
    }

    final rawBankTx = txVM.transactionsForSender(widget.sender.senderName);
    final allTxForSender = (accountItems.isNotEmpty && _selectedAccountIndex > 0)
        ? rawBankTx.where((tx) {
            final targetSlot = accountItems[_selectedAccountIndex].simSlot;
            return targetSlot == null || tx.simSlot == targetSlot;
          }).toList()
        : rawBankTx;

    final uniqueSenders = allTxForSender
        .map((tx) => tx.sender.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final senderOptions = ['All Senders', ...uniqueSenders];
    if (!senderOptions.contains(_senderFilter)) {
      _senderFilter = 'All Senders';
    }

    // Filter transactions for listing & search
    final filteredTransactions = allTxForSender.where((tx) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          tx.sender.toLowerCase().contains(q) ||
          (tx.resolvedReason?.toLowerCase().contains(q) ?? false) ||
          tx.amount.toString().contains(q) ||
          (tx.bankReference?.toLowerCase().contains(q) ?? false);

      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Income' && tx.type == 'income') ||
          (_typeFilter == 'Expense' && tx.type != 'income');

      final matchesSender = _senderFilter == 'All Senders' ||
          tx.sender.trim().toLowerCase() == _senderFilter.trim().toLowerCase();

      final matchesBookmark = !_isBookmarkedOnly || tx.isBookmarked;

      bool matchesDateRange = true;
      final now = DateTime.now();
      if (_dateRangeFilter == '7D') {
        matchesDateRange =
            tx.date.isAfter(now.subtract(const Duration(days: 7)));
      } else if (_dateRangeFilter == '30D') {
        matchesDateRange =
            tx.date.isAfter(now.subtract(const Duration(days: 30)));
      } else if (_dateRangeFilter == '90D') {
        matchesDateRange =
            tx.date.isAfter(now.subtract(const Duration(days: 90)));
      } else if (_dateRangeFilter == '1Y') {
        matchesDateRange =
            tx.date.isAfter(now.subtract(const Duration(days: 365)));
      }

      return matchesSearch &&
          matchesType &&
          matchesSender &&
          matchesBookmark &&
          matchesDateRange;
    }).toList();

    // Sort transactions
    if (_sortBy == 'Date: Oldest') {
      filteredTransactions.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == 'Amount: High-Low') {
      filteredTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'Amount: Low-High') {
      filteredTransactions.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      // Default: Date: Newest
      filteredTransactions.sort((a, b) => b.date.compareTo(a.date));
    }

    // Calculate Balance & Trends
    final double currentBalance = (accountItems.isNotEmpty && _selectedAccountIndex > 0)
        ? accountItems[_selectedAccountIndex].balance
        : txVM.balanceForSender(widget.sender.senderName);

    // Trend calculation
    double monthChange = 0;
    double monthPercent = 0;
    if (allTxForSender.isNotEmpty) {
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final thisMonthTx =
          allTxForSender.where((tx) => tx.date.isAfter(thirtyDaysAgo)).toList();
      for (var tx in thisMonthTx) {
        if (tx.type == 'income') {
          monthChange += tx.amount;
        } else {
          monthChange -= tx.amount;
        }
      }
      if (currentBalance != 0) {
        monthPercent =
            (monthChange / (currentBalance - monthChange).abs()) * 100;
        if (monthPercent.isInfinite || monthPercent.isNaN) monthPercent = 0;
      }
    }
    final int? activeSimSlot = (accountItems.isNotEmpty && _selectedAccountIndex > 0)
        ? accountItems[_selectedAccountIndex].simSlot
        : null;
    final double telebirrSavings = txVM.telebirrSavingBalanceForAccount(activeSimSlot);

    final String senderName = widget.sender.senderName;
    final activeSenders = txVM.activeSenders;
    final int topDeckIndex = activeSenders.isNotEmpty
        ? (activeSenders.length.clamp(1, 3) - 1)
        : -1;
    final int senderIndex = activeSenders.indexWhere(
        (s) => s.senderName.toUpperCase() == senderName.toUpperCase());
    final bool isTopCard =
        (senderIndex >= 0 && senderIndex == topDeckIndex);
    final bool isDarkTextTheme =
        BankCardWidget.isDarkTextTheme(senderName, isTopCard: isTopCard);

    final Brightness iconBrightness =
        isDarkTextTheme ? Brightness.dark : Brightness.light;
    final Brightness iosBrightness =
        isDarkTextTheme ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iosBrightness,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.background,
                AppColors.bgMid,
              ],
            ),
          ),
          child: RefreshIndicator(
            color: AppColors.brandGreen,
            backgroundColor: AppColors.surfaceElevated,
            onRefresh: () async {
              final activeOption = context.read<SettingsViewModel>().scanWindowOption;
              await txVM.refreshBankData(
                bankName: widget.sender.senderName,
                scanWindowOption: activeOption,
              );
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // ── Dynamic Collapsing Interactive Bank Card Header ──
                SliverPersistentHeader(
                  pinned: true,
                  delegate: BankDetailHeaderDelegate(
                    sender: currentSender,
                    topSafeArea: topSafeArea,
                    currentBalance: currentBalance,
                    monthChange: monthChange,
                    monthPercent: monthPercent,
                    txCount: allTxForSender.length,
                    isChartVisible: _isChartVisible,
                    accounts: accountItems,
                    selectedAccountIndex: _selectedAccountIndex,
                    onAccountChanged: (idx) =>
                        setState(() => _selectedAccountIndex = idx),
                    onToggleAccountPause: (idx) async {
                      if (idx > 0 && idx < accountItems.length) {
                        final slot = accountItems[idx].simSlot;
                        if (slot != null) {
                          await txVM.toggleAccountPause(
                              widget.sender.senderName, slot);
                        }
                      }
                    },
                    onAddTransaction: () {
                      AppBottomSheet.show(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => ManualTransactionSheet(
                          txVM: txVM,
                          initialSender: widget.sender,
                        ),
                      );
                    },
                    onAnalytics: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalysisScreen(
                            initialBankFilter: widget.sender.senderName,
                          ),
                        ),
                      );
                    },
                    onShowPnlInfo: () => _showPNLInfo(context),
                    onCredentials: () => _showRefreshChooser(context, txVM),
                    onToggleChart: () => setState(() => _isChartVisible = !_isChartVisible),
                  ),
                ),

                // ── Extra Bank Details (Telebirr Savings, Charts, Filters) ──
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      if (widget.sender.senderName.toUpperCase() == 'TELEBIRR' &&
                          telebirrSavings > 0)
                        _buildTelebirrSavingSummaryCard(
                          telebirrSavings,
                          activeSimSlot,
                        ),
                      if (_isChartVisible) ...[
                        const SizedBox(height: 8),
                        InteractiveBalanceChart(
                          transactions: allTxForSender,
                          initialFilter: _chartFilter,
                          isBalanceVisible: settingsVM.isBalanceVisible,
                          chartHeight: 140,
                          onFilterChanged: (val) =>
                              setState(() => _chartFilter = val),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildActivityFilterSection(
                        filteredTransactions.length,
                        senderOptions,
                      ),
                    ],
                  ),
                ),

                // ── Transaction List (Virtualized SliverList with Lazy Loading) ──
                _buildTransactionSliverList(filteredTransactions),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Summary card for Telebirr Savings (Sanduq) when savings balance exists
  Widget _buildTelebirrSavingSummaryCard(double savingBalance, [int? activeSimSlot]) {
    final fmt = NumberFormat('#,##0.00');
    final settingsVM = context.watch<SettingsViewModel>();
    final String subtitle = activeSimSlot != null
        ? 'SIM ${activeSimSlot + 1} savings vault'
        : 'High-yield savings vault';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.telebirrGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_rounded,
                color: AppColors.telebirrGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Telebirr Sanduq (Savings)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (activeSimSlot != null) ...[
                        const SizedBox(width: 6),
                        SimBadge(simSlot: activeSimSlot),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            settingsVM.isBalanceVisible
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmt.format(savingBalance),
                        style: const TextStyle(
                          color: AppColors.telebirrGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const CurrencySymbolWidget(
                        color: AppColors.telebirrGreen,
                        size: 13,
                      ),
                    ],
                  )
                : const Text(
                    '••••••••',
                    style: TextStyle(
                      color: AppColors.telebirrGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ],
        ),
      );
  }

  /// Lets the user pick how far back to re-scan SMS for this bank, synchronized with the active scan range.
  void _showRefreshChooser(BuildContext context, TransactionsViewModel txVM) {
    final settingsVM = context.read<SettingsViewModel>();
    final activeScanOption = settingsVM.scanWindowOption;
    final bankName = widget.sender.senderName;

    Future<void> runRefresh(ScanWindowOption option) async {
      final rangeLabel = option == ScanWindowOption.allTime
          ? 'all historical records'
          : option.title.toLowerCase();
      AppToast.info(
        context,
        message: 'Rescanning $bankName SMS',
        subtitle: 'Refreshing $bankName transactions from $rangeLabel…',
        duration: const Duration(seconds: 2),
      );
      await txVM.refreshBankData(
        bankName: bankName,
        scanWindowOption: option,
      );
      if (!context.mounted) return;
      AppToast.success(
        context,
        message: 'Sync Complete',
        subtitle: 'Refreshed $bankName transactions ($rangeLabel)',
      );
    }

    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        Widget optionWidget({
          required IconData icon,
          required String title,
          required String subtitle,
          required ScanWindowOption option,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.pop(sheetCtx);
              runRefresh(option);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.drawerCard,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }

        final List<Widget> optionWidgets = [];

        optionWidgets.add(optionWidget(
          icon: Icons.today_rounded,
          title: 'Today only',
          subtitle: 'Recent 24 hours of $bankName messages',
          option: ScanWindowOption.todayOnly,
        ));

        if (activeScanOption != ScanWindowOption.todayOnly) {
          optionWidgets.add(optionWidget(
            icon: Icons.history_rounded,
            title: 'Past 7 days',
            subtitle: 'Recent $bankName messages',
            option: ScanWindowOption.sevenDays,
          ));
        }

        if (activeScanOption == ScanWindowOption.thirtyDays ||
            activeScanOption == ScanWindowOption.ninetyDays ||
            activeScanOption == ScanWindowOption.allTime) {
          optionWidgets.add(optionWidget(
            icon: Icons.date_range_rounded,
            title: 'Last 30 days',
            subtitle: 'Past 1 month of $bankName records',
            option: ScanWindowOption.thirtyDays,
          ));
        }

        if (activeScanOption == ScanWindowOption.ninetyDays ||
            activeScanOption == ScanWindowOption.allTime) {
          optionWidgets.add(optionWidget(
            icon: Icons.calendar_month_rounded,
            title: 'Last 90 days',
            subtitle: 'Past 3 months of $bankName records',
            option: ScanWindowOption.ninetyDays,
          ));
        }

        if (activeScanOption == ScanWindowOption.allTime) {
          optionWidgets.add(optionWidget(
            icon: Icons.all_inclusive_rounded,
            title: 'All Time',
            subtitle: 'Complete all historical $bankName records',
            option: ScanWindowOption.allTime,
          ));
        }

        return AppDrawer(
          headerCard: AppDrawerHeaderCard(
            icon: Icons.refresh_rounded,
            title: 'Refresh $bankName',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: optionWidgets,
          ),
        );
      },
    );
  }

  Widget _buildActivityFilterSection(
      int totalCount, List<String> senderOptions) {
    final hasActiveFilters = _isBookmarkedOnly ||
        _typeFilter != 'All' ||
        _senderFilter != 'All Senders' ||
        _dateRangeFilter != 'All Time' ||
        _sortBy != 'Date: Newest' ||
        _searchQuery.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal Scrollable Filter Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildBookmarkFilterPill(),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _typeFilter,
                items: const ['All', 'Income', 'Expense'],
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
              _buildFilterDropdown(
                value: _senderFilter,
                items: senderOptions,
                maxWidth: 140,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _senderFilter = val;
                      _displayLimit = 30;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _sortBy,
                items: const [
                  'Date: Newest',
                  'Date: Oldest',
                  'Amount: High-Low',
                  'Amount: Low-High',
                ],
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
              _buildFilterDropdown(
                value: _dateRangeFilter,
                items: const ['30D', '7D', '90D', '1Y', 'All Time'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _dateRangeFilter = val;
                      _displayLimit = 30;
                    });
                  }
                },
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                AppResetFilterButton(
                  onTap: () {
                    setState(() {
                      _isBookmarkedOnly = false;
                      _typeFilter = 'All';
                      _senderFilter = 'All Senders';
                      _dateRangeFilter = 'All Time';
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
        const SizedBox(height: 18),

        // Header Label with Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVITY ($totalCount)',
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (hasActiveFilters)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text(
                    'Filtered',
                    style: TextStyle(
                      color: AppColors.positive,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildBookmarkFilterPill() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isBookmarkedOnly = !_isBookmarkedOnly;
          _displayLimit = 30;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
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
              size: 14,
              color: _isBookmarkedOnly ? AppColors.gold : AppColors.textSoft,
            ),
            const SizedBox(width: 6),
            Text(
              'Bookmarked',
              style: TextStyle(
                color:
                    _isBookmarkedOnly ? AppColors.gold : AppColors.textSoft,
                fontSize: 11.5,
                fontWeight:
                    _isBookmarkedOnly ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? maxWidth,
  }) {
    return AppDropdown.simple(
      value: value,
      items: items,
      onChanged: onChanged,
      variant: AppDropdownVariant.dark,
      maxWidth: maxWidth,
    );
  }

  String _getDateHeaderLabel(DateTime groupDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (groupDate.year == today.year &&
        groupDate.month == today.month &&
        groupDate.day == today.day) {
      return 'Today';
    } else if (groupDate.year == yesterday.year &&
        groupDate.month == yesterday.month &&
        groupDate.day == yesterday.day) {
      return 'Yesterday';
    } else if (groupDate.year == now.year) {
      return DateFormat('d MMMM').format(groupDate);
    } else {
      return DateFormat('d MMMM yyyy').format(groupDate);
    }
  }

  Widget _buildDateGroupHeader(String label, {bool isFirst = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, isFirst ? 8 : 18, 0, 10),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textSoft,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSliverList(List<AppTransaction> transactions) {
    if (transactions.isEmpty) {
      final settingsVM = context.read<SettingsViewModel>();
      final scanOption = settingsVM.scanWindowOption;
      final bankName = widget.sender.senderName;
      final isFiltered = _isBookmarkedOnly ||
          _typeFilter != 'All' ||
          _senderFilter != 'All Senders' ||
          _dateRangeFilter != 'All Time' ||
          _searchQuery.isNotEmpty;

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.textSoft,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isFiltered
                      ? 'No Matching Transactions'
                      : 'No Transactions Yet',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isFiltered
                      ? 'No $bankName transactions match your current search and filter settings.'
                      : 'Scanning started from ${scanOption.title}. No transactions found for $bankName starting from this date. Whenever SMS or transactions appear after this date, they will be displayed here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final displayedTransactions = transactions.take(_displayLimit).toList();
    final bool hasMore = transactions.length > _displayLimit;

    // Group displayed transactions by calendar day
    final Map<DateTime, List<AppTransaction>> grouped = {};
    for (final tx in displayedTransactions) {
      final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(dayKey, () => []).add(tx);
    }

    // Sort group keys newest date first
    final sortedDayKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final int groupCount = sortedDayKeys.length;
    final int totalCount = groupCount + (hasMore ? 1 : 0);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == groupCount && hasMore) {
              final remaining = transactions.length - _displayLimit;
              final nextBatch = remaining > 30 ? 30 : remaining;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Center(
                  child: AppButton.secondary(
                    text: 'Load More (+$nextBatch of $remaining)',
                    icon: Icons.expand_more_rounded,
                    height: 42,
                    fullWidth: true,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _displayLimit += 30;
                      });
                    },
                  ),
                ),
              );
            }

            final dayKey = sortedDayKeys[index];
            final dayTxs = grouped[dayKey]!;
            final headerLabel = _getDateHeaderLabel(dayKey);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateGroupHeader(headerLabel, isFirst: index == 0),
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.cardRadius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (int i = 0; i < dayTxs.length; i++) ...[
                        _buildTransactionItem(dayTxs[i]),
                        if (i < dayTxs.length - 1)
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
          childCount: totalCount,
        ),
      ),
    );
  }

  Widget _buildTransactionItem(AppTransaction tx) {
    final isIncome = tx.type == 'income';
    final partyName = tx.sender.trim();
    final partyLabel = partyName.isNotEmpty
        ? (isIncome ? 'From $partyName' : 'To $partyName')
        : (isIncome ? 'Income' : 'Expense');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: tx),
          ),
        ),
        splashColor: Colors.white.withValues(alpha: 0.04),
        highlightColor: Colors.white.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isIncome
                      ? AppColors.positive.withValues(alpha: 0.12)
                      : AppColors.negative.withValues(alpha: 0.12),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : Icons.north_east_rounded,
                  size: 20,
                  color: isIncome ? AppColors.positive : AppColors.negative,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tx.resolvedReason ??
                                (isIncome ? 'Income' : 'Expense'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (tx.isBookmarked) ...[
                          const SizedBox(width: 5),
                          const BookmarkBadge(),
                        ],
                        if (Provider.of<TransactionsViewModel>(context,
                                    listen: false)
                                .accountsForBank(tx.name)
                                .length >
                            1) ...[
                          const SizedBox(width: 5),
                          SimBadge(simSlot: tx.simSlot),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Consumer<SettingsViewModel>(
                builder: (context, settingsVM, child) {
                  final isVisible = settingsVM.isBalanceVisible;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      isVisible
                          ? CurrencyTextWidget(
                              amount: tx.amount,
                              showSign: true,
                              style: TextStyle(
                                color: isIncome
                                    ? AppColors.positive
                                    : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              customFormattedStr: NumberFormat('#,##0.00')
                                  .format(tx.amount),
                            )
                          : Text(
                              '••••••••',
                              style: TextStyle(
                                color: isIncome
                                    ? AppColors.positive
                                    : Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('hh:mm a').format(tx.date),
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
