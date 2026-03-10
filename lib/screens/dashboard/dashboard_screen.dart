import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_banking_app/providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:math';
import 'sender_detail_screen.dart';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';
import 'cash_wallet_detail_screen.dart';
import 'transaction_search_screen.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  late PageController _bannerController;
  bool _isShowingTodayOnly = false;
  Timer? _bannerTimer;
  final int _bannerLoopFactor = 10000;
  bool _isOverallChartVisible = false;
  String _chartFilter = '30D';
  int _searchLabelIndex = 0;
  Timer? _searchLabelTimer;
  double? _touchedX;

  @override
  void initState() {
    super.initState();
    // Start PageController at a large central value for "infinite" scroll
    _bannerController = PageController(initialPage: _bannerLoopFactor ~/ 2);
    _startAutoScroll();
    _startSearchLabelRotation();
  }

  void _startSearchLabelRotation() {
    _searchLabelTimer?.cancel();
    _searchLabelTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _searchLabelIndex = (_searchLabelIndex + 1) % 3;
        });
      }
    });
  }

  String _getSearchHint(FinanceProvider provider) {
    if (_searchLabelIndex == 0) {
      final hour = DateTime.now().hour;
      String greeting;
      if (hour < 12) {
        greeting = 'Good Morning ☀️';
      } else if (hour < 17) {
        greeting = 'Good Afternoon 🌤️';
      } else {
        greeting = 'Good Evening 🌙';
      }

      if (provider.userName != null) {
        greeting = '$greeting Dear ${provider.userName}';
      }
      return greeting;
    } else if (_searchLabelIndex == 1) {
      return 'Search all Transactions';
    } else {
      final top = provider.topExpenseHighlight;
      if (top != null) {
        return 'HE: ${top['reason']} (${NumberFormat('#,###').format(top['amount'])} ETB)';
      }
      return 'Search all Transactions';
    }
  }

  void _startAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        _bannerController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerTimer?.cancel();
    _searchLabelTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  void _showPNLInfo(BuildContext context, bool isToday) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F1F25),
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
                  isToday ? "Today's PNL" : "Overall PNL",
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
                  isToday
                      ? "Today's PNL = (Today's Income + Cash Additions) - (Today's Expenses + Cash Spending).\n\nIt represents your net increase or decrease in wealth today."
                      : "Overall PNL = (All-time Income + Cash Additions) - (All-time Expenses + Cash Spending).\n\nThis shows your cumulative financial progress since using the app.",
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
                    backgroundColor: const Color(0xFFF0B90B),
                    foregroundColor: const Color(0xFF1F1F25),
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

  IconData _getReasonIcon(String? reason) {
    if (reason == null) {
      return Icons.help_outline;
    }
    final r = reason.toLowerCase();
    if (r.contains('airtime') || r.contains('phone')) {
      return Icons.phone_android;
    }
    if (r.contains('food') || r.contains('restaurant')) {
      return Icons.restaurant;
    }
    if (r.contains('transport') || r.contains('taxi')) {
      return Icons.directions_car;
    }
    if (r.contains('shopping')) {
      return Icons.shopping_bag;
    }
    if (r.contains('utility') || r.contains('bill')) {
      return Icons.receipt_long;
    }
    if (r.contains('loan') || r.contains('debt')) {
      return Icons.handshake;
    }
    if (r.contains('gift')) {
      return Icons.redeem;
    }
    if (r.contains('salary') || r.contains('deposit')) {
      return Icons.account_balance_wallet;
    }
    if (r.contains('internet')) {
      return Icons.language;
    }
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF1F1F25),
                Color(0xFF1B1B21),
              ],
            ),
          ),
          child: Consumer<FinanceProvider>(
            builder: (context, financeProvider, child) {
              return _buildMainDashboardLayout(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboardLayout(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                if (provider.overdueLoans.isNotEmpty)
                  _buildOverdueLoanBanner(context),
                const SizedBox(height: 16),
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildBalanceCard(context),
                _buildOverallChartSection(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildSendersList(context),
          const SizedBox(height: 24),
          _buildBannerCarousel(context),
          const SizedBox(height: 24),
          _buildTransactionsList(context, _searchQuery),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildOverdueLoanBanner(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final overdueCount = provider.overdueLoanCount;
    final firstOverdue = provider.overdueLoans.first;
    final totalRemaining = provider.overdueLoans
        .fold<double>(0, (sum, loan) => sum + loan.remainingAmount);

    return GestureDetector(
      onTap: () {
        provider.setScreenIndex(3);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.alertRed.withValues(alpha: 0.15),
          border: Border(
            bottom:
                BorderSide(color: AppColors.alertRed.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.alertRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                overdueCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                overdueCount == 1
                    ? 'OVERDUE: ${firstOverdue.personName} (${firstOverdue.daysOverdue} days late — ${NumberFormat('#,###').format(firstOverdue.remainingAmount)} ETB)'
                    : '$overdueCount LOANS ARE OVERDUE — Total: ${NumberFormat('#,###').format(totalRemaining)} ETB',
                style: const TextStyle(
                  color: AppColors.alertRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.alertRed, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const TransactionSearchScreen()),
                );
              },
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A34),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search,
                        color: AppColors.labelGray, size: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerLeft,
                        children: [
                          if (_searchQuery.isEmpty)
                            IgnorePointer(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 600),
                                switchInCurve: Curves.easeInOutCubic,
                                switchOutCurve: Curves.easeInOutCubic,
                                layoutBuilder: (Widget? currentChild,
                                    List<Widget> previousChildren) {
                                  return Stack(
                                    alignment: Alignment.centerLeft,
                                    children: [
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  final inAnimation = Tween<Offset>(
                                    begin: const Offset(0.0, 1.2),
                                    end: Offset.zero,
                                  ).animate(animation);
                                  final outAnimation = Tween<Offset>(
                                    begin: const Offset(0.0, -1.2),
                                    end: Offset.zero,
                                  ).animate(animation);

                                  return ClipRect(
                                    child: SlideTransition(
                                      position: child.key ==
                                              ValueKey(_searchLabelIndex)
                                          ? inAnimation
                                          : outAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Text(
                                  _getSearchHint(provider),
                                  key: ValueKey(_searchLabelIndex),
                                  style: const TextStyle(
                                      color: AppColors.labelGray, fontSize: 12),
                                ),
                              ),
                            ),
                          TextField(
                            enabled: false,
                            controller: _searchController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: '',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                SvgPicture.asset('assets/images/Notification.svg',
                    colorFilter:
                        const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    width: 20,
                    height: 20),
                if (provider.unreadNotificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          provider.unreadNotificationCount > 9
                              ? '9+'
                              : provider.unreadNotificationCount.toString(),
                          style: const TextStyle(
                            color: Color(0xFF1F1F25),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final formatter = NumberFormat('#,##0');
    final String fullyFormatted = provider.isBalanceVisible
        ? formatter.format(provider.totalBalance.floor())
        : '****,***';
    final String decimals = provider.isBalanceVisible
        ? (provider.totalBalance % 1).toStringAsFixed(2).split('.')[1]
        : '**';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: provider.toggleBalanceVisibility,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    const Text(
                      'Total balance',
                      style:
                          TextStyle(color: AppColors.labelGray, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      provider.isBalanceVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.labelGray,
                      size: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: provider.toggleBalanceVisibility,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          '\$',
                          style: TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fullyFormatted,
                          style: const TextStyle(
                            color: AppColors.textWhite,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '.$decimals',
                      style: const TextStyle(
                        color: AppColors.labelGray,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showPNLInfo(context, _isShowingTodayOnly),
                    behavior: HitTestBehavior.opaque,
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isShowingTodayOnly ? 'TODAY PNL' : 'OVERALL PNL',
                            style: const TextStyle(
                              color: AppColors.labelGray,
                              fontSize: 9, // Reduced
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 1),
                          CustomPaint(
                            size: const Size(double.infinity, 1),
                            painter: DashedUnderlinePainter(
                                color:
                                    AppColors.labelGray.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isOverallChartVisible = !_isOverallChartVisible;
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(
                          '${(_isShowingTodayOnly ? provider.netForSelectedDate : provider.netOverall) >= 0 ? '+' : '-'}${NumberFormat('#,##0').format((_isShowingTodayOnly ? provider.netForSelectedDate : provider.netOverall).abs())}',
                          style: TextStyle(
                            color: (_isShowingTodayOnly
                                        ? provider.netForSelectedDate
                                        : provider.netOverall) >=
                                    0
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            fontSize: 10, // Reduced
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4), // Reduced from 8
                        Text(
                          '(',
                          style: TextStyle(
                            color: (_isShowingTodayOnly
                                        ? provider.incomePercentageChange
                                        : provider.percentageChangeOverall) >=
                                    0
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            fontSize: 10, // Reduced
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          (_isShowingTodayOnly
                                      ? provider.incomePercentageChange
                                      : provider.percentageChangeOverall) >=
                                  0
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: (_isShowingTodayOnly
                                      ? provider.incomePercentageChange
                                      : provider.percentageChangeOverall) >=
                                  0
                              ? AppColors.mintGreen
                              : AppColors.alertRed,
                          size: 12, // Reduced from 14
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${(_isShowingTodayOnly ? provider.incomePercentageChange : provider.percentageChangeOverall).abs().toStringAsFixed(2)}%)',
                          style: TextStyle(
                            color: (_isShowingTodayOnly
                                        ? provider.incomePercentageChange
                                        : provider.percentageChangeOverall) >=
                                    0
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            fontSize: 10, // Reduced
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isOverallChartVisible
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              provider.setScreenIndex(1);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0B90B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.keyboard_double_arrow_right,
                      color: Color(0xFF1F1F25), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: Color(0xFF1F1F25),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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

  Widget _buildOverallChartSection(BuildContext context) {
    if (!_isOverallChartVisible) return const SizedBox.shrink();

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    List<FlSpot> spots = [];
    int daysLimit = 30;
    if (_chartFilter == '1D') {
      daysLimit = 2; // need at least 2 points to draw a line
    } else if (_chartFilter == '7D') {
      daysLimit = 7;
    } else if (_chartFilter == '30D') {
      daysLimit = 30;
    } else if (_chartFilter == '180D') {
      daysLimit = 180;
    } else if (_chartFilter == '360D') {
      daysLimit = 360;
    }

    DateTime now = DateTime.now();
    // Normalize "now" to midnight today to prevent data jitter based on the current time.
    final DateTime todayMidnight = DateTime(now.year, now.month, now.day);

    // Clip daysLimit to actual data range so the chart fills its width.
    if (provider.transactions.isNotEmpty ||
        provider.cashTransactions.isNotEmpty) {
      DateTime? firstTx;
      if (provider.transactions.isNotEmpty) {
        firstTx = provider.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      if (provider.cashTransactions.isNotEmpty) {
        final firstCash = provider.cashTransactions
            .map((t) => t.date)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        if (firstTx == null || firstCash.isBefore(firstTx)) {
          firstTx = firstCash;
        }
      }
      if (firstTx != null) {
        // Difference from midnight of the first transaction day
        final firstDateMidnight =
            DateTime(firstTx.year, firstTx.month, firstTx.day);
        final daysSinceFirst =
            todayMidnight.difference(firstDateMidnight).inDays + 1;
        daysLimit = daysSinceFirst.clamp(2, daysLimit);
      }
    }

    // Re-calculate chartStart based on the potentially clipped daysLimit
    final DateTime actualChartStart =
        todayMidnight.subtract(Duration(days: daysLimit - 1));

    // Sort all transactions oldest-first
    final sortedTxs = List.from(provider.transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    final sortedCashTxs = List.from(provider.cashTransactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Walk day by day.
    final Map<String, double> lastKnownBalance = {};
    double currentCashBalance = 0;

    // A helper to detect if a bank transaction is a cash transfer
    bool isCashTransfer(AppTransaction tx) {
      return tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash';
    }

    // Pre-seed with balances from transactions strictly BEFORE the chart window
    for (final tx in sortedTxs) {
      if (tx.date.isBefore(actualChartStart)) {
        if (tx.totalBalance > 0) {
          lastKnownBalance[tx.name] = tx.totalBalance;
        }
        if (isCashTransfer(tx)) {
          if (tx.type == 'expense') {
            currentCashBalance += tx.amount.abs();
          } else {
            currentCashBalance -= tx.amount.abs();
          }
        }
      }
    }
    for (final ctx in sortedCashTxs) {
      if (ctx.date.isBefore(actualChartStart)) {
        if (ctx.type == 'addition') {
          currentCashBalance += ctx.amount;
        } else {
          currentCashBalance -= ctx.amount;
        }
      }
    }

    // Build lists of transactions grouped by their day key for fast lookup
    final Map<String, List<AppTransaction>> txsByDay = {};
    for (final tx in sortedTxs) {
      if (!tx.date.isBefore(actualChartStart)) {
        final key = '${tx.date.year}-${tx.date.month}-${tx.date.day}';
        txsByDay.putIfAbsent(key, () => []);
        txsByDay[key]!.add(tx);
      }
    }
    final Map<String, List<CashTransaction>> cashTxsByDay = {};
    for (final ctx in sortedCashTxs) {
      if (!ctx.date.isBefore(actualChartStart)) {
        final key = '${ctx.date.year}-${ctx.date.month}-${ctx.date.day}';
        cashTxsByDay.putIfAbsent(key, () => []);
        cashTxsByDay[key]!.add(ctx);
      }
    }

    for (int i = 0; i < daysLimit; i++) {
      final d = actualChartStart.add(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';

      // Update bank balances with any transactions on this day
      final dayTxs = txsByDay[key];
      if (dayTxs != null) {
        for (final tx in dayTxs) {
          if (tx.totalBalance > 0) {
            lastKnownBalance[tx.name] = tx.totalBalance;
          }
          if (isCashTransfer(tx)) {
            if (tx.type == 'expense') {
              currentCashBalance += tx.amount.abs();
            } else {
              currentCashBalance -= tx.amount.abs();
            }
          }
        }
      }

      // Update cash balance with manual transactions on this day
      final dayCashTxs = cashTxsByDay[key];
      if (dayCashTxs != null) {
        for (final ctx in dayCashTxs) {
          if (ctx.type == 'addition') {
            currentCashBalance += ctx.amount;
          } else {
            currentCashBalance -= ctx.amount;
          }
        }
      }

      // Sum all banks' latest known balances + cash balance
      final bankTotal = lastKnownBalance.values.fold(0.0, (sum, v) => sum + v);
      final totalBal =
          bankTotal + (currentCashBalance > 0 ? currentCashBalance : 0);
      spots.add(FlSpot(i.toDouble(), totalBal));
    }

    // ── Gradient configuration ──────────────────────────────────────────────
    // LINE  : always left→right so stops map to horizontal chart positions.
    // FILL  : always top→bottom for that strong area-chart fade effect.
    //         When touched we simply dim the entire fill uniformly; the clear
    //         left/right distinction is shown by the line gradient + indicator.
    List<double> lineStops = [0.0, 1.0];
    List<Color> lineColors = [AppColors.accentBlue, AppColors.accentBlue];

    // Fill: top strong → bottom fully transparent (always top→bottom)
    List<Color> fillColors = [
      AppColors.accentBlue.withValues(alpha: 0.28),
      AppColors.accentBlue.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        // Line: full left of indicator, nearly invisible right of it
        lineColors = [
          AppColors.accentBlue,
          AppColors.accentBlue,
          AppColors.accentBlue.withValues(alpha: 0.08),
          AppColors.accentBlue.withValues(alpha: 0.08),
        ];
        // Fill: dim the whole fill uniformly when touching
        fillColors = [
          AppColors.accentBlue.withValues(alpha: 0.07),
          AppColors.accentBlue.withValues(alpha: 0.0),
        ];
      }
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          height: 120,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          color: AppColors.accentBlue,
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
        ),
        // Chart Filters
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: ['1D', '7D', '30D', '180D', '360D'].map((f) {
              final isSelected = _chartFilter == f;
              return GestureDetector(
                onTap: () => setState(() => _chartFilter = f),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      color: isSelected ? Colors.white : AppColors.labelGray,
                      fontSize: 10,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCashWalletCard(BuildContext context, FinanceProvider provider) {
    final pd = provider.selectedDate;
    double cashNet = 0;
    for (var tx in provider.cashTransactions) {
      if (_isShowingTodayOnly) {
        if (tx.date.year != pd.year ||
            tx.date.month != pd.month ||
            tx.date.day != pd.day) {
          continue;
        }
      } else {
        if (tx.date.year != pd.year || tx.date.month != pd.month) {
          continue;
        }
      }
      if (tx.type == 'addition') {
        cashNet += tx.amount;
      } else if (tx.type == 'subtraction' || tx.type == 'expense') {
        cashNet -= tx.amount;
      }
    }
    final String sign = cashNet >= 0 ? '+' : '-';
    final fmt = NumberFormat('#,##0');

    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CashWalletDetailScreen()));
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  gradient: const SweepGradient(
                    center: Alignment.center,
                    transform: GradientRotation(pi / 4),
                    colors: [
                      Color(0xFF2F2F39),
                      Color(0xFF4F4F59),
                      Color(0xFF2F2F39)
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    const Center(
                        child: Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.white, size: 40)),
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cash Wallet',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          Text(
                            provider.isBalanceVisible
                                ? NumberFormat('#,##0.00')
                                    .format(provider.cashBalance)
                                : '****.**',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF363640),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$sign${fmt.format(cashNet.abs())}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.normal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendersList(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;

    return Column(
      children: [
        SizedBox(
          height: 110,
          child: ListView.builder(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: senders.length + 1,
            itemBuilder: (context, index) {
              if (index == senders.length) {
                return _buildCashWalletCard(context, provider);
              }
              final sender = senders[index];
              double senderBalance = 0;
              final matchingTxs = provider.transactions.where(
                  (t) => t.name == sender.senderName && t.totalBalance > 0);
              if (matchingTxs.isNotEmpty) {
                senderBalance = matchingTxs.first.totalBalance;
              }

              final relevantTxs = _isShowingTodayOnly
                  ? provider.transactionsForSelectedDate
                  : provider.transactionsForSelectedMonth;
              double totalNet = 0;
              for (var tx in relevantTxs) {
                if (tx.name == sender.senderName) {
                  bool isBounce = tx.resolvedReason?.toLowerCase() ==
                          'bounce' ||
                      tx.resolvedReason?.toLowerCase() == 'internal transfer';
                  if (!isBounce) {
                    if (tx.type == 'income') {
                      totalNet += tx.amount;
                    } else if (tx.type == 'expense') {
                      totalNet -= tx.amount;
                    }
                  }
                }
              }
              final String sign = totalNet >= 0 ? '+' : '-';
              String subTitle = '';
              final nameUp = sender.senderName.toUpperCase();
              if (nameUp == 'CBE') {
                subTitle = 'Bank';
              } else if (nameUp == 'TELEBIRR') {
                subTitle = 'E-money';
              } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                subTitle = 'Wallet';
              }

              Widget logoWidget = _getBankIconSmall(sender.senderName);
              List<Color> cardGradient;
              if (nameUp == 'CBE') {
                cardGradient = [
                  const Color(0xFF3D1B0F),
                  const Color(0xFF6E482F),
                  const Color(0xFF3D1B0F)
                ];
              } else if (nameUp == 'TELEBIRR') {
                cardGradient = [
                  const Color(0xFF0BA751),
                  const Color(0xFF88BF47),
                  const Color(0xFF0BA751)
                ];
              } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                cardGradient = [
                  const Color(0xFFAFAFB3),
                  const Color(0xFFFFFFFF),
                  const Color(0xFFAFAFB3)
                ];
              } else {
                cardGradient = [
                  const Color(0xFF1E1E26),
                  const Color(0xFF3E3E4A),
                  const Color(0xFF1E1E26)
                ];
              }

              final textColor = (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR')
                  ? Colors.black
                  : Colors.white;

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SenderDetailScreen(sender: sender)));
                },
                child: Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          border:
                              Border.all(color: cardGradient.first, width: 1.5),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(23),
                            gradient: SweepGradient(
                                center: Alignment.center,
                                transform: const GradientRotation(pi / 4),
                                colors: cardGradient),
                          ),
                          child: Stack(
                            children: [
                              Center(child: logoWidget),
                              Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sender.senderName,
                                          style: TextStyle(
                                              color: textColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (subTitle.isNotEmpty)
                                          Text(
                                            subTitle,
                                            style: TextStyle(
                                                color: textColor.withValues(
                                                    alpha: 0.7),
                                                fontSize: 7),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    Text(
                                      provider.isBalanceVisible
                                          ? '\$${NumberFormat('#,##0.00').format(senderBalance)}'
                                          : '\$****.**',
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF363640),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$sign${NumberFormat('#,##0').format(totalNet.abs())}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.normal),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCarousel(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final mostExpenseToday = provider.mostExpenseToday;
    final mostExpenseMonth = provider.mostExpenseThisMonth;
    final mostAffected = provider.mostAffectedAccount;
    final lessAffected = provider.lessAffectedAccount;

    final bannerData = [
      {
        'title': mostExpenseToday != null
            ? 'THE MOST EXPENSE TODAY'
            : 'NO EXPENSE TODAY',
        'main': mostExpenseToday != null
            ? mostExpenseToday['reason']
            : 'Keep Savings!',
        'icon': Icon(_getReasonIcon(mostExpenseToday?['reason']),
            color: const Color(0xFFF0B90B), size: 32)
      },
      {
        'title': 'THE MOST EXPENSE THIS MONTH',
        'main': mostExpenseMonth != null
            ? mostExpenseMonth['reason']
            : 'No Transactions',
        'icon': Icon(_getReasonIcon(mostExpenseMonth?['reason']),
            color: const Color(0xFFF0B90B), size: 32)
      },
      {
        'title': 'THE MOST AFFECTED ACCOUNT',
        'main': mostAffected?.senderName ?? 'N/A',
        'icon': _getBankIconSmall(mostAffected?.senderName, size: 36)
      },
      {
        'title': 'THE LESS AFFECTED ACCOUNT',
        'main': lessAffected?.senderName ?? 'N/A',
        'icon': _getBankIconSmall(lessAffected?.senderName, size: 36)
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 110,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Listener(
                    onPointerDown: (_) => _bannerTimer?.cancel(),
                    onPointerUp: (_) => _startAutoScroll(),
                    onPointerCancel: (_) => _startAutoScroll(),
                    child: PageView.builder(
                      controller: _bannerController,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final dataIndex = index % bannerData.length;
                        return _buildBannerItem(
                          key: ValueKey<int>(index),
                          title: bannerData[dataIndex]['title'] as String,
                          mainText: bannerData[dataIndex]['main'] as String,
                          iconWidget: bannerData[dataIndex]['icon'] as Widget,
                        );
                      },
                    ),
                  ),
                ),
                // Morphing Indicators inside the card area
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _bannerController,
                    builder: (context, child) {
                      double pageOffset = _bannerController.hasClients
                          ? (_bannerController.page ??
                              _bannerController.initialPage.toDouble())
                          : _bannerController.initialPage.toDouble();

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          bannerData.length,
                          (i) {
                            // Calculate smooth expansion/contraction based on exact scroll position
                            double difference =
                                ((pageOffset - i) % bannerData.length);
                            if (difference > bannerData.length / 2) {
                              difference -= bannerData.length;
                            } else if (difference < -bannerData.length / 2) {
                              difference += bannerData.length;
                            }
                            difference = difference.abs();

                            // difference is 0 when fully selected, 1 when one page away
                            double factor = 1.0 - difference.clamp(0.0, 1.0);

                            // Width goes from 6.0 (unselected) to 18.0 (selected)
                            double width = 6.0 + (12.0 * factor);
                            // Opacity goes from 0.2 (unselected) to 1.0 (selected)
                            double alpha = 0.2 + (0.8 * factor);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: width,
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: alpha),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerItem({
    required String title,
    required String mainText,
    required Widget iconWidget,
    Key? key,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF202029),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.labelGray,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  mainText,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8), // Reserve space for indicators
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: iconWidget,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(BuildContext context, String query) {
    final provider = Provider.of<FinanceProvider>(context);
    final allTransactions = _isShowingTodayOnly
        ? provider.transactionsForSelectedDate
        : provider.transactionsForSelectedMonth;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final filteredTransactions = allTransactions.where((tx) {
      final searchLower = query.toLowerCase();
      final nameStr = tx.name.toLowerCase();
      final senderStr = tx.sender.toLowerCase();
      final reasonStr = tx.reason?.toLowerCase() ?? '';
      final customReasonStr = tx.customReasonText?.toLowerCase() ?? '';
      final amountStr = tx.amount.toString();

      return nameStr.contains(searchLower) ||
          senderStr.contains(searchLower) ||
          reasonStr.contains(searchLower) ||
          customReasonStr.contains(searchLower) ||
          amountStr.contains(searchLower);
    }).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF202029),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTab('Month', !_isShowingTodayOnly, () {
                setState(() {
                  _isShowingTodayOnly = false;
                });
              }),
              const SizedBox(width: 32),
              _buildTab('Today', _isShowingTodayOnly, () {
                setState(() {
                  _isShowingTodayOnly = true;
                });
              }),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredTransactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(
                child: Text('No transactions found',
                    style: TextStyle(color: AppColors.labelGray)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.only(
                  top: 0.0, bottom: isKeyboardOpen ? 20.0 : 40.0),
              itemCount: filteredTransactions.length,
              itemBuilder: (context, index) {
                final tx = filteredTransactions[index];
                double impactPercent = 0;
                if (provider.totalBalance > 0) {
                  impactPercent = (tx.amount / provider.totalBalance) * 100;
                }
                // Only first item in the list gets the 'NEW' badge
                final bool isLatest = index == 0;
                return _buildTransactionItem(
                    context, tx, impactPercent, isLatest);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.labelGray,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, AppTransaction tx,
      double impactPercent, bool isLatest) {
    final bool isIncome = tx.type == 'income';
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final String amountStr = provider.isBalanceVisible
        ? NumberFormat('#,##0.0').format(tx.amount)
        : '****';
    final String label = isIncome ? 'Deposit' : 'Transferred';
    final subLabel = isIncome ? 'From ${tx.sender}' : 'For ${tx.sender}';

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transaction: tx)));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildBankAvatarSmall(tx.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      if (tx.isAutoDetected && isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE11D48),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Text('NEW',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      // Show REASON? on every transaction missing a reason
                      if (tx.reasonId == null &&
                          (tx.customReasonText == null ||
                              tx.customReasonText!.isEmpty) &&
                          (tx.reason == null || tx.reason!.isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0B90B),
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('REASON?',
                                style: TextStyle(
                                    color: Color(0xFF1F1F25),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subLabel,
                      style: const TextStyle(
                          color: AppColors.labelGray, fontSize: 10)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${isIncome ? '+' : '-'}$amountStr',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(isIncome ? Icons.trending_up : Icons.trending_down,
                        color: isIncome
                            ? const Color(0xFF3EB489)
                            : const Color(0xFFE11D48),
                        size: 10),
                    const SizedBox(width: 4),
                    Text('${impactPercent.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: isIncome
                                ? const Color(0xFF3EB489)
                                : const Color(0xFFE11D48),
                            fontSize: 9,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAvatarSmall(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    if (nameUp == 'CBE') {
      img = Image.asset('assets/images/CBE logo 1.png', width: 22, height: 22);
    } else if (nameUp == 'TELEBIRR') {
      img =
          Image.asset('assets/images/Telebirr Logo.png', width: 22, height: 22);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img =
          Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
    } else {
      img = Text(bankName.substring(0, min(1, bankName.length)).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10));
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
      child: Center(child: img),
    );
  }

  Widget _getBankIconSmall(String? name, {double size = 40}) {
    if (name == null) {
      return Icon(Icons.account_balance, color: Colors.white, size: size);
    }
    final nameUp = name.toUpperCase();
    if (nameUp == 'CBE') {
      return Image.asset('assets/images/CBE logo 1.png',
          width: size, height: size, fit: BoxFit.contain);
    } else if (nameUp == 'TELEBIRR') {
      return Image.asset('assets/images/Telebirr Logo.png',
          width: size, height: size, fit: BoxFit.contain);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return Image.asset('assets/images/CBEBirr Logo.png',
          width: size, height: size, fit: BoxFit.contain);
    }
    return Icon(Icons.account_balance, color: Colors.white, size: size);
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
