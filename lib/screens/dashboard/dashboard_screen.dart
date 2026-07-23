import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
import '../../widgets/hold_to_refresh.dart';
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
  bool _isFilterExpanded = false;
  String _filterType = 'All';

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
          _searchLabelIndex = (_searchLabelIndex + 1) % 4;
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

      if (provider.userName != null && provider.userName!.isNotEmpty) {
        return '$greeting, Dear ${provider.userName}! Welcome back to your dashboard';
      }
      return '$greeting! Welcome back to your mobile banking overview';
    } else if (_searchLabelIndex == 1) {
      return 'Search & filter all bank accounts, wallets, and cash transactions instantly';
    } else if (_searchLabelIndex == 2) {
      final top = provider.topExpenseHighlight;
      if (top != null) {
        final amt = NumberFormat('#,###').format(top['amount']);
        return 'Highest Expense Today: ${top['reason']} — $amt ETB total';
      }
      return 'Track your daily spending, incomes, and cash balances seamlessly';
    } else {
      final fmtBalance = NumberFormat('#,##0.00').format(provider.totalBalance);
      return 'Total Balance: $fmtBalance ETB across all your linked accounts';
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
                AppColors.background,
                AppColors.bgMid,
              ],
            ),
          ),
          child: Stack(
            children: [
              Consumer<FinanceProvider>(
                builder: (context, financeProvider, child) {
                  return _buildMainDashboardLayout(context);
                },
              ),
              _buildDraggableTransactionsSheet(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainDashboardLayout(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    return HoldToRefresh(
      onRefresh: () => provider.refreshData(lastDays: 7),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  if (provider.overdueLoans.isNotEmpty)
                    _buildOverdueLoanBanner(context),
                  const SizedBox(height: 12),
                  _buildHeader(context),
                  const SizedBox(height: 14),
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
            const SizedBox(height: 340),
          ],
        ),
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
          color: AppColors.negative.withValues(alpha: 0.15),
          border: Border(
            bottom:
                BorderSide(color: AppColors.negative.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.negative,
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
                  color: AppColors.negative,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.negative, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        child: Container(
          height: 35,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Color(0xFF1A1A1A),
                    size: 17,
                  ),
                  if (provider.unreadNotificationCount > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
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
                        position: child.key == ValueKey(_searchLabelIndex)
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
                      color: Color(0xFF1A1A1A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400, // Regular weight
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                          TextStyle(color: AppColors.textSoft, fontSize: 13),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      provider.isBalanceVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textSoft,
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
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fullyFormatted,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
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
                        color: AppColors.textSoft,
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
                              color: AppColors.textSoft,
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
                                    AppColors.textSoft.withValues(alpha: 0.4)),
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
                                ? AppColors.positive
                                : AppColors.negative,
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
                                ? AppColors.positive
                                : AppColors.negative,
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
                              ? AppColors.positive
                              : AppColors.negative,
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
                                ? AppColors.positive
                                : AppColors.negative,
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
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.keyboard_double_arrow_right,
                      color: AppColors.background, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Overview',
                    style: TextStyle(
                      color: AppColors.background,
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
    List<Color> lineColors = [AppColors.gold, AppColors.gold];

    // Fill: top strong → bottom fully transparent (always top→bottom)
    List<Color> fillColors = [
      AppColors.gold.withValues(alpha: 0.28),
      AppColors.gold.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        // Line: full left of indicator, nearly invisible right of it
        lineColors = [
          AppColors.gold,
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.08),
          AppColors.gold.withValues(alpha: 0.08),
        ];
        // Fill: dim the whole fill uniformly when touching
        fillColors = [
          AppColors.gold.withValues(alpha: 0.07),
          AppColors.gold.withValues(alpha: 0.0),
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
                      color: isSelected ? Colors.white : AppColors.textSoft,
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
                      AppColors.cardGrayDark,
                      AppColors.cardGrayMid,
                      AppColors.cardGrayDark
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
                  color: AppColors.surfaceElevated,
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
              } else if (nameUp.contains('AHADU')) {
                subTitle = 'Bank';
              }

              Widget logoWidget = _getBankIconSmall(sender.senderName);
              List<Color> cardGradient;
              if (nameUp == 'CBE') {
                cardGradient = [
                  AppColors.cardBrownDark,
                  AppColors.cardBrownMid,
                  AppColors.cardBrownDark
                ];
              } else if (nameUp == 'TELEBIRR') {
                cardGradient = [
                  AppColors.success,
                  AppColors.cardLime,
                  AppColors.success
                ];
              } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
                cardGradient = [
                  AppColors.cardSilver,
                  AppColors.textPrimary,
                  AppColors.cardSilver
                ];
              } else if (nameUp.contains('AHADU')) {
                cardGradient = [
                  AppColors.cardAhaduPink,
                  AppColors.cardAhaduWhite,
                  AppColors.cardAhaduPink
                ];
              } else {
                cardGradient = [
                  AppColors.bgMid,
                  AppColors.cardGrayLight,
                  AppColors.bgMid
                ];
              }

              final textColor = (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR' || nameUp.contains('AHADU'))
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
                            color: AppColors.surfaceElevated,
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

    final bannerItems = [
      {
        'title': mostExpenseToday != null
            ? 'THE MOST EXPENSE TODAY'
            : 'NO EXPENSE TODAY',
        'main': mostExpenseToday != null
            ? mostExpenseToday['reason'] as String
            : 'Keep Savings!',
        'bgColor': const Color(0xFF1B5E4B),
        'darkIconColor': const Color(0xFF0F3A2E),
        'titleColor': const Color(0xFF88C9B8),
        'iconData': _getReasonIcon(mostExpenseToday?['reason']),
        'isBankIcon': false,
        'bankName': null,
      },
      {
        'title': 'THE MOST EXPENSE THIS MONTH',
        'main': mostExpenseMonth != null
            ? mostExpenseMonth['reason'] as String
            : 'No Transactions',
        'bgColor': const Color(0xFF9E4B2D),
        'darkIconColor': const Color(0xFF542412),
        'titleColor': const Color(0xFFE8BDB0),
        'iconData': _getReasonIcon(mostExpenseMonth?['reason']),
        'isBankIcon': false,
        'bankName': null,
      },
      {
        'title': 'THE MOST AFFECTED ACCOUNT',
        'main': mostAffected?.senderName ?? 'N/A',
        'bgColor': const Color(0xFFF9B825),
        'darkIconColor': const Color(0xFF805A04),
        'titleColor': const Color(0xFFFFF1C6),
        'iconData': Icons.account_balance,
        'isBankIcon': true,
        'bankName': mostAffected?.senderName,
      },
      {
        'title': 'THE LESS AFFECTED ACCOUNT',
        'main': lessAffected?.senderName ?? 'N/A',
        'bgColor': const Color(0xFF5E35B1),
        'darkIconColor': const Color(0xFF2E175B),
        'titleColor': const Color(0xFFD1C4E9),
        'iconData': Icons.account_balance,
        'isBankIcon': true,
        'bankName': lessAffected?.senderName,
      },
    ];

    return SizedBox(
      height: 56,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: bannerItems.length,
        itemBuilder: (context, index) {
          final item = bannerItems[index];
          final Color bgColor = item['bgColor'] as Color;
          final Color darkIconColor = item['darkIconColor'] as Color;
          final Color titleColor = item['titleColor'] as Color;
          final String title = item['title'] as String;
          final String mainText = item['main'] as String;
          final bool isBankIcon = item['isBankIcon'] as bool;
          final String? bankName = item['bankName'] as String?;
          final IconData iconData = item['iconData'] as IconData;

          return Container(
            width: 225,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        mainText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (isBankIcon && bankName != null)
                  _getBankIconSmall(bankName, size: 24, overrideColor: darkIconColor)
                else
                  Icon(
                    iconData,
                    color: darkIconColor,
                    size: 24,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDraggableTransactionsSheet(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);

    List<AppTransaction> transactionsList;
    if (_filterType == 'Today') {
      transactionsList = provider.transactionsForSelectedDate;
    } else if (_filterType == 'Month') {
      transactionsList = provider.transactionsForSelectedMonth;
    } else if (_filterType == 'Missing Reason') {
      transactionsList = provider.transactions.where((tx) =>
          tx.reasonId == null &&
          (tx.customReasonText == null || tx.customReasonText!.isEmpty) &&
          (tx.reason == null || tx.reason!.isEmpty)).toList();
    } else {
      transactionsList = provider.transactions;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.48,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.45, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCCCCC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Top Bar: Filter Icon (Left), Title (Center), Search Icon (Right 50% opacity)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isFilterExpanded = !_isFilterExpanded;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.filter_list,
                          color: Color(0x80000000), // 50% opacity dark text color
                          size: 22,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Transactions',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransactionSearchScreen(),
                          ),
                        );
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.search,
                          color: Color(0x80000000), // 50% opacity dark text color
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isFilterExpanded) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildWhiteFilterChip('All', _filterType == 'All'),
                      const SizedBox(width: 8),
                      _buildWhiteFilterChip('Month', _filterType == 'Month'),
                      const SizedBox(width: 8),
                      _buildWhiteFilterChip('Today', _filterType == 'Today'),
                      const SizedBox(width: 8),
                      _buildWhiteFilterChip('Missing Reason', _filterType == 'Missing Reason'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const SizedBox(height: 4),
              Expanded(
                child: transactionsList.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(
                            color: Color(0xFF888888),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 4, bottom: 90),
                        itemCount: transactionsList.length,
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 72,
                          endIndent: 20,
                          color: Color(0xFFF0F0F0),
                        ),
                        itemBuilder: (context, index) {
                          final tx = transactionsList[index];
                          final bool isLatest = index == 0;
                          return _buildWhiteTransactionItem(context, tx, isLatest);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWhiteFilterChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF555555),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
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
    final subLabel = isIncome ? 'From ${tx.sender}' : 'For ${tx.sender}';

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
                            color: Color(0xFF1A1A1A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      if (tx.isAutoDetected && isLatest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (tx.reasonId == null &&
                          (tx.customReasonText == null ||
                              tx.customReasonText!.isEmpty) &&
                          (tx.reason == null || tx.reason!.isEmpty))
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6D00),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'REASON?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: const TextStyle(
                      color: Color(0xFF757575),
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
            Text(
              '${isIncome ? '+' : '-'}$amountStr',
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankAvatarSmallWhite(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    Color bgColor = const Color(0xFFF2F4F7);

    if (nameUp == 'CBE') {
      img = Image.asset('assets/images/CBE logo 1.png', width: 22, height: 22);
      bgColor = const Color(0xFF4A154B).withValues(alpha: 0.12);
    } else if (nameUp == 'TELEBIRR') {
      img = Image.asset(
        'assets/images/Telebirr Logo.png',
        width: 22,
        height: 22,
        color: const Color(0xFF00A859),
        colorBlendMode: BlendMode.srcIn,
      );
      bgColor = const Color(0xFFDCF5E8); // Visible Telebirr soft green background
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
      bgColor = const Color(0xFFE91E63).withValues(alpha: 0.10);
    } else if (nameUp.contains('AHADU')) {
      img = Image.asset('assets/images/Ahadu_Logo.png', width: 22, height: 22);
      bgColor = const Color(0xFFC62828).withValues(alpha: 0.10);
    } else {
      img = Text(
        bankName.substring(0, min(1, bankName.length)).toUpperCase(),
        style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 11, fontWeight: FontWeight.bold),
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

  Widget _getBankIconSmall(String? name, {double size = 40, Color? overrideColor}) {
    if (name == null) {
      return Icon(Icons.account_balance, color: overrideColor ?? Colors.white, size: size);
    }
    final nameUp = name.toUpperCase();
    if (nameUp == 'CBE') {
      return Image.asset(
        'assets/images/CBE logo 1.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: overrideColor,
        colorBlendMode: overrideColor != null ? BlendMode.srcIn : null,
      );
    } else if (nameUp == 'TELEBIRR') {
      return Image.asset(
        'assets/images/Telebirr Logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: overrideColor,
        colorBlendMode: overrideColor != null ? BlendMode.srcIn : null,
      );
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return Image.asset(
        'assets/images/CBEBirr Logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: overrideColor,
        colorBlendMode: overrideColor != null ? BlendMode.srcIn : null,
      );
    } else if (nameUp.contains('AHADU')) {
      return Image.asset(
        'assets/images/Ahadu_Logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: overrideColor,
        colorBlendMode: overrideColor != null ? BlendMode.srcIn : null,
      );
    }
    return Icon(Icons.account_balance, color: overrideColor ?? Colors.white, size: size);
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
