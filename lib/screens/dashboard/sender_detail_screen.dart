import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'manual_transaction_sheet.dart';
import '../../models/sender.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_reset_filter_button.dart';
import '../../widgets/app_capsule_tab_bar.dart';
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
  String _dateRangeFilter = 'All Time'; // All Time, 7D, 30D, 90D, 1Y
  final TextEditingController _searchController = TextEditingController();
  bool _isChartVisible = false;
  double? _touchedX;

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
          headerCard: AppDrawerHeaderCard(
            icon: Icons.analytics_outlined,
            iconColor: AppColors.positive,
            title: "30D PNL (${widget.sender.senderName})",
            subtitle: "30-Day Profit or Loss Calculation",
          ),
          bottomAction: AppButton.primary(
            text: "OK",
            height: 48,
            onPressed: () => Navigator.pop(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "This 30-Day Profit or Loss calculation for this specific account = (Deposits) - (Expenditures) over the last 30 days.\n\nIt reflects the recent net performance of this wallet or account.",
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
    final provider = Provider.of<FinanceProvider>(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;

    // Get latest sender info from provider to reflect linked status
    final currentSender = provider.senders.firstWhere(
      (s) => s.id == widget.sender.id,
      orElse: () => widget.sender,
    );

    final sNameUp = widget.sender.senderName.toUpperCase();
    final allTxForSender = provider.transactions.where((tx) {
      final tNameUp = tx.name.toUpperCase();
      final tSenderUp = tx.sender.toUpperCase();
      if (sNameUp == 'BOA' || sNameUp.contains('ABYSSINIA')) {
        return tNameUp == 'BOA' ||
            tSenderUp == 'BOA' ||
            tNameUp.contains('ABYSSINIA') ||
            tSenderUp.contains('ABYSSINIA');
      }
      return tNameUp == sNameUp || tSenderUp == sNameUp;
    }).toList();

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
    double currentBalance =
        allTxForSender.isNotEmpty ? allTxForSender.first.totalBalance : 0;

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
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
                  provider: provider,
                  topSafeArea: topSafeArea,
                  currentBalance: currentBalance,
                  monthChange: monthChange,
                  monthPercent: monthPercent,
                  txCount: allTxForSender.length,
                  isChartVisible: _isChartVisible,
                  onAddTransaction: () {
                    AppBottomSheet.show(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => ManualTransactionSheet(
                        provider: provider,
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
                  onCredentials: () => _showRefreshChooser(context, provider),
                  onToggleChart: () => setState(() => _isChartVisible = !_isChartVisible),
                ),
              ),

              // ── Extra Bank Details (Telebirr Savings, Charts, Filters) ──
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    if (widget.sender.senderName.toUpperCase() == 'TELEBIRR' &&
                        provider.telebirrSavingBalance > 0)
                      _buildTelebirrSavingSummaryCard(
                        provider.telebirrSavingBalance,
                      ),
                    if (_isChartVisible) ...[
                      const SizedBox(height: 16),
                      _buildChartSection(allTxForSender),
                      _buildChartFilters(),
                    ],
                    const SizedBox(height: 16),
                    _buildActivityFilterSection(
                      filteredTransactions.length,
                      senderOptions,
                    ),
                  ],
                ),
              ),

              // ── Transaction List (Full Width, edge-to-edge) ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                sliver: SliverToBoxAdapter(
                  child: _buildTransactionList(filteredTransactions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Summary card for Telebirr Savings (Sanduq) when savings balance exists
  Widget _buildTelebirrSavingSummaryCard(double savingBalance) {
    final fmt = NumberFormat('#,##0.00');
    final provider = context.watch<FinanceProvider>();

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
                  const Text(
                    'Telebirr Sanduq (Savings)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'High-yield savings vault',
                    style: TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            provider.isBalanceVisible
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

  /// Lets the user pick how far back to re-scan SMS, then refreshes.
  void _showRefreshChooser(BuildContext context, FinanceProvider provider) {
    Future<void> runRefresh(int days) async {
      AppToast.info(
        context,
        message: 'Rescanning SMS',
        subtitle: 'Refreshing transactions from the last $days days…',
        duration: const Duration(seconds: 2),
      );
      await provider.refreshData(lastDays: days);
      if (!context.mounted) return;
      AppToast.success(
        context,
        message: 'Sync Complete',
        subtitle: 'Refreshed the last $days days of transactions',
      );
    }

    AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required int days,
        }) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.pop(sheetCtx);
              runRefresh(days);
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
                  Column(
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
                  const Spacer(),
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

        return AppDrawer(
          headerCard: const AppDrawerHeaderCard(
            icon: Icons.refresh_rounded,
            iconColor: AppColors.positive,
            title: 'Refresh transactions',
            subtitle: 'Choose how far back to re-scan your SMS.',
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option(
                icon: Icons.history_rounded,
                title: 'Past 7 days',
                subtitle: 'Quick — recent messages only',
                days: 7,
              ),
              option(
                icon: Icons.date_range_rounded,
                title: 'Last 30 days',
                subtitle: 'Thorough — wider catch-up',
                days: 30,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChartSection(List<AppTransaction> transactions) {
    if (transactions.isEmpty) return const SizedBox(height: 100);

    // Filter data based on selection
    DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (_chartFilter == '1D') {
      cutoff = DateTime.now().subtract(const Duration(days: 1));
    }
    if (_chartFilter == '7D') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    }
    if (_chartFilter == '180D') {
      cutoff = DateTime.now().subtract(const Duration(days: 180));
    }
    if (_chartFilter == '360D') {
      cutoff = DateTime.now().subtract(const Duration(days: 360));
    }

    final filtered =
        transactions.where((t) => t.date.isAfter(cutoff)).toList();
    if (filtered.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: Text(
            "No data for this time frame",
            style: TextStyle(color: AppColors.textSoft, fontSize: 13),
          ),
        ),
      );
    }

    // Sort ascending for chart
    filtered.sort((a, b) => a.date.compareTo(b.date));

    // Compute cumulative balance trend points
    List<FlSpot> spots = [];
    double runningBalance = 0;
    for (int i = 0; i < filtered.length; i++) {
      final t = filtered[i];
      if (t.totalBalance > 0) {
        runningBalance = t.totalBalance;
      } else {
        if (t.type == 'income') {
          runningBalance += t.amount;
        } else {
          runningBalance -= t.amount;
        }
      }
      spots.add(FlSpot(i.toDouble(), runningBalance));
    }

    if (spots.length == 1) {
      spots = [FlSpot(0, spots[0].y), FlSpot(1, spots[0].y)];
    }

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY = minY * 0.9;
      maxY = maxY * 1.1;
    }
    final rangeY = (maxY - minY).abs();
    minY -= rangeY * 0.1;
    maxY += rangeY * 0.1;

    return Container(
      height: 180,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.transparent,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    NumberFormat("#,##0").format(spot.y),
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
            touchCallback: (event, response) {
              if (event is FlTapUpEvent || event is FlPanUpdateEvent) {
                if (response?.lineBarSpots != null &&
                    response!.lineBarSpots!.isNotEmpty) {
                  setState(() {
                    _touchedX = response.lineBarSpots!.first.x;
                  });
                }
              } else if (event is FlPanEndEvent || event is FlTapCancelEvent) {
                setState(() {
                  _touchedX = null;
                });
              }
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.positive,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.positive.withValues(alpha: 0.25),
                    AppColors.positive.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartFilters() {
    final filters = ['1D', '7D', '30D', '180D', '360D'];
    return Center(
      child: AppTertiaryTabBar(
        tabs: filters,
        selectedTab: _chartFilter,
        onTabChanged: (val) {
          setState(() {
            _chartFilter = val;
          });
        },
      ),
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
                  if (val != null) setState(() => _typeFilter = val);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _senderFilter,
                items: senderOptions,
                maxWidth: 140,
                onChanged: (val) {
                  if (val != null) setState(() => _senderFilter = val);
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
                  if (val != null) setState(() => _sortBy = val);
                },
              ),
              const SizedBox(width: 8),
              _buildFilterDropdown(
                value: _dateRangeFilter,
                items: const ['All Time', '7D', '30D', '90D', '1Y'],
                onChanged: (val) {
                  if (val != null) setState(() => _dateRangeFilter = val);
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

  Widget _buildTransactionList(List<AppTransaction> transactions) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('No matching transactions.',
              style: TextStyle(color: AppColors.textSoft)),
        ),
      );
    }

    // Group transactions by calendar day
    final Map<DateTime, List<AppTransaction>> grouped = {};
    for (final tx in transactions) {
      final dayKey = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(dayKey, () => []).add(tx);
    }

    // Sort group keys newest date first
    final sortedDayKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 0),
      itemCount: sortedDayKeys.length,
      itemBuilder: (context, groupIdx) {
        final dayKey = sortedDayKeys[groupIdx];
        final dayTxs = grouped[dayKey]!;
        final headerLabel = _getDateHeaderLabel(dayKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateGroupHeader(headerLabel, isFirst: groupIdx == 0),
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
    );
  }

  Widget _buildTransactionItem(AppTransaction tx) {
    final isIncome = tx.type == 'income';
    final partyName = tx.sender.trim();
    final partyLabel = partyName.isNotEmpty
        ? (isIncome ? 'From $partyName' : 'For $partyName')
        : (isIncome ? 'Deposit' : 'Transfer');

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
                                (isIncome ? 'Deposit' : 'Expense'),
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
              Consumer<FinanceProvider>(
                builder: (context, provider, child) {
                  final isVisible = provider.isBalanceVisible;
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
