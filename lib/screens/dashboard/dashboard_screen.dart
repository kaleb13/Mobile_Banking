import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart' as m;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile_banking_app/providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import 'dart:math';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../widgets/hold_to_refresh.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/app_badges.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _typeFilter = 'All';
  String _dateFilter = 'Any Time';
  String _senderFilter = 'All Senders';
  String _bankFilter = 'All Banks';
  bool _isSearchActive = false;
  bool _isFilterExpanded = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ScrollController _topScrollController = ScrollController();
  late PageController _bannerController;
  final bool _isShowingTodayOnly = false;
  Timer? _bannerTimer;
  final int _bannerLoopFactor = 10000;
  bool _isOverallChartVisible = false;
  String _chartFilter = '30D';
  double? _touchedX;
  final GlobalKey _topSectionKey = GlobalKey();
  double? _measuredTopSectionHeight;
  double _lastDynamicRestSize = 0.55;
  int _lastOverdueCount = -1;

  @override
  void initState() {
    super.initState();
    // Start PageController at a large central value for "infinite" scroll
    _bannerController = PageController(initialPage: _bannerLoopFactor ~/ 2);
    _startAutoScroll();
    _sheetController.addListener(_onSheetScroll);
    _topScrollController.addListener(_onTopScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTopSectionHeight());
  }

  void _onTopScroll() {
    if (!mounted) return;
    Provider.of<FinanceProvider>(context, listen: false)
        .setHomeTopScrollOffset(_topScrollController.hasClients ? _topScrollController.offset : 0.0);
  }

  void _onSheetScroll() {
    if (!mounted || !_sheetController.isAttached) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetTopY = screenHeight * (1.0 - _sheetController.size);
    Provider.of<FinanceProvider>(context, listen: false).setHomeSheetTopY(sheetTopY);
  }

  void _startAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (_bannerController.hasClients) {
        _bannerController.nextPage(
          duration: const Duration(milliseconds: 900),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetScroll);
    _topScrollController.removeListener(_onTopScroll);
    _topScrollController.dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
          ),
          child: Stack(
            children: [
              // Top background ambient glow — uses a RadialGradient instead of
              // ImageFilter.blur to avoid an expensive off-screen render pass.
              Positioned(
                top: -30,
                right: -100,
                width: 420,
                height: 420,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.telebirrGreen.withValues(alpha: 0.50),
                        AppColors.telebirrGreen.withValues(alpha: 0.22),
                        AppColors.telebirrGreen.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.38, 0.68, 1.0],
                    ),
                  ),
                ),
              ),
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

  void _showPNLInfo(BuildContext context, bool isToday) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard.withValues(alpha: 0.35), // Fully transparent glass background
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 25,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Row: Star/sparkle icon inline with white title text
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isToday ? "Today's PNL" : "Overall PNL",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Description: Smaller, clean text directly below title
                    Text(
                      isToday
                          ? "Today's PNL = (Today's Income + Cash Additions) - (Today's Expenses + Cash Spending).\nIt represents your net increase or decrease in wealth today."
                          : "Overall PNL = (All-time Income + Cash Additions) - (All-time Expenses + Cash Spending).\nThis shows your cumulative financial progress since using the app.",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 11.5,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Got It button — uses canvas.saveLayer to correctly apply
                    // BlendMode.overlay strictly to the text label against the
                    // button background (the ONLY correct Flutter approach).
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: CustomPaint(
                          painter: _OverlayButtonPainter(
                            backgroundColor: AppColors.positive,
                            label: "Got It",
                            borderRadius: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getReasonIcon(String? reason) {
    if (reason == null) return Icons.category_outlined;
    final r = reason.toLowerCase().trim();
    if (r.contains('food')) return Icons.restaurant;
    if (r.contains('drink')) return Icons.local_cafe;
    if (r.contains('transport')) return Icons.directions_car;
    if (r.contains('housing') || r.contains('rent')) return Icons.home;
    if (r.contains('utility') || r.contains('light')) return Icons.lightbulb;
    if (r.contains('goods') || r.contains('shopping')) return Icons.shopping_bag;
    if (r.contains('entertainment') || r.contains('movie')) return Icons.movie;
    if (r.contains('health') || r.contains('medical')) return Icons.medical_services;
    if (r.contains('education') || r.contains('school')) return Icons.school;
    if (r.contains('loan') || r.contains('debt')) return Icons.handshake_outlined;
    if (r.contains('cash')) return Icons.payments_outlined;
    if (r.contains('bounce')) return Icons.replay_rounded;
    if (r.contains('internal transfer')) return Icons.swap_horiz_rounded;
    if (r.contains('mobile') || r.contains('internet') || r.contains('airtime') || r.contains('phone')) return Icons.phone_android;
    if (r.contains('investment') || r.contains('saving') || r.contains('stock')) return Icons.trending_up;
    if (r.contains('salary')) return Icons.account_balance_wallet;
    return Icons.category_outlined;
  }



  void _updateTopSectionHeight({bool forceAnimate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final RenderBox? box =
          _topSectionKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final newHeight = box.size.height;
        final mediaQuery = MediaQuery.of(context);
        final screenHeight = mediaQuery.size.height;
        final topPadding = mediaQuery.padding.top;
        double newRestSize = (screenHeight - (newHeight + topPadding)) / screenHeight;
        newRestSize = newRestSize.clamp(0.20, 0.75);

        if (_measuredTopSectionHeight != newHeight || forceAnimate) {
          if (_measuredTopSectionHeight != newHeight) {
            setState(() {
              _measuredTopSectionHeight = newHeight;
            });
          }
          if (_sheetController.isAttached) {
            final currentSize = _sheetController.size;
            if (forceAnimate || (currentSize - _lastDynamicRestSize).abs() < 0.15 || currentSize <= 0.60) {
              _sheetController.animateTo(
                newRestSize,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
              );
            }
          }
          _lastDynamicRestSize = newRestSize;
        }
      }
      _onSheetScroll();
    });
  }

  Widget _buildMainDashboardLayout(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final currentOverdueCount = provider.overdueLoanCount;
    if (_lastOverdueCount != currentOverdueCount) {
      _lastOverdueCount = currentOverdueCount;
      _updateTopSectionHeight(forceAnimate: true);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.axis == Axis.vertical) {
          provider.setHomeTopScrollOffset(notification.metrics.pixels);
        }
        return false;
      },
      child: HoldToRefresh(
        onRefresh: () => provider.refreshData(lastDays: 7),
        child: SingleChildScrollView(
          controller: _topScrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  key: _topSectionKey,
                  children: [
                    if (provider.overdueLoans.isNotEmpty)
                      _buildOverdueLoanBanner(context),
                    const SizedBox(height: 8),
                    _buildHeader(context),
                    const SizedBox(height: 10),
                    _buildBalanceCard(context),
                    _buildOverallChartSection(context),
                    const SizedBox(height: 10),
                    _buildBannerCarousel(context),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              const SizedBox(height: 60), // Decoy Section below carousel banner
            ],
          ),
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
        final targetTab = firstOverdue.loanType == 'borrowed' ? 1 : 0;
        provider.setLoanTabIndex(targetTab);
        provider.animateToTab(3);
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      child: Center(
        child: DynamicNotificationPill(),
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

    final netVal = _isShowingTodayOnly ? provider.netForSelectedDate : provider.netOverall;
    final pctVal = _isShowingTodayOnly ? provider.incomePercentageChange : provider.percentageChangeOverall;
    final bool isPositive = netVal >= 0;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, top: 12.0, bottom: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Column: Total Balance & PNL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label + Visibility icon
                  GestureDetector(
                    onTap: provider.toggleBalanceVisibility,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Total balance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          provider.isBalanceVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Large Balance Display
                  GestureDetector(
                    onTap: provider.toggleBalanceVisibility,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const CurrencySymbolWidget(
                          size: 28,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: Text(
                                  fullyFormatted,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.0,
                                    height: 1.05,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '.$decimals',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  height: 1.05,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Sub-row: Today's / Overall PNL with Dashed Underline & Chart Toggle Arrow
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
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
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 1),
                                CustomPaint(
                                  size: const Size(double.infinity, 1),
                                  painter: DashedUnderlinePainter(
                                    color: AppColors.textSoft.withValues(alpha: 0.4),
                                  ),
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
                            _updateTopSectionHeight(forceAnimate: true);
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) _updateTopSectionHeight(forceAnimate: true);
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Text(
                                '${isPositive ? '+' : '-'}${NumberFormat('#,##0').format(netVal.abs())}',
                                style: TextStyle(
                                  color: isPositive ? AppColors.positive : AppColors.negative,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(',
                                style: TextStyle(
                                  color: isPositive ? AppColors.positive : AppColors.negative,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                isPositive ? Icons.trending_up : Icons.trending_down,
                                color: isPositive ? AppColors.positive : AppColors.negative,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${pctVal.abs().toStringAsFixed(2)}%)',
                                style: TextStyle(
                                  color: isPositive ? AppColors.positive : AppColors.negative,
                                  fontSize: 10,
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
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Right Column: Stacked Cards Deck
            _buildStackedCardsDeck(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildStackedCardsDeck(BuildContext context, FinanceProvider provider) {
    final senders = provider.senders;
    final t = provider.pageOffset.clamp(0.0, 1.0);

    // If swiping page transition is active (t > 0.05), let MainShell flying overlay handle it
    if (senders.isEmpty || t > 0.05) {
      return GestureDetector(
        onTap: () => provider.animateToTab(1),
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(width: 105, height: 185),
      );
    }

    // Render native stacked cards in-tree on Home Page for 100% synchronous scroll/pull
    const double baseLeftOffset = -42.0;
    const double leftStep = 22.0;
    const double homeW = 100.0;
    const double homeH = 185.0;

    final int totalCards = senders.length + 1;
    final List<Widget> cardWidgets = [];

    for (int i = 0; i < totalCards; i++) {
      final bool isCashWallet = i == senders.length;
      final String cardName =
          isCashWallet ? 'Cash Wallet' : senders[i].senderName;
      final bool isVisibleOnHome = !isCashWallet && i < 3;
      if (!isVisibleOnHome) continue;

      final int deckIndex = i;
      final double deckLeftOffset = baseLeftOffset + deckIndex * leftStep;

      final senderTxs = provider.transactions
          .where((tx) =>
              tx.name.trim().toUpperCase() == cardName.trim().toUpperCase())
          .toList();

      double balance = 0;
      final withBal = senderTxs.where((tx) => tx.totalBalance > 0);
      if (withBal.isNotEmpty) {
        balance = withBal.first.totalBalance;
      }

      final isPaused = provider.isTrackingPaused(cardName);

      final Widget card = BankCardWidget(
        senderName: cardName,
        balance: balance,
        txCount: senderTxs.length,
        isBalanceVisible: provider.isBalanceVisible,
        isPaused: isPaused,
        animationFactor: 0.0,
      );

      cardWidgets.add(
        Positioned(
          left: deckLeftOffset + 42.0,
          top: 0,
          width: homeW,
          height: homeH,
          child: card,
        ),
      );
    }

    return GestureDetector(
      onTap: () => provider.animateToTab(1),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 105,
        height: 185,
        child: Stack(
          clipBehavior: Clip.none,
          children: cardWidgets,
        ),
      ),
    );
  }

  Widget _buildOverallChartSection(BuildContext context) {
    if (!_isOverallChartVisible) return const SizedBox.shrink();
    return _buildOverallChartContent(context);
  }

  Widget _buildOverallChartContent(BuildContext context) {
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
    List<Color> lineColors = [AppColors.positive, AppColors.positive];

    // Fill: top strong → bottom fully transparent (always top→bottom)
    List<Color> fillColors = [
      AppColors.positive.withValues(alpha: 0.28),
      AppColors.positive.withValues(alpha: 0.0),
    ];

    if (_touchedX != null && spots.isNotEmpty) {
      final maxX = spots.last.x;
      if (maxX > 0) {
        double ratio = (_touchedX! / maxX).clamp(0.0, 1.0);
        lineStops = [0.0, ratio, ratio, 1.0];
        // Line: full left of indicator, nearly invisible right of it
        lineColors = [
          AppColors.positive,
          AppColors.positive,
          AppColors.positive.withValues(alpha: 0.08),
          AppColors.positive.withValues(alpha: 0.08),
        ];
        // Fill: dim the whole fill uniformly when touching
        fillColors = [
          AppColors.positive.withValues(alpha: 0.07),
          AppColors.positive.withValues(alpha: 0.0),
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
        'bgColor': AppColors.cardCbeBg,
        'darkIconColor': AppColors.cardCbeDarkIcon,
        'titleColor': AppColors.cardCbeTitle,
        'iconData': _getReasonIcon(mostExpenseToday?['reason']),
        'isBankIcon': false,
        'bankName': null,
      },
      {
        'title': 'THE MOST EXPENSE THIS MONTH',
        'main': mostExpenseMonth != null
            ? mostExpenseMonth['reason'] as String
            : 'No Transactions',
        'bgColor': AppColors.statCardExpenseMonthBg,
        'darkIconColor': AppColors.statCardExpenseMonthDarkIcon,
        'titleColor': AppColors.statCardExpenseMonthTitle,
        'iconData': _getReasonIcon(mostExpenseMonth?['reason']),
        'isBankIcon': false,
        'bankName': null,
      },
      {
        'title': 'THE MOST AFFECTED ACCOUNT',
        'main': mostAffected?.senderName ?? 'N/A',
        'bgColor': AppColors.cardDashenBg,
        'darkIconColor': AppColors.cardDashenDarkIcon,
        'titleColor': AppColors.cardDashenTitle,
        'iconData': Icons.account_balance,
        'isBankIcon': true,
        'bankName': mostAffected?.senderName,
      },
      {
        'title': 'THE LESS AFFECTED ACCOUNT',
        'main': lessAffected?.senderName ?? 'N/A',
        'bgColor': AppColors.cardCoopBg,
        'darkIconColor': AppColors.cardCoopDarkIcon,
        'titleColor': AppColors.cardCoopTitle,
        'iconData': Icons.account_balance,
        'isBankIcon': true,
        'bankName': lessAffected?.senderName,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.gold,
                size: 13,
              ),
              const SizedBox(width: 6),
              const Text(
                'SAVINGS & SPENDING INSIGHTS',
                style: TextStyle(
                  color: AppColors.textSoft,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                'Smart Tracking',
                style: TextStyle(
                  color: AppColors.telebirrGreen,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 50,
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 4, right: 16, top: 2, bottom: 2),
            clipBehavior: Clip.none,
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
                width: 185,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.3),
                      blurRadius: 5,
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
                              fontSize: 7.0,
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
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (isBankIcon && bankName != null)
                      _getBankIconSmall(bankName, size: 20, overrideColor: darkIconColor)
                    else
                      Icon(
                        iconData,
                        color: darkIconColor,
                        size: 20,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWhiteFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double? maxWidth,
  }) {
    final bool isDefault = value == 'All' ||
        value == 'Any Time' ||
        value == 'All Senders' ||
        value == 'All Banks';

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGreyBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault
              ? AppColors.lightGreyText.withValues(alpha: 0.3)
              : AppColors.darkCharcoal.withValues(alpha: 0.6),
          width: isDefault ? 1.0 : 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.darkCharcoal,
              size: 16,
            ),
          ),
          dropdownColor: Colors.white,
          style: TextStyle(
            color: AppColors.darkCharcoal,
            fontSize: 12,
            fontWeight: isDefault ? FontWeight.w500 : FontWeight.bold,
          ),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth ?? 150),
                child: Text(
                  item,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkCharcoal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDraggableTransactionsSheet(BuildContext context) {
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

    final transactionsList = allTransactions.where((tx) {
      if (_typeFilter == 'Incoming' && tx.type != 'income') return false;
      if (_typeFilter == 'Outgoing' && tx.type != 'expense') return false;

      if (_senderFilter != 'All Senders' && tx.sender != _senderFilter) {
        return false;
      }

      if (_bankFilter != 'All Banks' && tx.name != _bankFilter) {
        return false;
      }

      if (_dateFilter != 'Any Time') {
        final now = DateTime.now();
        final txDate = tx.date;
        if (_dateFilter == 'Today') {
          if (txDate.year != now.year ||
              txDate.month != now.month ||
              txDate.day != now.day) {
            return false;
          }
        } else if (_dateFilter == 'This Week') {
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          final startOfToday =
              DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          if (txDate.isBefore(startOfToday)) return false;
        } else if (_dateFilter == 'This Month') {
          if (txDate.year != now.year || txDate.month != now.month) {
            return false;
          }
        }
      }

      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final nameStr = tx.name.toLowerCase();
        final senderStr = tx.sender.toLowerCase();
        final reasonStr = tx.reason?.toLowerCase() ?? '';
        final customReasonStr = tx.customReasonText?.toLowerCase() ?? '';
        final amountStr = tx.amount.toString();
        final rawStr = tx.rawMessage.toLowerCase();

        final matchesSearch = nameStr.contains(searchLower) ||
            senderStr.contains(searchLower) ||
            reasonStr.contains(searchLower) ||
            customReasonStr.contains(searchLower) ||
            amountStr.contains(searchLower) ||
            rawStr.contains(searchLower);

        return matchesSearch;
      }

      return true;
    }).toList();

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final textScale = mediaQuery.textScaler.scale(1.0);

    final double estimatedTopContent =
        (provider.overdueLoans.isNotEmpty ? 54.0 : 0.0) +
            (_isOverallChartVisible ? 220.0 : 0.0) +
            (345.0 * textScale.clamp(1.0, 1.4));

    double dynamicRestSize;
    if (_measuredTopSectionHeight != null && _measuredTopSectionHeight! > 0) {
      dynamicRestSize =
          (screenHeight - (_measuredTopSectionHeight! + topPadding)) /
              screenHeight;
    } else {
      dynamicRestSize =
          (screenHeight - (topPadding + estimatedTopContent)) / screenHeight;
    }
    dynamicRestSize = dynamicRestSize.clamp(0.20, 0.75);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: dynamicRestSize,
      minChildSize: dynamicRestSize,
      maxChildSize: 0.95,
      snap: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
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
                child: InteractiveDragHandle(
                  color: const Color(0xFFCBD5E1),
                  width: 36,
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  onTap: () {
                    final bool isExpanded =
                        _sheetController.size > (dynamicRestSize + 0.95) / 2;
                    _sheetController.animateTo(
                      isExpanded ? dynamicRestSize : 0.95,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  onVerticalDragUpdate: (details) {
                    final double delta = details.primaryDelta ?? 0;
                    final double currentSize = _sheetController.size;
                    final double newSize = (currentSize - delta / screenHeight)
                        .clamp(dynamicRestSize, 0.95);
                    _sheetController.jumpTo(newSize);
                  },
                  onVerticalDragEnd: (details) {
                    final double currentSize = _sheetController.size;
                    final double mid = (dynamicRestSize + 0.95) / 2;
                    final double target = (currentSize >= mid ||
                            (details.velocity.pixelsPerSecond.dy < -200))
                        ? 0.95
                        : dynamicRestSize;
                    _sheetController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    );
                  },
                ),
              ),

              // Search & Header Row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _isSearchActive
                    ? Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.lightGreyBackground,
                          borderRadius: BorderRadius.circular(21),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            const Icon(Icons.search_rounded,
                                color: AppColors.darkGreyText, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                style: const TextStyle(
                                    color: AppColors.darkCharcoal,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by sender, bank, or reason...',
                                  hintStyle: const TextStyle(
                                      color: AppColors.greyText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  suffixIconConstraints: const BoxConstraints(
                                    minHeight: 24,
                                    minWidth: 24,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _searchQuery = '';
                                              _searchController.clear();
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.only(
                                                right: 10.0),
                                            child: Icon(Icons.cancel_rounded,
                                                color: AppColors.greyText,
                                                size: 16),
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
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSearchActive = false;
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: const Icon(Icons.close_rounded,
                                    color: AppColors.darkCharcoal, size: 18),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                      )
                    : Row(
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
                              child: Icon(
                                Icons.filter_list,
                                color: _isFilterExpanded
                                    ? AppColors.darkCharcoal
                                    : AppColors.overlayDark50,
                                size: 22,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Transactions',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.darkCharcoal,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSearchActive = true;
                              });
                              _searchFocusNode.requestFocus();
                              _sheetController.animateTo(0.95,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.search,
                                color: AppColors.overlayDark50,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Filter Row Dropdowns (Hidden by default; appears when search active or filter icon tapped)
              if (_isSearchActive || _isFilterExpanded) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildWhiteFilterDropdown(
                          value: _typeFilter,
                          items: const ['All', 'Incoming', 'Outgoing'],
                          onChanged: (val) {
                            if (val != null) setState(() => _typeFilter = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _dateFilter,
                          items: const [
                            'Any Time',
                            'Today',
                            'This Week',
                            'This Month'
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _dateFilter = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _bankFilter,
                          items: allBanks,
                          maxWidth: 90,
                          onChanged: (val) {
                            if (val != null) setState(() => _bankFilter = val);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _senderFilter,
                          items: allSenders,
                          maxWidth: 100,
                          onChanged: (val) {
                            if (val != null) setState(() => _senderFilter = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: transactionsList.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions found',
                          style: TextStyle(
                            color: AppColors.greyText,
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
                          color: AppColors.lightGreySurface,
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
                            color: AppColors.darkCharcoal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
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
          ],
        ),
      ),
    );
  }

  Widget _buildBankAvatarSmallWhite(String bankName) {
    final nameUp = bankName.toUpperCase();
    Widget img;
    Color bgColor = AppColors.lightGreyBackground;

    if (nameUp == 'CBE') {
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
      bgColor = AppColors.telebirrGreenSoft; // Visible Telebirr soft green background
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset('assets/images/CBEBirr Logo.png', width: 22, height: 22);
      bgColor = AppColors.cbeBirrPink.withValues(alpha: 0.10);
    } else if (nameUp.contains('AHADU')) {
      img = Image.asset('assets/images/Ahadu_Logo.png', width: 22, height: 22);
      bgColor = AppColors.cardAhaduRed.withValues(alpha: 0.10);
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      img = SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg', width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else {
      img = Text(
        bankName.substring(0, min(1, bankName.length)).toUpperCase(),
        style: const TextStyle(color: AppColors.darkCharcoal, fontSize: 11, fontWeight: FontWeight.bold),
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
        'assets/images/CBE logo 1.webp',
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
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
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

/// Correctly applies BlendMode.overlay to text against a pill button background.
/// Uses canvas.saveLayer so both background and text share the same composited
/// GPU buffer — the only way BlendMode.overlay works correctly against a colored
/// background in Flutter's rendering pipeline.
class _OverlayButtonPainter extends CustomPainter {
  final Color backgroundColor;
  final String label;
  final double borderRadius;

  _OverlayButtonPainter({
    required this.backgroundColor,
    required this.label,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Step 1: Draw the solid button background pill
    canvas.drawRRect(rrect, Paint()..color = backgroundColor);

    // Step 2: Open a new compositing layer over the button area.
    // When canvas.restore() is called, this layer is composited back
    // onto the background using BlendMode.overlay.
    canvas.saveLayer(
      rect,
      Paint()..blendMode = BlendMode.overlay,
    );

    // Step 3: Draw the label text inside the saved layer.
    // The text is drawn in white — the overlay blend mode then blends
    // these white pixels against the green background underneath,
    // producing the correct overlay effect.
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Got It',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: m.TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, textOffset);

    // Step 4: Restore triggers the GPU to composite the text layer
    // back onto the green background using BlendMode.overlay.
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayButtonPainter old) =>
      old.backgroundColor != backgroundColor ||
      old.label != label ||
      old.borderRadius != borderRadius;
}
