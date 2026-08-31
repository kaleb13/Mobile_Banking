import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/analytics_view_model.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../theme/app_theme.dart';
import 'dart:math';
import 'transaction_detail_screen.dart';
import 'notifications_screen.dart';
import '../../models/transaction.dart';
import '../../widgets/hold_to_refresh.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_search_bar.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_date_filter.dart';
import '../../widgets/app_reset_filter_button.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/usecases/transactions/filter_transactions_usecase.dart';
import '../../widgets/animated_balance_text.dart';
import '../../widgets/interactive_balance_chart.dart';
import '../../widgets/app_money_text.dart';

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
  bool _isBookmarkedOnly = false;
  AppDateFilterValue _dateFilterValue = const AppDateFilterValue.last30Days();
  String _senderFilter = 'All Senders';
  String _bankFilter = 'All Banks';
  String _sortBy = 'Date: Newest';
  int _displayedLimit = 30;
  bool _isSearchActive = false;
  bool _isFilterExpanded = false;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final ScrollController _topScrollController = ScrollController();
  final bool _isShowingTodayOnly = false;
  bool _isOverallChartVisible = false;
  String _chartFilter = '30D';
  final GlobalKey _topSectionKey = GlobalKey();
  double? _measuredTopSectionHeight;
  double _lastDynamicRestSize = 0.55;
  int _lastOverdueCount = -1;

  @override
  void initState() {
    super.initState();
    _topScrollController.addListener(_onTopScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateTopSectionHeight());
  }

  void _onTopScroll() {
    if (!mounted) return;
    Provider.of<SettingsViewModel>(context, listen: false)
        .setHomeTopScrollOffset(_topScrollController.hasClients ? _topScrollController.offset : 0.0);
  }

  @override
  void dispose() {
    _topScrollController.removeListener(_onTopScroll);
    _topScrollController.dispose();
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
              // Permanent Top-Right Ambient Glow
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
              _buildMainDashboardLayout(context),
              Consumer2<TransactionsViewModel, LoansViewModel>(
                builder: (context, txVM, loansVM, _) {
                  return _buildDraggableTransactionsSheet(context, txVM, loansVM);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPNLInfo(BuildContext context, bool isToday) {
    AppDrawer.show(
      context: context,
      builder: (ctx) {
        return AppDrawer(
          headerCard: AppDrawerHeaderCard(
            icon: Icons.auto_awesome_rounded,
            title: isToday ? "Today's PnL" : "Overall PnL",
          ),
          bottomAction: AppButton.primary(
            text: "Got It",
            height: 48,
            onPressed: () => Navigator.pop(ctx),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              isToday
                  ? "Today's PNL = (Today's Income + Cash Additions) - (Today's Expenses + Cash Spending).\n\nIt represents your net increase or decrease in wealth today."
                  : "Overall PNL = (All-time Income + Cash Additions) - (All-time Expenses + Cash Spending).\n\nThis shows your cumulative financial progress since using the app.",
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.70),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w400,
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
    if (r.contains('pass-through') || r.contains('pass through') || r.contains('bounce')) return Icons.undo_rounded;
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

        final bool heightChanged = (_measuredTopSectionHeight == null) ||
            ((_measuredTopSectionHeight! - newHeight).abs() > 3.0);

        if (heightChanged || forceAnimate) {
          if (heightChanged) {
            setState(() {
              _measuredTopSectionHeight = newHeight;
            });
          }
          if (forceAnimate && _sheetController.isAttached) {
            final currentSize = _sheetController.size;
            if ((currentSize - _lastDynamicRestSize).abs() < 0.15 || currentSize <= 0.60) {
              _sheetController.animateTo(
                newRestSize,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          }
          _lastDynamicRestSize = newRestSize;
        }
      }
    });
  }

  Widget _buildMainDashboardLayout(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.axis == Axis.vertical) {
          context.read<SettingsViewModel>().setHomeTopScrollOffset(notification.metrics.pixels);
        }
        return false;
      },
      child: HoldToRefresh(
        onRefresh: () => context.read<TransactionsViewModel>().refreshData(lastDays: 7),
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
                    Consumer<LoansViewModel>(
                      builder: (context, lVM, _) {
                        final currentOverdueCount = lVM.overdueLoans.length;
                        if (_lastOverdueCount != currentOverdueCount) {
                          _lastOverdueCount = currentOverdueCount;
                          _updateTopSectionHeight(forceAnimate: true);
                        }
                        if (lVM.overdueLoans.isNotEmpty) {
                          return _buildOverdueLoanBanner(context, lVM);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
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

  Widget _buildOverdueLoanBanner(BuildContext context, LoansViewModel loansVM) {
    final overdueCount = loansVM.overdueLoans.length;
    final firstOverdue = loansVM.overdueLoans.first;
    final totalRemaining = loansVM.overdueLoans
        .fold<double>(0, (sum, loan) => sum + loan.remainingAmount);

    return GestureDetector(
      onTap: () {
        final targetTab = firstOverdue.loanType == 'borrowed' ? 1 : 0;
        loansVM.setLoanTabIndex(targetTab);
        context.read<SettingsViewModel>().tabNavigationNotifier.value = 3;
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.15),
        ),
        child: Row(
          children: [
            AppBadge.destructive(
              text: overdueCount.toString(),
              size: AppBadgeSize.small,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Consumer<SettingsViewModel>(
                builder: (context, settingsVM, _) {
                  return Text(
                    overdueCount == 1
                        ? (settingsVM.isBalanceVisible
                            ? 'OVERDUE: ${firstOverdue.personName} (${firstOverdue.daysOverdue} days late — ${NumberFormat('#,###').format(firstOverdue.remainingAmount)} ETB)'
                            : 'OVERDUE: ${firstOverdue.personName} (${firstOverdue.daysOverdue} days late — ••••••••)')
                        : (settingsVM.isBalanceVisible
                            ? '$overdueCount LOANS ARE OVERDUE — Total: ${NumberFormat('#,###').format(totalRemaining)} ETB'
                            : '$overdueCount LOANS ARE OVERDUE — Total: ••••••••'),
                    style: const TextStyle(
                      color: AppColors.negative,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
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
    return Consumer3<AnalyticsViewModel, SettingsViewModel, TransactionsViewModel>(
      builder: (context, analyticsVM, settingsVM, txVM, _) {
        final cashVM = Provider.of<CashWalletViewModel>(context, listen: false);
        final netVal = _isShowingTodayOnly ? analyticsVM.netForSelectedDate : analyticsVM.netOverall;
        final pctVal = _isShowingTodayOnly ? analyticsVM.incomePercentageChange : analyticsVM.percentageChangeOverall;
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
                      // Label + Question Icon (before eye) + Visibility Eye Icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total balance',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (txVM.hasMultipleSims) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _showAccountBreakdownDrawer(context, txVM, cashVM, analyticsVM);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                                child: SvgPicture.asset(
                                  'assets/images/message_question_Icon.svg',
                                  width: 14,
                                  height: 14,
                                  colorFilter: const ColorFilter.mode(
                                    AppColors.textSecondary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              settingsVM.toggleBalanceVisibility();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
                              child: Icon(
                                settingsVM.isBalanceVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Large Animated Balance Display (Auto-scales down for high amounts e.g. 1M+ so it never truncates)
                      Builder(
                        builder: (context) {
                          final bool isTotalUnknown = txVM.transactions.isEmpty && analyticsVM.totalBalance == 0.0;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              settingsVM.toggleBalanceVisibility();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isTotalUnknown) ...[
                                    const CurrencySymbolWidget(
                                      size: 26,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  AnimatedBalanceText(
                                    value: analyticsVM.totalBalance,
                                    isMasked: !settingsVM.isBalanceVisible,
                                    isUnknown: isTotalUnknown,
                                    integerStyle: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1.0,
                                      height: 1.05,
                                    ),
                                    decimalStyle: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      height: 1.05,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
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
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    settingsVM.isBalanceVisible
                                        ? '${isPositive ? '+' : '-'}${NumberFormat('#,##0').format(netVal.abs())}'
                                        : '••••••',
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
                _buildStackedCardsDeck(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStackedCardsDeck(BuildContext context) {
    return Selector<SettingsViewModel, ({bool isBalanceVisible, Set<String> hiddenBanks, bool isHomeResting})>(
      selector: (_, s) => (
        isBalanceVisible: s.isBalanceVisible,
        hiddenBanks: s.hiddenBalanceBanks,
        isHomeResting: s.pageOffset <= 0.02,
      ),
      builder: (context, settingsData, _) {
        final txVM = Provider.of<TransactionsViewModel>(context);
        final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
        final senders = txVM.senders;

        const double baseLeftOffset = -36.0;
        const double leftStep = 18.0;
        const double homeW = 180.0;
        const double homeH = 188.0;
        const double deckWidth = 120.0;

        final activeSenders = txVM.activeSenders;

        // If swiping page transition is active, let MainShell flying overlay handle it
        if (senders.isEmpty || !settingsData.isHomeResting) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              settingsVM.animateToTab(1);
            },
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(width: deckWidth, height: homeH),
          );
        }

        // Render native stacked cards in-tree on Home Page for 100% synchronous scroll/pull
        final List<Widget> cardWidgets = [];
        final int stackCount = activeSenders.length.clamp(0, 3);

        for (int i = 0; i < stackCount; i++) {
          final sender = activeSenders[i];
          final String cardName = sender.senderName;

          final int deckIndex = i;
          final double deckLeftOffset = baseLeftOffset + deckIndex * leftStep;

          final double balance = txVM.balanceForSender(cardName);
          final int txCount = txVM.txCountForSender(cardName);

          final bool isBankHidden = settingsData.hiddenBanks.any(
            (b) => b.trim().toUpperCase() == cardName.trim().toUpperCase(),
          );
          final bool cardBalanceVisible =
              settingsData.isBalanceVisible && !isBankHidden;

          // Top-most card in the rendered stack dynamically takes the White version
          final bool isTop = (i == stackCount - 1);

          final Widget card = BankCardWidget(
            senderName: cardName,
            balance: balance,
            txCount: txCount,
            isBalanceVisible: cardBalanceVisible,
            isPaused: false,
            isTopCard: isTop,
            animationFactor: 0.0,
            onTap: () {
              HapticFeedback.selectionClick();
              settingsVM.animateToTab(1);
            },
          );

          cardWidgets.add(
            Positioned(
              left: deckLeftOffset + 36.0,
              top: 0,
              width: homeW,
              height: homeH,
              child: card,
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            settingsVM.animateToTab(1);
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: deckWidth,
            height: homeH,
            child: Stack(
              clipBehavior: Clip.none,
              children: cardWidgets,
            ),
          ),
        );
      },
    );
  }

  void _showAccountBreakdownDrawer(
    BuildContext context,
    TransactionsViewModel txVM,
    CashWalletViewModel cashVM,
    AnalyticsViewModel analyticsVM,
  ) {
    final settingsVM = Provider.of<SettingsViewModel>(context, listen: false);
    final fmt = NumberFormat('#,##0.00');

    AppDrawer.show(
      context: context,
      builder: (drawerCtx) {
        return AppDrawer(
          headerCard: AppDrawerHeaderCard(
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/message_question_Icon.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            title: 'Account Balances',
          ),
          bottomAction: AppButton.primary(
            text: 'Got it',
            onPressed: () => Navigator.pop(drawerCtx),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dual-account / Multi-SIM view: Collapsible per-SIM cards (collapsed by default)
              if (txVM.hasMultipleSims) ...[
                for (final slot in txVM.detectedSimSlots) ...[
                  Builder(
                    builder: (context) {
                      final sim = txVM.simCards.where((s) => s.simSlot == slot).firstOrNull;
                      final double simBal = txVM.totalBalanceForSim(slot);

                      // Non-zero bank balances under this SIM
                      final nonZeroBanks = <MapEntry<String, double>>[];
                      for (final sender in txVM.activeSenders) {
                        if (sender.senderName.trim().toUpperCase() == 'CASH WALLET') continue;
                        if (!txVM.isAccountPaused(sender.senderName, slot)) {
                          final bBal = txVM.balanceForAccount(sender.senderName, slot);
                          if (bBal > 0) {
                            nonZeroBanks.add(MapEntry(sender.senderName, bBal));
                          }
                        }
                      }

                      return _CollapsibleSimAccountCard(
                        slot: slot,
                        displayName: sim?.displayName,
                        totalBalance: simBal,
                        bankBalances: nonZeroBanks,
                        isBalanceVisible: settingsVM.isBalanceVisible,
                      );
                    },
                  ),
                ],
              ] else ...[
                // Single-SIM view: List only active banks with balance > 0 (compact, no icons)
                Builder(
                  builder: (context) {
                    final nonZeroSenders = txVM.activeSenders.where((sender) {
                      if (sender.senderName.trim().toUpperCase() == 'CASH WALLET') return false;
                      return txVM.balanceForSender(sender.senderName) > 0;
                    }).toList();

                    if (nonZeroSenders.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.cardSm),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final sender in nonZeroSenders)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sender.senderName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    settingsVM.isBalanceVisible
                                        ? '${fmt.format(txVM.balanceForSender(sender.senderName))} ETB'
                                        : '••••••••',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],


              // Cash Wallet (only if balance > 0)
              if (cashVM.balance > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.cardSm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Physical Cash',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        settingsVM.isBalanceVisible
                            ? '${fmt.format(cashVM.balance)} ETB'
                            : '••••••••',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              // Summary Total Card (Compact)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppRadius.cardSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Combined Net Assets',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      !settingsVM.isBalanceVisible
                          ? '••••••••'
                          : ((txVM.transactions.isEmpty && analyticsVM.totalBalance == 0.0)
                              ? 'Unknown'
                              : '${fmt.format(analyticsVM.totalBalance)} ETB'),
                      style: const TextStyle(
                        color: AppColors.brandGreen,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallChartSection(BuildContext context) {
    if (!_isOverallChartVisible) return const SizedBox.shrink();
    return Consumer3<TransactionsViewModel, CashWalletViewModel, SettingsViewModel>(
      builder: (context, txVM, cashVM, settingsVM, _) {
        final activeBankNames =
            txVM.activeSenders.map((s) => s.senderName).toSet();
        return InteractiveBalanceChart(
          transactions: txVM.transactions,
          cashTransactions: cashVM.cashTransactions,
          initialFilter: _chartFilter,
          isBalanceVisible: settingsVM.isBalanceVisible,
          accentColor: AppColors.positive,
          chartHeight: 120,
          allowedBanks: activeBankNames,
          onFilterChanged: (val) => setState(() => _chartFilter = val),
        );
      },
    );
  }





  Widget _buildBannerCarousel(BuildContext context) {
    return Consumer<AnalyticsViewModel>(
      builder: (context, analyticsVM, _) {
        final mostExpenseToday = analyticsVM.mostExpenseToday;
        final mostExpenseMonth = analyticsVM.mostExpenseThisMonth;
        final mostAffected = analyticsVM.mostAffectedAccount;
        final lessAffected = analyticsVM.lessAffectedAccount;

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
        'bgColor': AppColors.cardBoaBg,
        'darkIconColor': AppColors.cardBoaDarkIcon,
        'titleColor': AppColors.textPrimary,
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
      },
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

  Widget _buildDraggableTransactionsSheet(
      BuildContext context, TransactionsViewModel txVM, LoansViewModel loansVM) {

    final allSenders = ['All Senders', ...txVM.uniqueSenders];
    if (!allSenders.contains(_senderFilter)) {
      _senderFilter = 'All Senders';
    }

    final allBanks = ['All Banks', ...txVM.uniqueBanks];
    if (!allBanks.contains(_bankFilter)) {
      _bankFilter = 'All Banks';
    }

    final transactionsList = const FilterTransactionsUseCase().execute(
      transactions: txVM.transactions,
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

    final int visibleCount = _displayedLimit.clamp(0, transactionsList.length);
    final bool hasMore = transactionsList.length > visibleCount;

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final topPadding = mediaQuery.padding.top;
    final textScale = mediaQuery.textScaler.scale(1.0);

    final double estimatedTopContent =
        (loansVM.overdueLoans.isNotEmpty ? 54.0 : 0.0) +
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
                  color: AppColors.darkGreyText,
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
                child: AppSearchBar(
                  mode: AppSearchBarMode.icon,
                  centerTitle: true,
                  isExpanded: _isSearchActive,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  hint: 'Search by sender, bank, or reason...',
                  title: 'Transactions',
                  leading: GestureDetector(
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
                            : AppColors.darkGreyText,
                        size: 22,
                      ),
                    ),
                  ),
                  onExpandChanged: (expanded) {
                    setState(() {
                      _isSearchActive = expanded;
                    });
                    if (expanded) {
                      _sheetController.animateTo(
                        0.95,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _displayedLimit = 30;
                    });
                  },
                  onClear: () {
                    setState(() {
                      _searchQuery = '';
                      _displayedLimit = 30;
                    });
                  },
                  onClose: () {
                    setState(() {
                      _isSearchActive = false;
                      _searchQuery = '';
                      _displayedLimit = 30;
                    });
                  },
                  backgroundColor: AppColors.lightGreyBackground,
                  textColor: AppColors.darkCharcoal,
                  hintColor: AppColors.greyText,
                  iconColor: AppColors.darkGreyText,
                  closeIconColor: AppColors.darkCharcoal,
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
                        // ── Bookmark Toggle Filter Pill ──
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isBookmarkedOnly = !_isBookmarkedOnly;
                              _displayedLimit = 30;
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
                            if (val != null) {
                              setState(() {
                                _sortBy = val;
                                _displayedLimit = 30;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _typeFilter,
                          items: const ['All', 'Income', 'Expense'],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _typeFilter = val;
                                _displayedLimit = 30;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        AppDateFilter.light(
                          value: _dateFilterValue,
                          onChanged: (val) {
                            setState(() {
                              _dateFilterValue = val;
                              _displayedLimit = 30;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _bankFilter,
                          items: allBanks,
                          maxWidth: 90,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _bankFilter = val;
                                _displayedLimit = 30;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildWhiteFilterDropdown(
                          value: _senderFilter,
                          items: allSenders,
                          maxWidth: 100,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _senderFilter = val;
                                _displayedLimit = 30;
                              });
                            }
                          },
                        ),
                        if (_isBookmarkedOnly ||
                            _typeFilter != 'All' ||
                            _dateFilterValue.preset != AppDateFilterPreset.last30Days ||
                            _bankFilter != 'All Banks' ||
                            _senderFilter != 'All Senders' ||
                            _sortBy != 'Date: Newest') ...[
                          const SizedBox(width: 8),
                          AppResetFilterButton(
                            onTap: () {
                              setState(() {
                                _isBookmarkedOnly = false;
                                _typeFilter = 'All';
                                _dateFilterValue = const AppDateFilterValue.last30Days();
                                _bankFilter = 'All Banks';
                                _senderFilter = 'All Senders';
                                _sortBy = 'Date: Newest';
                                _displayedLimit = 30;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: transactionsList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.lightGreyBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: AppColors.mediumGreyText,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No transactions found',
                                style: TextStyle(
                                  color: AppColors.darkCharcoal,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No activity recorded for ${_dateFilterValue.label}.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.mediumGreyText,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.only(top: 4, bottom: 90),
                        itemCount: visibleCount + (hasMore ? 1 : 0),
                        separatorBuilder: (context, index) => const Divider(
                          height: 1,
                          thickness: 0.5,
                          indent: 72,
                          endIndent: 20,
                          color: AppColors.lightGreySurface,
                        ),
                        itemBuilder: (context, index) {
                          if (index == visibleCount) {
                            // Lazy load next page
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && _displayedLimit < transactionsList.length) {
                                setState(() {
                                  _displayedLimit += 30;
                                });
                              }
                            });
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.brandGreen.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
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
    final String label = isIncome ? 'Income' : 'Expense';
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
                      if (Provider.of<TransactionsViewModel>(context, listen: false)
                              .accountsForBank(tx.name)
                              .length >
                          1)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: SimBadge(simSlot: tx.simSlot),
                        ),
                      if (tx.isAutoDetected && isLatest)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: NewBadge(),
                        ),
                      if (tx.reasonId == null &&
                          (tx.customReasonText == null ||
                              tx.customReasonText!.isEmpty) &&
                          (tx.reason == null || tx.reason!.isEmpty) &&
                          !Provider.of<TransactionsViewModel>(context,
                                  listen: false)
                              .hasSplits(tx.id))
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
            AppMoneyText(
              amount: tx.amount,
              prefix: isIncome ? '+' : '-',
              decimalDigits: 2,
              style: const TextStyle(
                color: AppColors.darkCharcoal,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
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
      img = SvgPicture.asset('assets/images/CBE logo.svg', width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.slackPurple.withValues(alpha: 0.12);
    } else if (nameUp == 'TELEBIRR') {
      img = SvgPicture.asset(
        'assets/images/Telebirr_Logo.svg',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.telebirrGreen, BlendMode.srcIn),
      );
      bgColor = AppColors.telebirrGreenSoft; // Visible Telebirr soft green background
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = SvgPicture.asset('assets/images/CBEBirr_Logo.svg', width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cbeBirrPink.withValues(alpha: 0.10);
    } else if (nameUp.contains('AHADU')) {
      img = SvgPicture.asset('assets/images/Ahadu_Logo.svg', width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cardAhaduRed.withValues(alpha: 0.10);
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      img = SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg', width: 22, height: 22, fit: BoxFit.contain);
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      img = SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: 25,
        height: 25,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.cardDashenDark, BlendMode.srcIn),
      );
      bgColor = AppColors.cardDashenLight.withValues(alpha: 0.15);
    } else if (nameUp.contains('AWASH')) {
      img = SvgPicture.asset(
        'assets/images/Awash_Bank_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cardAwashDark.withValues(alpha: 0.12);
    } else if (nameUp.contains('CASH')) {
      img = SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: 20,
        height: 20,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.positive, BlendMode.srcIn),
      );
      bgColor = AppColors.positive.withValues(alpha: 0.12);
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
    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL')) {
      return SvgPicture.asset(
        'assets/images/CBE logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp == 'TELEBIRR') {
      return SvgPicture.asset(
        'assets/images/Telebirr_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return SvgPicture.asset(
        'assets/images/CBEBirr_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp.contains('AHADU')) {
      return SvgPicture.asset(
        'assets/images/Ahadu_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      return SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp.contains('AWASH')) {
      return SvgPicture.asset(
        'assets/images/Awash_Bank_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
      );
    } else if (nameUp.contains('CASH')) {
      return SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: overrideColor != null
            ? ColorFilter.mode(overrideColor, BlendMode.srcIn)
            : null,
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

class _CollapsibleSimAccountCard extends StatefulWidget {
  final int slot;
  final String? displayName;
  final double totalBalance;
  final List<MapEntry<String, double>> bankBalances;
  final bool isBalanceVisible;

  const _CollapsibleSimAccountCard({
    required this.slot,
    this.displayName,
    required this.totalBalance,
    required this.bankBalances,
    required this.isBalanceVisible,
  });

  @override
  State<_CollapsibleSimAccountCard> createState() => _CollapsibleSimAccountCardState();
}

class _CollapsibleSimAccountCardState extends State<_CollapsibleSimAccountCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final bg = widget.slot == 0 ? AppColors.sim1BadgeBg : AppColors.sim2BadgeBg;
    final hasNonZeroBanks = widget.bankBalances.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.cardSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Clickable Summary Header (Tapping toggles expansion if there are bank items)
          InkWell(
            onTap: hasNonZeroBanks
                ? () {
                    HapticFeedback.selectionClick();
                    setState(() => _isExpanded = !_isExpanded);
                  }
                : null,
            borderRadius: BorderRadius.circular(AppRadius.cardSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'SIM ${widget.slot + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (widget.displayName != null && widget.displayName!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.displayName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                  ],
                  Text(
                    !widget.isBalanceVisible
                        ? '••••••••'
                        : (widget.totalBalance == 0.0 && !hasNonZeroBanks
                            ? 'Unknown'
                            : '${fmt.format(widget.totalBalance)} ETB'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasNonZeroBanks) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Animated Collapsible Details (Hidden by default)
          if (_isExpanded && hasNonZeroBanks) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.surfaceElevated),
                  const SizedBox(height: 8),
                  for (final item in widget.bankBalances)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isBalanceVisible ? '${fmt.format(item.value)} ETB' : '••••••••',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

