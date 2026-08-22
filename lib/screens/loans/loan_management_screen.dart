import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
import '../dashboard/bank_detail/bank_behind_info_panel.dart';
import '../dashboard/bank_detail/bank_metadata.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Loan Management Screen
// ─────────────────────────────────────────────────────────────────────────────
class LoanManagementScreen extends StatefulWidget {
  const LoanManagementScreen({super.key});

  @override
  State<LoanManagementScreen> createState() => _LoanManagementScreenState();
}

class _LoanManagementScreenState extends State<LoanManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // 0 = Lent (I gave money), 1 = Borrowed (I owe), 2 = Paid
  static const _lentColor = AppColors.positive; // green
  static const _borrowColor = AppColors.warning; // amber
  static const _paidColor = AppColors.textSoft; // 80% white (was muted blue)

  @override
  void initState() {
    super.initState();
    final initialTab = context.read<LoansViewModel>().activeLoanTabIndex.clamp(0, 2);
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabCtrl.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LoansViewModel>().loadLoans();
    });
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    context.read<LoansViewModel>().setLoanTabIndex(_tabCtrl.index);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final loansVM = Provider.of<LoansViewModel>(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final targetTab = loansVM.activeLoanTabIndex.clamp(0, 2);
    if (_tabCtrl.index != targetTab && !_tabCtrl.indexIsChanging) {
      _tabCtrl.animateTo(targetTab);
    }
    final lentLoans = loansVM.loanRecords
        .where((l) => l.loanType == 'lent' && !l.isPaid)
        .toList();
    final borrowedLoans = loansVM.loanRecords
        .where((l) => l.loanType == 'borrowed' && !l.isPaid)
        .toList();
    final paidLoans = loansVM.paidLoans;

    // Summary figures
    final totalLent =
        lentLoans.fold<double>(0, (s, l) => s + l.remainingAmount);
    final totalBorrowed =
        borrowedLoans.fold<double>(0, (s, l) => s + l.remainingAmount);

    final bool hasPending = loansVM.pendingRepaymentRequests.isNotEmpty;
    final double cardRestingHeight = topSafeArea + (hasPending ? 218.0 : 172.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
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
              // ── Tab views (Rendered underneath, padded by card resting height) ──
              Padding(
                padding: EdgeInsets.only(top: cardRestingHeight),
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _LoanList(
                      loans: lentLoans,
                      accentColor: _lentColor,
                      emptyTitle: 'No active loans given',
                      emptySubtitle: 'Track money you\'ve lent to others',
                    ),
                    _LoanList(
                      loans: borrowedLoans,
                      accentColor: _borrowColor,
                      emptyTitle: 'No active debts',
                      emptySubtitle: 'Track money you\'ve borrowed from others',
                    ),
                    _LoanList(
                      loans: paidLoans,
                      accentColor: _paidColor,
                      emptyTitle: 'No settled loans yet',
                      emptySubtitle:
                          'Paid loans will appear here automatically',
                      showPaid: true,
                    ),
                  ],
                ),
              ),

              // ── Interactive Stacked Sliding Loan Card (On TOP so slide translates over body) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _InteractiveLoanCard(
                  totalLent: totalLent,
                  totalBorrowed: totalBorrowed,
                  lentCount: lentLoans.length,
                  borrowedCount: borrowedLoans.length,
                  settledCount: paidLoans.length,
                  tabController: _tabCtrl,
                  settingsVM: settingsVM,
                  loansVM: loansVM,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Interactive Sliding Loan Card & Behind Info Panel
// ─────────────────────────────────────────────────────────────────────────────
class _InteractiveLoanCard extends StatefulWidget {
  final double totalLent;
  final double totalBorrowed;
  final int lentCount;
  final int borrowedCount;
  final int settledCount;
  final TabController tabController;
  final SettingsViewModel settingsVM;
  final LoansViewModel loansVM;

  const _InteractiveLoanCard({
    required this.totalLent,
    required this.totalBorrowed,
    required this.lentCount,
    required this.borrowedCount,
    required this.settledCount,
    required this.tabController,
    required this.settingsVM,
    required this.loansVM,
  });

  @override
  State<_InteractiveLoanCard> createState() => _InteractiveLoanCardState();
}

