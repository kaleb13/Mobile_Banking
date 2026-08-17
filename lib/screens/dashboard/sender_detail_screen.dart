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
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/animated_balance_text.dart';
import '../../widgets/app_badges.dart';
import 'transaction_detail_screen.dart';
import 'manage_bank_screen.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final PageController _cardPageController = PageController();
  int _cardPageIndex = 0;
  bool _isChartVisible = false;
  double? _touchedX;

  @override
  void dispose() {
    _searchController.dispose();
    _cardPageController.dispose();
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
    // Get latest sender info from provider to reflect linked status
    final currentSender = provider.senders.firstWhere(
      (s) => s.id == widget.sender.id,
      orElse: () => widget.sender,
    );
    final isLinked =
        currentSender.accountNumber != null && currentSender.pin != null;

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

    // Chart date filter
    DateTime cutoff = DateTime.now().subtract(const Duration(days: 30));
    if (_chartFilter == '1D') {
      cutoff = DateTime.now().subtract(const Duration(days: 1));
    } else if (_chartFilter == '7D') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    } else if (_chartFilter == '30D') {
      cutoff = DateTime.now().subtract(const Duration(days: 30));
    } else if (_chartFilter == '180D') {
      cutoff = DateTime.now().subtract(const Duration(days: 180));
    } else if (_chartFilter == '360D') {
      cutoff = DateTime.now().subtract(const Duration(days: 360));
    }

    // Filter transactions for listing & chart
    final filteredTransactions = allTxForSender.where((tx) {
      final matchesDate = tx.date.isAfter(cutoff);
      final matchesSearch =
          tx.sender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (tx.resolvedReason
                      ?.toLowerCase()
                      .contains(_searchQuery.toLowerCase()) ??
                  false);
      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Income' && tx.type == 'income') ||
          (_typeFilter == 'Expense' && tx.type != 'income');
      return matchesDate && matchesSearch && matchesType;
    }).toList();

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
        extendBodyBehindAppBar: true,
        floatingActionButton: AppButton.primary(
          text: 'Add Transaction',
          icon: Icons.add_rounded,
          fullWidth: false,
          height: 48,
          elevation: 6.0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          onPressed: () {
            AppBottomSheet.show(
              context: context,
              isScrollControlled: true,
              builder: (context) => ManualTransactionSheet(
                provider: provider,
                initialSender: widget.sender,
              ),
            );
          },
        ),
        body: Stack(
          children: [
            // Background Gradient
            _buildBackground(),

            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildSearchHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          if (widget.sender.senderName.toUpperCase() == 'TELEBIRR' &&
                              provider.telebirrSavingBalance > 0)
                            _buildTelebirrCardCarousel(
                              currentBalance,
                              provider.telebirrSavingBalance,
                              monthChange,
                              monthPercent,
                              allTxForSender.length,
                            )
                          else
                            _buildBankCard(
                              currentBalance,
                              monthChange,
                              monthPercent,
                              allTxForSender.length,
                            ),
                          if (isLinked)
                            _buildDynamicButtons(context, currentSender)
                          else
                            _buildAddAccountButton(context),
                          if (_isChartVisible) ...[
                            const SizedBox(height: 16),
                            _buildChartSection(allTxForSender),
                            _buildChartFilters(),
                          ],
                          const SizedBox(height: 32),
                          _buildActivityFilterSection(),
                          _buildTransactionList(filteredTransactions),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final senderName = widget.sender.senderName.toUpperCase().contains('AHADU')
        ? 'Ahadu Bank'
        : widget.sender.senderName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: AppSearchBar(
        mode: AppSearchBarMode.icon,
        controller: _searchController,
        hint: 'Search in $senderName...',
        title: senderName,
        leading: const AppBackButton(),
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
            _searchQuery = '';
          });
        },
        backgroundColor: AppColors.surface,
        textColor: Colors.white,
        hintColor: AppColors.textSoft,
        iconColor: Colors.white70,
        closeIconColor: Colors.white,
      ),
    );
  }

  /// Carousel view showing both Main Telebirr Wallet & Telebirr Savings (Sanduq) Account.
  Widget _buildTelebirrCardCarousel(
    double mainBalance,
    double savingBalance,
    double change,
    double percent,
    int txCount,
  ) {
    final cardGradient = BankCardWidget.getCardGradient('Telebirr');
    final bool isDarkTextTheme = BankCardWidget.isDarkTextTheme('Telebirr');
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Column(
      children: [
        SizedBox(
          height: 205,
          child: PageView(
            controller: _cardPageController,
            onPageChanged: (idx) {
              setState(() {
                _cardPageIndex = idx;
              });
            },
            physics: const BouncingScrollPhysics(),
            children: [
              // ── 1. Main Telebirr Wallet Card ──────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: cardGradient,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          BankCardWidget.bankLogo(
                            'Telebirr',
                            38,
                            isDarkTextTheme
                                ? AppColors.darkCharcoal
                                : Colors.white,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Telebirr',
                                      style: TextStyle(
                                        color: textColorPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: isDarkTextTheme
                                            ? Colors.black.withValues(alpha: 0.09)
                                            : Colors.white.withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        'Main Wallet',
                                        style: TextStyle(
                                          color: textColorPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Ethio Telecom , E- money',
                                  style: TextStyle(
                                    color: textColorSub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCardRefreshButton(
                              textColorPrimary, isDarkTextTheme),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Large Balance Display
                      _buildLargeBalanceDisplay(
                          mainBalance, textColorPrimary, isDarkTextTheme),
                      const SizedBox(height: 8),
                      // Bottom row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$txCount total Transactions',
                            style: TextStyle(
                              color: textColorSub,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          _build30DPnlChip(change, percent, textColorPrimary,
                              isDarkTextTheme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 2. Telebirr Savings Account (Sanduq) Card ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [
                        Color(0xFF007A3D),
                        Color(0xFF00B050),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          BankCardWidget.bankLogo('Telebirr', 38, Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'Telebirr Saving',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: const Text(
                                        'Sanduq',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'High-Yield Savings Account',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCardRefreshButton(Colors.white, false),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Large Balance Display
                      _buildLargeBalanceDisplay(
                          savingBalance, Colors.white, false),
                      const SizedBox(height: 8),
                      // Bottom row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Compounding Interest Vault',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline_rounded,
                                    color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  'Protected Vault',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Smooth Page Indicators ───────────────────────────────────────────
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _cardPageIndex == 0 ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _cardPageIndex == 0
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _cardPageIndex == 1 ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _cardPageIndex == 1
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ],
        ),

        // ── Combined Total Assets Summary ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Telebirr Net Worth',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Consumer<FinanceProvider>(
                      builder: (context, prov, _) {
                        final total = mainBalance + savingBalance;
                        final fmt = NumberFormat('#,##0.00');
                        final valStr = prov.isBalanceVisible
                            ? 'ETB ${fmt.format(total)}'
                            : 'ETB ****,***.**';
                        return Text(
                          valStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.telebirrGreen,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '2 Accounts',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeBalanceDisplay(
      double balance, Color textColorPrimary, bool isDarkTextTheme) {
    return Consumer<FinanceProvider>(
      builder: (context, provider, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            provider.toggleBalanceVisibility();
          },
          behavior: HitTestBehavior.opaque,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedBalanceText(
              value: balance,
              isMasked: !provider.isBalanceVisible,
              integerStyle: TextStyle(
                color: textColorPrimary,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                height: 1.0,
              ),
              decimalStyle: TextStyle(
                color: isDarkTextTheme
                    ? AppColors.darkCharcoal.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.65),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardRefreshButton(
      Color textColorPrimary, bool isDarkTextTheme) {
    return GestureDetector(
      onTap: () => _showRefreshChooser(
        context,
        Provider.of<FinanceProvider>(context, listen: false),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkTextTheme
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.refresh_rounded,
          color: textColorPrimary,
          size: 18,
        ),
      ),
    );
  }

  Widget _build30DPnlChip(double change, double percent, Color textColorPrimary,
      bool isDarkTextTheme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isChartVisible = !_isChartVisible;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDarkTextTheme
              ? Colors.black.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showPNLInfo(context),
              child: Text(
                '30D PNL ',
                style: TextStyle(
                  color: textColorPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              '${change >= 0 ? '+' : '-'}${NumberFormat('#,##0').format(change.abs())} (${percent.abs().toStringAsFixed(1)}%)',
              style: TextStyle(
                color: textColorPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isChartVisible
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: textColorPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(
      double balance, double change, double percent, int txCount) {
    final senderName = widget.sender.senderName;
    final cardGradient = BankCardWidget.getCardGradient(senderName);
    final bool isDarkTextTheme = BankCardWidget.isDarkTextTheme(senderName);
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: cardGradient,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Logo + Bank Title + Sub-description + Top-Right Refresh Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BankCardWidget.bankLogo(
                  senderName,
                  38,
                  isDarkTextTheme ? AppColors.darkCharcoal : Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName.toUpperCase().contains('AHADU')
                            ? 'Ahadu Bank'
                            : senderName,
                        style: TextStyle(
                          color: textColorPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        BankCardWidget.subtitle(senderName),
                        style: TextStyle(
                          color: textColorSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildCardRefreshButton(textColorPrimary, isDarkTextTheme),
              ],
            ),
            const SizedBox(height: 18),

            // Large Balance Display (Integer + Decimals)
            _buildLargeBalanceDisplay(
                balance, textColorPrimary, isDarkTextTheme),
            const SizedBox(height: 8),

            // Bottom Info & Chart Toggle Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$txCount total Transactions',
                  style: TextStyle(
                    color: textColorSub,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                _build30DPnlChip(
                    change, percent, textColorPrimary, isDarkTextTheme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
    );
  }

  Widget _buildDynamicButtons(BuildContext context, AppSender sender) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  context,
                  label: "View Bank",
                  icon: Icons.account_balance_rounded,
                  color: AppColors.surfaceElevated,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ManageBankScreen(sender: sender)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  context,
                  label: "Transfer",
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.gold,
                  textColor: Colors.black,
                  onTap: () {
                    AppToast.info(
                      context,
                      message: 'Quick Transfer',
                      subtitle: 'Direct transfer feature is coming soon!',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor.withValues(alpha: 0.8), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    return const SizedBox.shrink();
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
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary, size: 20),
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
    } else if (_chartFilter == '7D') {
      cutoff = DateTime.now().subtract(const Duration(days: 7));
    } else if (_chartFilter == '30D') {
      cutoff = DateTime.now().subtract(const Duration(days: 30));
    } else if (_chartFilter == '180D') {
      cutoff = DateTime.now().subtract(const Duration(days: 180));
    } else if (_chartFilter == '360D') {
      cutoff = DateTime.now().subtract(const Duration(days: 360));
    }

    final filtered = transactions
        .where((tx) => tx.date.isAfter(cutoff) && tx.totalBalance > 0)
        .toList()
        .reversed
        .toList();
    if (filtered.isEmpty) return const SizedBox(height: 100);

    List<FlSpot> spots = filtered.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalBalance);
    }).toList();

    if (spots.length == 1) {
      spots = [
        FlSpot(0, spots.first.y),
        FlSpot(1, spots.first.y),
      ];
    }

    // Gradient configuration
    List<double> lineStops = [0.0, 1.0];
    List<Color> lineColors = [AppColors.positive, AppColors.positive];

    List<Color> fillColors = [
      AppColors.positive.withValues(alpha: 0.28),
      AppColors.positive.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        lineColors = [
          AppColors.positive,
          AppColors.positive,
          AppColors.positive.withValues(alpha: 0.08),
          AppColors.positive.withValues(alpha: 0.08),
        ];
        fillColors = [
          AppColors.positive.withValues(alpha: 0.07),
          AppColors.positive.withValues(alpha: 0.0),
        ];
      }
    }

    return Container(
      height: 120, // Match Dashboard height
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchCallback:
                (FlTouchEvent event, LineTouchResponse? touchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    touchResponse == null ||
                    touchResponse.lineBarSpots == null ||
                    touchResponse.lineBarSpots!.isEmpty) {
                  _touchedX = null;
                  return;
                }
                final newX = touchResponse.lineBarSpots!.first.x;
                if (_touchedX != newX) {
                  HapticFeedback.selectionClick();
                  _touchedX = newX;
                }
              });
            },
            getTouchedSpotIndicator:
                (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: Colors.white.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.gold,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    '',
                    const TextStyle(),
                    children: [
                      TextSpan(
                        text: 'ETB ',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(
                        text: NumberFormat('#,##0').format(s.y),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: LinearGradient(
                colors: lineColors,
                stops: lineStops,
              ),
              barWidth: 1.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: fillColors,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['1D', '7D', '30D', '180D', '360D'].map((f) {
          final isSelected = _chartFilter == f;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _chartFilter = f);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSoft,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityFilterSection() {
    const tabs = ['All', 'Income', 'Expense'];
    final selectedIdx = tabs.indexOf(_typeFilter).clamp(0, 2);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AppCapsuleTabBar component
          AppCapsuleTabBar(
            tabs: tabs,
            selectedIndex: selectedIdx,
            onTabChanged: (idx) {
              setState(() {
                _typeFilter = tabs[idx];
              });
            },
            height: 44,
            fontSize: 13,
            borderRadius: 24,
            indicatorRadius: 20,
          ),
          const SizedBox(height: 24),
          const Text(
            'ACTIVITY',
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedDayKeys.length,
      itemBuilder: (context, groupIdx) {
        final dayKey = sortedDayKeys[groupIdx];
        final dayTxs = grouped[dayKey]!;
        final headerLabel = _getDateHeaderLabel(dayKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateGroupHeader(headerLabel, isFirst: groupIdx == 0),
            ...dayTxs.map((tx) => _buildTransactionItem(tx)),
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

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: tx)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
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
                isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
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
                          tx.resolvedReason ?? (isIncome ? 'Deposit' : 'Expense'),
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
                              color: isIncome ? AppColors.positive : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            customFormattedStr:
                                NumberFormat('#,##0.00').format(tx.amount),
                          )
                        : Text(
                            '****',
                            style: TextStyle(
                              color: isIncome ? AppColors.positive : Colors.white,
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
    );
  }
}

class DashedUnderlinePainter extends CustomPainter {
  final Color color;
  DashedUnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 1.5;
    const dashSpace = 1.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
