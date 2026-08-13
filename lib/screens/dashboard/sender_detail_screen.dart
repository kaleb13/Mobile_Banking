import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _isChartVisible = false;
  double? _touchedX;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPNLInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "30D PNL (${widget.sender.senderName})",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  "This 30-Day Profit or Loss calculation for this specific account = (Deposits) - (Expenditures) over the last 30 days.\n\nIt reflects the recent net performance of this wallet or account.",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.background,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => ManualTransactionSheet(
                provider: provider,
                initialSender: widget.sender,
              ),
            );
          },
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.brownDark,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28),
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
                          _buildBankCard(
                              currentBalance, monthChange, monthPercent, allTxForSender.length),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tabBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSoft,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search in ${widget.sender.senderName}...',
                        hintStyle: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        suffixIconConstraints:
                            const BoxConstraints(minHeight: 24, minWidth: 24),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: Icon(
                                    Icons.cancel_rounded,
                                    color: Colors.white.withValues(alpha: 0.3),
                                    size: 16,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
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

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    String imagePath = '';

    if (nameUp == 'CBE') {
      imagePath = 'assets/images/CBE logo 1.webp';
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('AHADU')) {
      imagePath = 'assets/images/Ahadu_Logo.png';
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: 38,
        height: 38,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        width: 38,
        height: 38,
        fit: BoxFit.contain,
      );
    }

    return Icon(
      Icons.account_balance,
      color: Colors.white.withValues(alpha: 0.9),
      size: 34,
    );
  }

  String _bankSubtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'TELEBIRR') return 'Ethio Telecom, E-money';
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr Mobile Wallet';
    if (n.contains('AHADU')) return 'Ahadu Bank S.C.';
    return 'Bank Account';
  }

  List<Color> _getCardGradient(String name) {
    final nameUp = name.toUpperCase();
    if (nameUp == 'TELEBIRR') {
      return [
        AppColors.success,
        AppColors.cardLime,
      ];
    } else if (nameUp == 'CBE') {
      return [
        AppColors.cardBrownDark,
        AppColors.cardBrownMid,
      ];
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return [
        AppColors.cardCbeBirrSilver,
        AppColors.cardCbeBirrWhite,
      ];
    } else if (nameUp.contains('AHADU')) {
      return [
        AppColors.cardAhaduPink,
        AppColors.cardAhaduWhite,
      ];
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA') {
      return [
        AppColors.cardBoaDarkIcon,
        AppColors.cardBoaBg,
      ];
    } else if (nameUp.contains('DASHEN')) {
      return [
        AppColors.cardDashenDarkIcon,
        AppColors.cardDashenBg,
      ];
    } else if (nameUp.contains('COOP')) {
      return [
        AppColors.cardCoopDarkIcon,
        AppColors.cardCoopBg,
      ];
    }
    return [
      AppColors.bgMid,
      AppColors.cardGrayLight,
    ];
  }

  Widget _buildBankCard(
      double balance, double change, double percent, int txCount) {
    final senderName = widget.sender.senderName;
    final cardGradient = _getCardGradient(senderName);
    final bool isDarkTextTheme = senderName.toUpperCase().contains('AHADU') ||
        senderName.toUpperCase() == 'CBE BIRR' ||
        senderName.toUpperCase() == 'CBEBIRR';
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
            colors: cardGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Logo + Bank Title + Sub-description + Top-Right Refresh Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _bankLogo(senderName),
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
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bankSubtitle(senderName),
                        style: TextStyle(
                          color: textColorSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Top-Right Refresh Button on Bank Card
                GestureDetector(
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
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Large Balance Display (Integer + Decimals)
            Consumer<FinanceProvider>(
              builder: (context, provider, child) {
                final fmt = NumberFormat('#,##0.00');
                final balStr = provider.isBalanceVisible
                    ? fmt.format(balance)
                    : '****,***.**';
                final parts = balStr.split('.');

                return GestureDetector(
                  onTap: provider.toggleBalanceVisibility,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        parts[0],
                        style: TextStyle(
                          color: textColorPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        '.${parts[1]}',
                        style: TextStyle(
                          color: isDarkTextTheme
                              ? AppColors.darkCharcoal.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.65),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isChartVisible = !_isChartVisible;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDarkTextTheme
                          ? Colors.black.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
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
                ),
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
                  color: AppColors.overlay,
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Transfer feature coming soon!')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshing the last $days days…',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          backgroundColor: AppColors.overlay,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      await provider.refreshData(lastDays: days);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refreshed the last $days days',
              style: const TextStyle(color: Colors.white, fontSize: 13)),
          backgroundColor: AppColors.overlay,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.overlay.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgMid,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Refresh transactions',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Choose how far back to re-scan your SMS.',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  const SizedBox(height: 18),
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
            ),
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
        .where((tx) => tx.date.isAfter(cutoff))
        .toList()
        .reversed
        .toList();
    if (filtered.isEmpty) return const SizedBox(height: 100);

    final spots = filtered.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalBalance);
    }).toList();

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
                _touchedX = touchResponse.lineBarSpots!.first.x;
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
            onTap: () => setState(() => _chartFilter = f),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.transparent),
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
          color: AppColors.tabBackground, // Loan card background (#191F28)
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
                  Text(
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