class _InteractiveLoanCardState extends State<_InteractiveLoanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _dragOffset = 0.0;
  static const double _maxSlideDown = 184.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset =
          (_dragOffset + details.primaryDelta!).clamp(0.0, _maxSlideDown);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > 0.0) {
      _animCtrl.value = _dragOffset / _maxSlideDown;
      setState(() => _dragOffset = 0.0);
      _animCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _togglePeek() {
    if (_animCtrl.isAnimating) return;

    // Quick subtle bounce (~5-6% slide down) to act as a clue that the card can be dragged
    _animCtrl
        .animateTo(
          0.06,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
      if (mounted) {
        _animCtrl.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final fmt = NumberFormat('#,##0.00');
    final infoData = BankInfoData.forBank('Loan Tracker');

    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, _) {
        final double animatedSlide = _animCtrl.value * _maxSlideDown;
        final double currentSlide =
            (_dragOffset + animatedSlide).clamp(0.0, _maxSlideDown);
        final double revealProgress =
            (currentSlide / _maxSlideDown).clamp(0.0, 1.0);
        final double topCornerRadius =
            (currentSlide / 20.0).clamp(0.0, 1.0) * 24.0;

        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // ── Revealed Behind Info Card (Full Width behind front card) ──
            BankBehindInfoPanel(
              topSafeArea: topSafeArea,
              currentSlide: currentSlide,
              revealProgress: revealProgress,
              infoData: infoData,
            ),

            // ── Front Sliding Loan Card ──
            Transform.translate(
              offset: Offset(0, currentSlide),
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(topCornerRadius),
                    topRight: Radius.circular(topCornerRadius),
                    bottomLeft: const Radius.circular(28),
                    bottomRight: const Radius.circular(28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: AppHeader with Page Title & Add Loan Action in top right
                          AppHeader(
                            title: 'Loan Tracker',
                            showBackButton: false,
                            padding: EdgeInsets.zero,
                            trailing: AppButton.primary(
                              text: 'Add Loan',
                              icon: Icons.add_rounded,
                              fullWidth: false,
                              height: 28,
                              fontSize: 11.5,
                              iconSize: 13,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              onPressed: () {
                                AppBottomSheet.show(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => const AddLoanSheet(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Compact Sub-metric Pills (Lent Out & Borrowed)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      widget.tabController.animateTo(0),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration:
                                              const BoxDecoration(
                                            color: AppColors.positive,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Lent: ',
                                          style: TextStyle(
                                            color:
                                                AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  widget.settingsVM.isBalanceVisible
                                                      ? fmt.format(widget.totalLent)
                                                      : '••••••',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
                                                ),
                                              ),
                                              if (widget.settingsVM.isBalanceVisible) ...[
                                                const SizedBox(width: 3),
                                                const CurrencySymbolWidget(
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      widget.tabController.animateTo(1),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                      borderRadius:
                                          BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration:
                                              const BoxDecoration(
                                            color: AppColors.warning,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'Owed: ',
                                          style: TextStyle(
                                            color:
                                                AppColors.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Expanded(
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  widget.settingsVM.isBalanceVisible
                                                      ? fmt.format(widget.totalBorrowed)
                                                      : '••••••',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11.5,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow
                                                          .ellipsis,
                                                ),
                                              ),
                                              if (widget.settingsVM.isBalanceVisible) ...[
                                                const SizedBox(width: 3),
                                                const CurrencySymbolWidget(
                                                  color: Colors.white,
                                                  size: 10,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Pending approvals banner inside card
                          if (widget.loansVM.pendingRepaymentRequests
                              .isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _PendingApprovalsBanner(
                              requests: widget
                                  .loansVM.pendingRepaymentRequests,
                              loans: widget.loansVM.loanRecords,
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Primary Tab Bar inside the card
                          AppPrimaryTabBar(
                            tabs: const [
                              'Lent Out',
                              'Borrowed',
                              'Settled',
                            ],
                            controller: widget.tabController,
                            backgroundColor: AppColors.tabBackground,
                            margin: EdgeInsets.zero,
                          ),

                          // Grab Handle at Bottom of Card (Just like Bank Detail Page)
                          Center(
                            child: InteractiveDragHandle(
                              onTap: _togglePeek,
                              onVerticalDragUpdate: _onDragUpdate,
                              onVerticalDragEnd: _onDragEnd,
                              padding: const EdgeInsets.only(
                                  top: 10, bottom: 2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }


// ─────────────────────────────────────────────────────────────────────────────
// Loan List (per tab)
// ─────────────────────────────────────────────────────────────────────────────
class _LoanList extends StatelessWidget {
  final List<LoanRecord> loans;
  final Color accentColor;
  final String emptyTitle;
  final String emptySubtitle;
  final bool showPaid;

  const _LoanList({
    required this.loans,
    required this.accentColor,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.showPaid = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.only(top: 80, bottom: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.handshake_outlined,
                  color: context.themeTextSecondary.withValues(alpha: 0.5), size: 52),
              const SizedBox(height: 16),
              Text(emptyTitle,
                  style: TextStyle(
                      color: context.themeTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 6),
              Text(emptySubtitle,
                  style:
                      TextStyle(color: context.themeTextSecondary, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 140),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      itemCount: loans.length,
      itemBuilder: (ctx, i) => _LoanCard(
        loan: loans[i],
        accentColor: accentColor,
        showPaid: showPaid,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Loan Card
// ─────────────────────────────────────────────────────────────────────────────
class _LoanCard extends StatelessWidget {
  final LoanRecord loan;
  final Color accentColor;
  final bool showPaid;
  const _LoanCard(
      {required this.loan, required this.accentColor, this.showPaid = false});

  Widget _buildAmount(BuildContext context, double amount, {bool isRightAligned = false}) {
    final settingsVM = context.watch<SettingsViewModel>();
    if (!settingsVM.isBalanceVisible) {
      return Text(
        '••••••••',
        textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          color: context.themeTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      );
    }
    final fmt = NumberFormat('#,##0.00');
    final formattedStr = fmt.format(amount);
    final parts = formattedStr.split('.');
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? '.${parts[1]}' : '.00';

    return RichText(
      textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
      text: TextSpan(
        children: [
          TextSpan(
            text: intPart,
            style: TextStyle(
              color: context.themeTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          TextSpan(
            text: fracPart,
            style: TextStyle(
              color: context.themeTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loansVM = context.read<LoansViewModel>();
    final pct = loan.progressPercent;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      onTap: () => _openDetail(context),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Borrower / Lender Name + Overdue Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    loan.personName,
                    style: TextStyle(
                      color: context.themeTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loan.isOverdue && !showPaid) ...[
                  const SizedBox(width: 8),
                  AppBadge.destructive(
                    text: '${loan.daysOverdue}d OVERDUE',
                    icon: Icons.warning_amber_rounded,
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Amounts Row: Remaining and Paid side by side
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        color: context.themeTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildAmount(context, loan.remainingAmount),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Paid',
                      style: TextStyle(
                        color: context.themeTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildAmount(context, loan.paidAmount, isRightAligned: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Centered Progress Bar Section (Reused CustomProgressBar Component)
            CustomProgressBar(
              progress: pct,
              height: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.13),
              progressColor: AppColors.emeraldBright,
              centerLabel: '${(pct * 100).toStringAsFixed(0)}% Repaid',
              labelInFilledOnly: false,
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            // Watching & Date Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    loan.loanType == 'lent'
                        ? 'Borrower: ${loan.personName}'
                        : 'Lender: ${loan.personName}',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('MMM d').format(loan.dueDate),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action Buttons Row
            if (showPaid || loan.isPaid) ...[
              // Settled Loan Actions: View Details + Delete
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      text: 'View Details',
                      icon: Icons.receipt_long_outlined,
                      height: 42,
                      onPressed: () => _openDetail(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, loansVM),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.buttonSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Active Loan Actions: Record Payment + Delete
              Row(
                children: [
                  Expanded(
                    child: AppButton.primary(
                      text: 'Record Payment',
                      icon: Icons.account_balance_wallet_outlined,
                      height: 42,
                      onPressed: () => _showPaymentSheet(context, loan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _confirmDelete(context, loansVM),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.buttonSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white70,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(loan: loan),
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, LoanRecord loan) {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(loan: loan),
    );
  }

  void _confirmDelete(BuildContext context, LoansViewModel loansVM) {
    AppConfirmDialog.show(
      context: context,
      title: 'Delete Loan?',
      message:
          'Are you sure you want to delete the loan for ${loan.personName}? All payment history will be lost.',
      confirmText: 'Delete',
      isDestructive: true,
      onConfirm: () async {
        await loansVM.deleteLoan(loan.id!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loan Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class LoanDetailScreen extends StatefulWidget {
  final LoanRecord loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
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
      ),
    );
  }

  Widget _buildCompactHeroCard(
    BuildContext context,
    LoanRecord current,
    Color accentColor,
    NumberFormat fmt,
    SettingsViewModel settingsVM,
    LoansViewModel loansVM,
    bool isLent,
  ) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            // Top Row: Status Badge + Due/Created Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (current.isPaid)
                  const AppBadge.success(
                    text: 'SETTLED • PAID',
                    size: AppBadgeSize.small,
                  )
                else if (current.isOverdue)
                  AppBadge.destructive(
                    text: 'OVERDUE BY ${current.daysOverdue}D',
                    size: AppBadgeSize.small,
                  )
                else if (isLent)
                  const AppBadge.success(
                    text: 'MONEY LENT',
                    size: AppBadgeSize.small,
                  )
                else
                  const AppBadge.warning(
                    text: 'DEBT BORROWED',
                    size: AppBadgeSize.small,
                  ),
                Text(
                  'Due ${DateFormat('MMM d, yyyy').format(current.dueDate)}',
                  style: TextStyle(
                    color: current.isOverdue ? AppColors.negative : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: current.isOverdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hero Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (settingsVM.isBalanceVisible) ...[
                  Text(
                    NumberFormat('#,##0').format(current.principalAmount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '.${(current.principalAmount % 1).toStringAsFixed(2).split('.')[1]}',
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const CurrencySymbolWidget(
                    size: 18,
                    color: AppColors.textSoft,
                  ),
                ] else
                  const Text(
                    '••••••••',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            CustomProgressBar(
              progress: current.progressPercent,
              height: 8,
              progressColor: accentColor,
            ),
            const SizedBox(height: 12),

            // Stats summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressStat(
                  'Principal',
                  settingsVM.isBalanceVisible ? '${fmt.format(current.principalAmount)} ETB' : '••••••••',
                  Colors.white,
                ),
                _buildProgressStat(
                  'Paid (${(current.progressPercent * 100).toStringAsFixed(0)}%)',
                  settingsVM.isBalanceVisible ? '${fmt.format(current.paidAmount)} ETB' : '••••••••',
                  AppColors.positive,
                ),
                _buildProgressStat(
                  'Remaining',
                  settingsVM.isBalanceVisible
                      ? '${fmt.format(current.remainingAmount)} ETB'
                      : '••••••••',
                  current.remainingAmount > 0 ? accentColor : AppColors.textSoft,
                ),
              ],
            ),

            // Quick Action Buttons directly in the hero if not paid
            if (!current.isPaid) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppButton.primary(
                      text: 'Record Payment',
                      icon: Icons.add_rounded,
                      height: 40,
                      fontSize: 13,
                      iconSize: 16,
                      onPressed: () {
                        AppBottomSheet.show(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => RecordPaymentSheet(
                            loan: current,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton.secondary(
                      text: 'Extend Due Date',
                      icon: Icons.event_repeat_rounded,
                      height: 40,
                      fontSize: 13,
                      iconSize: 16,
                      onPressed: () async {
                        final picked = await AppDatePickerDrawer.showSingleDate(
                          context: context,
                          initialDate: current.dueDate.isBefore(DateTime.now())
                              ? DateTime.now()
                              : current.dueDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          title: 'Extend Due Date',
                        );
                        if (picked != null && current.id != null) {
                          await loansVM.updateLoanDueDate(current.id!, picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoanInfoCard(BuildContext context, LoanRecord current, bool isLent) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LOAN OVERVIEW',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Type', isLent ? 'Money Lent Out' : 'Debt Borrowed', isLent ? AppColors.positive : AppColors.warning),
          _buildInfoDivider(),
          _buildInfoRow('Counterparty', current.personName, Colors.white),
          _buildInfoDivider(),
          _buildInfoRow('Creation Date', DateFormat('MMM d, yyyy').format(current.loanDate), Colors.white),
          _buildInfoDivider(),
          _buildInfoRow('Due Date', DateFormat('MMM d, yyyy').format(current.dueDate), current.isOverdue ? AppColors.negative : Colors.white),
          if (current.trackedSenderName != null && current.trackedSenderName!.isNotEmpty) ...[
            _buildInfoDivider(),
            _buildInfoRow('Monitored Banks', current.trackedSenderName!, Colors.white70),
          ],
          if (current.note != null && current.note!.isNotEmpty) ...[
            _buildInfoDivider(),
            _buildInfoRow('Note', current.note!, Colors.white70),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Divider(color: Colors.white.withValues(alpha: 0.05), height: 12);
  }

  Widget _buildProgressStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPaymentHistorySection(
      BuildContext context,
      LoanRecord current,
      List<LoanPayment> payments,
      Color accentColor,
      NumberFormat fmt,
      LoansViewModel loansVM) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REPAYMENT HISTORY',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              AppBadge.neutral(
                text: '${payments.length} ${payments.length == 1 ? 'payment' : 'payments'}',
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: AppColors.textSecondary.withValues(alpha: 0.35),
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No repayments recorded yet',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.white.withValues(alpha: 0.06),
                height: 16,
              ),
              itemBuilder: (ctx, idx) {
                final payment = payments[idx];
                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.positive,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '+${fmt.format(payment.amount)} ETB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, yyyy • hh:mm a').format(payment.paymentDate),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (payment.note != null && payment.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              payment.note!,
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.textSoft,
                        size: 18,
                      ),
                      tooltip: 'Remove payment',
                      onPressed: () {
                        AppConfirmDialog.show(
                          context: context,
                          title: 'Remove Payment?',
                          icon: Icons.delete_outline_rounded,
                          iconColor: AppColors.negative,
                          message:
                              'Are you sure you want to remove this repayment record of ${fmt.format(payment.amount)} ETB?',
                          confirmText: 'Remove',
                          cancelText: 'Cancel',
                          isDestructive: true,
                          onConfirm: () async {
                            await loansVM.deleteLoanPaymentRecord(payment.id!, current.id!);
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLinkedMessagesSection(
      BuildContext context,
      LoanRecord current,
      List<LoanPayment> payments,
      Color accentColor,
      NumberFormat fmt,
      TransactionsViewModel txVM) {
    // 1. Originating transaction
    final originTx = current.linkedTransactionId != null
        ? txVM.transactions
            .where((t) => t.id == current.linkedTransactionId)
            .cast<dynamic>()
            .firstOrNull
        : null;

    // 2. Repayment transactions
    final repaymentTxs = payments
        .where((p) => p.linkedTransactionId != null)
        .map((p) => (
              payment: p,
              tx: txVM.transactions
                  .where((t) => t.id == p.linkedTransactionId)
                  .cast<dynamic>()
                  .firstOrNull,
            ))
        .where((pair) => pair.tx != null)
        .toList();

    if (originTx == null && repaymentTxs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'LINKED SMS MESSAGES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Originating loan SMS
        if (originTx != null) ...[
          _LinkedMessageCard(
            label: current.isPaid
                ? '📄 Originating Transaction (Settled)'
                : '📄 Originating Transaction',
            sublabel:
                'Created this loan on ${DateFormat('MMM d, y').format(current.loanDate)}',
            rawMessage: originTx.rawMessage as String,
            accentColor: accentColor,
            isPrimary: true,
          ),
          if (repaymentTxs.isNotEmpty) const SizedBox(height: 10),
        ],

        // Repayment SMS messages
        ...repaymentTxs.asMap().entries.map((entry) {
          final idx = entry.key;
          final pair = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LinkedMessageCard(
              label: '💸 Repayment #${idx + 1}',
              sublabel:
                  '${fmt.format(pair.payment.amount)} ETB on ${DateFormat('MMM d, y').format(pair.payment.paymentDate)}',
              rawMessage: pair.tx.rawMessage as String,
              accentColor: AppColors.positive,
              isPrimary: false,
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loansVM = context.watch<LoansViewModel>();
    final settingsVM = context.watch<SettingsViewModel>();
    final txVM = context.watch<TransactionsViewModel>();
    final current = loansVM.loanRecords
        .firstWhere((l) => l.id == widget.loan.id, orElse: () => widget.loan);
    final payments = loansVM.paymentsForLoan(current.id!);
    final fmt = NumberFormat('#,##0.00');
    final isLent = current.loanType == 'lent';
    final accentColor = isLent ? AppColors.positive : AppColors.warning;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 10,
          leadingWidth: 48,
          title: const Text(
            'Loan Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: AppBackButton(),
          ),
          actions: [
            AppMenuButton<String>.dark(
              minWidth: 170,
              items: [
                if (!current.isPaid)
                  const AppMenuItem<String>(
                    value: 'extend',
                    label: 'Extend Due Date',
                    icon: Icons.calendar_today_rounded,
                  ),
                const AppMenuItem<String>(
                  value: 'delete',
                  label: 'Delete Loan',
                  icon: Icons.delete_outline_rounded,
                ),
              ],
              onSelected: (value) async {
                if (value == 'extend') {
                  final picked = await AppDatePickerDrawer.showSingleDate(
                    context: context,
                    initialDate: current.dueDate.isBefore(DateTime.now())
                        ? DateTime.now()
                        : current.dueDate,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    title: 'Extend Due Date',
                  );
                  if (picked != null && current.id != null) {
                    await loansVM.updateLoanDueDate(current.id!, picked);
                  }
                } else if (value == 'delete') {
                  final shouldDelete = await AppConfirmDialog.show(
                    context: context,
                    title: 'Delete Loan?',
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.negative,
                    message:
                        'Are you sure you want to delete this loan for ${current.personName}? All repayment records will be permanently removed.',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                    isDestructive: true,
                    onConfirm: () {},
                  );
                  if (shouldDelete == true &&
                      current.id != null &&
                      context.mounted) {
                    await loansVM.deleteLoan(current.id!);
                    if (context.mounted) {
                      Navigator.pop(context);
                      AppToast.info(context, message: 'Loan record deleted');
                    }
                  }
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _buildBackground(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 100, bottom: 0),
                    child: Column(
                      children: [
                        // ── 1. Compact Hero Card (Amount, Progress, Stats, & Actions) ──
                        _buildCompactHeroCard(context, current, accentColor, fmt, settingsVM, loansVM, isLent),
                        const SizedBox(height: 14),

                        // ── 2. Core Loan Info Card ─────────────────────────
                        _buildLoanInfoCard(context, current, isLent),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 3. Payment History Section ─────────────────────
                    _buildPaymentHistorySection(context, current, payments, accentColor, fmt, loansVM),

                    const SizedBox(height: 8),

                    // ── 4. Linked Messages Section ─────────────────────
                    _buildLinkedMessagesSection(context, current, payments, accentColor, fmt, txVM),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Linked Message Card ────────────────────────────────────────────────────
class _LinkedMessageCard extends StatefulWidget {
  final String label;
  final String sublabel;
  final String rawMessage;
  final Color accentColor;
  final bool isPrimary;

  const _LinkedMessageCard({
    required this.label,
    required this.sublabel,
    required this.rawMessage,
    required this.accentColor,
    required this.isPrimary,
  });

  @override
  State<_LinkedMessageCard> createState() => _LinkedMessageCardState();
}

class _LinkedMessageCardState extends State<_LinkedMessageCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        children: [
          // ── Header row (always visible) ─────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isPrimary
                          ? Icons.receipt_long_outlined
                          : Icons.payments_outlined,
                      color: widget.accentColor,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sublabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable raw message ───────────────────────────────────
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    widget.rawMessage,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.secondary(
                      text: 'Copy',
                      icon: Icons.copy_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.rawMessage));
                        AppToast.success(context, message: 'Message copied to clipboard');
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Loan Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class AddLoanSheet extends StatefulWidget {
  final String? linkedTransactionId;
  final double? prefilledAmount;
  final String? prefilledName;
  final String? prefilledTrackedSender;
  final String? prefilledType;

  const AddLoanSheet({
    super.key,
    this.linkedTransactionId,
    this.prefilledAmount,
    this.prefilledName,
    this.prefilledTrackedSender,
    this.prefilledType,
  });

  @override
  State<AddLoanSheet> createState() => _AddLoanSheetState();
}

class _AddLoanSheetState extends State<AddLoanSheet> {
  String _loanType = 'lent';
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Set<String> _selectedBanks = {};
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledAmount != null) {
      _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(2);
    }
    if (widget.prefilledName != null) {
      _nameCtrl.text = widget.prefilledName!;
    }
    if (widget.prefilledType != null) {
      _loanType = widget.prefilledType!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
      _selectedBanks = Set<String>.from(txVM.bankSenderNames);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _pickPersonName(BuildContext context, List<String> names) {
    final existing = _nameCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NamePickerSheet(
        title: _loanType == 'lent' ? 'Pick Borrower(s)' : 'Pick Lender(s)',
        names: names,
        initialSelected: existing,
        onSelected: (selectedString) {
          setState(() => _nameCtrl.text = selectedString);
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await AppDatePickerDrawer.showSingleDate(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      title: 'Select Due Date',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim().replaceAll(',', '');
    if (name.isEmpty || amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);

    String? tracked;
    if (_selectedBanks.isNotEmpty) {
      tracked = _selectedBanks.join(',');
    } else {
      tracked = null;
    }

    final loansVM = Provider.of<LoansViewModel>(context, listen: false);
    await loansVM.createLoan(
      loanType: _loanType,
      personName: name,
      trackedSenderName: tracked,
      principalAmount: amount,
      dueDate: _dueDate,
      linkedTransactionId: widget.linkedTransactionId,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  List<String> get _selectedPersonNames {
    return _nameCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  void _removePersonName(String nameToRemove) {
    final list = _selectedPersonNames;
    list.removeWhere((name) => name.toLowerCase() == nameToRemove.toLowerCase());
    setState(() {
      _nameCtrl.text = list.join(', ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final txVM = context.watch<TransactionsViewModel>();
    final allPersonNames = txVM.allTrackedPersonNames;
    final bankNames = txVM.bankSenderNames;

    return AppDrawer(
      heightFactor: 0.88,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.handshake_outlined,
        iconColor: _loanType == 'lent' ? AppColors.positive : AppColors.warning,
        title: 'Create Loan Record',
        subtitle: _loanType == 'lent'
            ? 'Track money lent out with SMS repayment monitoring.'
            : 'Track debt borrowed with SMS repayment monitoring.',
      ),
      bottomAction: AppButton.primary(
        text: 'Save Loan Record',
        isLoading: _saving,
        height: 48,
        onPressed: _saving ? null : _save,
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // ── Auto-detected Loan Type Toggle (When no prefilled type) ─
          if (widget.prefilledType == null) ...[
            AppPrimaryTabBar(
              tabs: const ['Money Lent Out', 'Debt Borrowed'],
              selectedIndex: _loanType == 'lent' ? 0 : 1,
              onTabChanged: (idx) {
                setState(() {
                  _loanType = idx == 0 ? 'lent' : 'borrowed';
                });
              },
              backgroundColor: AppColors.tabBackground,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
          ],

          // ── Person Name Dropdown Field ──────────────────────────
          Text(
            _loanType == 'lent' ? 'Person Name (Borrower)' : 'Person Name (Lender)',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SheetField(
            controller: _nameCtrl,
            hint: _loanType == 'lent' ? 'Select or type borrower\'s name…' : 'Select or type lender\'s name…',
            icon: Icons.person_outline_rounded,
            onTap: allPersonNames.isNotEmpty ? () => _pickPersonName(context, allPersonNames) : null,
            suffixIcon: allPersonNames.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: AppColors.textSecondary, size: 18),
                    onPressed: () => _pickPersonName(context, allPersonNames),
                  )
                : null,
            onChanged: (_) => setState(() {}),
          ),
          if (_selectedPersonNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedPersonNames.map((name) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.positive,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => _removePersonName(name),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.positive,
                            size: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 14),

          // ── Amount Field ────────────────────────────────────────
          const Text(
            'Principal Amount',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _SheetField(
            controller: _amountCtrl,
            hint: 'Amount…',
            prefixWidget: const CurrencySymbolWidget(
              size: 16,
              color: AppColors.textSecondary,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 14),

          // ── Return Due Date Picker ─────────────────────────────────
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.previewCardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Repayment Due Date: ${DateFormat('MMM d, y').format(_dueDate)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Real-Time Payment Tracking Section Card ────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.previewCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.positive.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: AppColors.positive,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Real-Time Repayment Tracking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Auto-detect repayment SMS messages',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'WATCH CHANNELS',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        if (_selectedBanks.length == bankNames.length) {
                          _selectedBanks.clear();
                        } else {
                          _selectedBanks = Set<String>.from(bankNames);
                        }
                      }),
                      child: Text(
                        _selectedBanks.length == bankNames.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(
                          color: AppColors.positive,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: bankNames.map((bank) {
                    final isSelected = _selectedBanks.contains(bank);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selectedBanks.remove(bank);
                        } else {
                          _selectedBanks.add(bank);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.positive.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? AppColors.positive
                                  : AppColors.textSoft,
                              size: 13,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              bank,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontSize: 11.5,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Collapsible Note / Remarks Component ───────────────────
          AppNoteCard(
            controller: _noteCtrl,
            title: 'NOTE / REMARKS',
            hintText: 'Add optional note or remarks…',
            isCollapsible: true,
            initialExpanded: false,
            backgroundColor: AppColors.previewCardBg,
            accentColor: _loanType == 'lent' ? AppColors.positive : AppColors.warning,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Name Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _NamePickerSheet extends StatefulWidget {
  final String title;
  final List<String> names;
  final Set<String>? initialSelected;
  final ValueChanged<String> onSelected;

  const _NamePickerSheet({
    required this.title,
    required this.names,
    this.initialSelected,
    required this.onSelected,
  });

  @override
  State<_NamePickerSheet> createState() => _NamePickerSheetState();
}

class _NamePickerSheetState extends State<_NamePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];
  late Set<String> _selectedNames;

  @override
  void initState() {
    super.initState();
    _filtered = widget.names;
    _selectedNames = widget.initialSelected != null
        ? Set<String>.from(widget.initialSelected!)
        : <String>{};

    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered =
            widget.names.where((n) => n.toLowerCase().contains(q)).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmSelection() {
    if (_selectedNames.isEmpty) {
      widget.onSelected('');
    } else {
      widget.onSelected(_selectedNames.join(', '));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDrawer(
      heightFactor: 0.70,
      title: widget.title,
      trailingHeader: _filtered.isNotEmpty
          ? GestureDetector(
              onTap: () => setState(() {
                if (_selectedNames.length == _filtered.length) {
                  _selectedNames.clear();
                } else {
                  _selectedNames = Set<String>.from(_filtered);
                }
              }),
              child: Text(
                _selectedNames.length == _filtered.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      bottomAction: AppButton.primary(
        height: 48,
        onPressed: _confirmSelection,
        text: _selectedNames.isEmpty
            ? 'Done (No contact selected)'
            : 'Done (${_selectedNames.length} contact${_selectedNames.length > 1 ? "s" : ""} selected)',
      ),
      child: Column(
        children: [
          // Search field with high contrast card style
          AppSearchBar(
            mode: AppSearchBarMode.bar,
            controller: _searchCtrl,
            hint: 'Search contacts…',
            backgroundColor: AppColors.previewCardBg,
            textColor: Colors.white,
            hintColor: AppColors.textSecondary.withValues(alpha: 0.6),
            iconColor: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),

          // Results list (capped height)
          Expanded(
            child: _filtered.isEmpty
                ? const Center(
                    child: Text('No matching contacts found',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final name = _filtered[i];
                      final isSelected = _selectedNames.contains(name);
                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.positive.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: AppRadius.cardRadius,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: AppRadius.cardRadius,
                          child: InkWell(
                            borderRadius: AppRadius.cardRadius,
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedNames.remove(name);
                                } else {
                                  _selectedNames.add(name);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.positive.withValues(alpha: 0.20)
                                          : Colors.white.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            color: isSelected ? AppColors.positive : Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                        fontSize: 13.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? AppColors.positive : Colors.white24,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? prefixWidget;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const _SheetField({
    required this.controller,
    required this.hint,
    this.icon,
    this.prefixWidget,
    this.keyboardType,
    this.onChanged,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      onChanged: onChanged,
      onTap: onTap,
      prefix: prefixWidget,
      prefixIcon: icon,
      suffix: suffixIcon,
      hint: hint,
      backgroundColor: AppColors.previewCardBg,
      borderRadius: BorderRadius.circular(16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Record Payment Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class RecordPaymentSheet extends StatefulWidget {
  final LoanRecord loan;
  const RecordPaymentSheet(
      {super.key, required this.loan});

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill remaining amount for convenience
    _amountCtrl.text = widget.loan.remainingAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amountStr = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    await context.read<LoansViewModel>().recordLoanPayment(
      loanId: widget.loan.id!,
      amount: amount,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isLent = widget.loan.loanType == 'lent';
    final accentColor =
        isLent ? AppColors.positive : AppColors.warning;

    return AppDrawer(
      heightFactor: null,
      isBodyScrollable: false,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.payments_outlined,
        iconColor: accentColor,
        title: isLent
            ? 'Record payment from ${widget.loan.personName}'
            : 'Record repayment to ${widget.loan.personName}',
        subtitle: '${NumberFormat('#,##0.00').format(widget.loan.remainingAmount)} ETB remaining',
      ),
      bottomAction: AppButton.primary(
        text: 'Confirm Payment',
        isLoading: _saving,
        height: 48,
        onPressed: _saving ? null : _save,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SheetField(
            controller: _amountCtrl,
            hint: 'Amount paid…',
            prefixWidget: const CurrencySymbolWidget(
              size: 16,
              color: AppColors.textSecondary,
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          _SheetField(
            controller: _noteCtrl,
            hint: 'Note (optional)…',
            icon: Icons.notes_rounded,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending Approvals Banner
// ─────────────────────────────────────────────────────────────────────────────
class _PendingApprovalsBanner extends StatefulWidget {
  final List<LoanRepaymentRequest> requests;
  final List<LoanRecord> loans;

  const _PendingApprovalsBanner({
    required this.requests,
    required this.loans,
  });

  @override
  State<_PendingApprovalsBanner> createState() =>
      _PendingApprovalsBannerState();
}

class _PendingApprovalsBannerState extends State<_PendingApprovalsBanner> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header row
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.requests.length} Pending Loan Approval${widget.requests.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.warning,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Approval cards — scrollable when many requests overflow
          if (_expanded)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.40,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.requests.map((req) {
                    final loan =
                        widget.loans.where((l) => l.id == req.loanId).toList();
                    final loanName = loan.isNotEmpty
                        ? loan.first.personName
                        : req.trackedName;
                    final fmt = NumberFormat('#,##0.00');

                    return Container(
                      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bgMid,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sender info
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: AppColors.warning, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.senderFound,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Sent ${fmt.format(req.amount)} ETB',
                                      style: const TextStyle(
                                          color: AppColors.positive,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Match info
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.compare_arrows_rounded,
                                    color: AppColors.textSecondary, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary),
                                      children: [
                                        const TextSpan(
                                            text: 'Incoming payment from '),
                                        TextSpan(
                                          text: req.senderFound,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const TextSpan(
                                            text: ' matches borrower '),
                                        TextSpan(
                                          text: loanName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Action buttons
                          Row(
                            children: [
                              // Approve
                              Expanded(
                                child: AppButton.primary(
                                  text: 'Approve',
                                  icon: Icons.check_rounded,
                                  height: 36,
                                  fontSize: 12,
                                  iconSize: 14,
                                  onPressed: () async {
                                    await context
                                        .read<LoansViewModel>()
                                        .approveLoanRepaymentRequest(req);
                                    if (context.mounted) {
                                      AppToast.success(
                                        context,
                                        message: 'Payment approved & applied',
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reject
                              Expanded(
                                child: AppButton.softDestructive(
                                  text: 'Reject',
                                  icon: Icons.close_rounded,
                                  height: 36,
                                  fontSize: 12,
                                  iconSize: 14,
                                  onPressed: () async {
                                    await context
                                        .read<LoansViewModel>()
                                        .rejectLoanRepaymentRequest(req);
                                    if (context.mounted) {
                                      AppToast.info(
                                        context,
                                        message: 'Payment request rejected',
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
