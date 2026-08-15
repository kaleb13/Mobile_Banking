import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

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
  static const _tabs = ['Lent Out', 'Borrowed', 'Settled'];

  static const _lentColor = AppColors.positive; // green
  static const _borrowColor = AppColors.warning; // amber
  static const _paidColor = AppColors.textSoft; // 80% white (was muted blue)

  @override
  void initState() {
    super.initState();
    final initialTab = context.read<FinanceProvider>().activeLoanTabIndex.clamp(0, 2);
    _tabCtrl = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _tabCtrl.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadLoans();
    });
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    context.read<FinanceProvider>().setLoanTabIndex(_tabCtrl.index);
  }

  @override
  void dispose() {
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final targetTab = provider.activeLoanTabIndex.clamp(0, 2);
    if (_tabCtrl.index != targetTab && !_tabCtrl.indexIsChanging) {
      _tabCtrl.animateTo(targetTab);
    }
    final lentLoans = provider.loanRecords
        .where((l) => l.loanType == 'lent' && !l.isPaid)
        .toList();
    final borrowedLoans = provider.loanRecords
        .where((l) => l.loanType == 'borrowed' && !l.isPaid)
        .toList();
    final paidLoans = provider.paidLoans;

    // Summary figures
    final totalLent =
        lentLoans.fold<double>(0, (s, l) => s + l.remainingAmount);
    final totalBorrowed =
        borrowedLoans.fold<double>(0, (s, l) => s + l.remainingAmount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: context.themeBackground,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: context.isLightMode
                ? const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.backgroundLight,
                      AppColors.bgMidLight,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.background,
                      AppColors.bgMid,
                    ],
                  ),
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _LoanHeader(
                  totalLent: totalLent,
                  totalBorrowed: totalBorrowed,
                  provider: provider,
                ),
              ),

              // ── Pending Approvals Banner ───────────────────────────────────
              if (provider.pendingRepaymentRequests.isNotEmpty)
                _PendingApprovalsBanner(
                  requests: provider.pendingRepaymentRequests,
                  loans: provider.loanRecords,
                  provider: provider,
                ),

              // ── Tab bar ─────────────────────────────────────────────────────────────
              AppCapsuleTabBar(
                tabs: _tabs,
                controller: _tabCtrl,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                fontSize: 13,
              ),

              // ── Tab views ─────────────────────────────────────────────────
              Expanded(
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
            ],
          ),
        ),
        floatingActionButton: null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Header (Plain text without cards)
// ─────────────────────────────────────────────────────────────────────────────
class _LoanHeader extends StatelessWidget {
  final double totalLent;
  final double totalBorrowed;
  final FinanceProvider provider;

  const _LoanHeader({
    required this.totalLent,
    required this.totalBorrowed,
    required this.provider,
  });

  Widget _buildAmountText(BuildContext context, double amount) {
    final fmt = NumberFormat('#,##0.00');
    final formattedStr = fmt.format(amount);
    final parts = formattedStr.split('.');
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? '.${parts[1]}' : '.00';

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: intPart,
              style: TextStyle(
                color: context.themeTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            TextSpan(
              text: '$fracPart ETB',
              style: TextStyle(
                color: context.themeTextSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title on Left, Add Loan button on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loan Tracker',
                style: TextStyle(
                  color: context.themeTextPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              AppButton.primary(
                text: 'Add Loan',
                icon: Icons.add,
                fullWidth: false,
                height: 28,
                fontSize: 11.5,
                iconSize: 13,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                onPressed: () {
                  AppBottomSheet.show(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddLoanSheet(provider: provider),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Summary metrics with badges & center divider
          Row(
            children: [
              // Lent Out Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AppBadge.success(
                      text: 'Lent Out',
                      icon: Icons.arrow_upward,
                      size: AppBadgeSize.small,
                    ),
                    const SizedBox(height: 6),
                    _buildAmountText(context, totalLent),
                  ],
                ),
              ),

              // Center Divider
              Container(
                height: 30,
                width: 1,
                color: context.themeBorder,
              ),

              // Borrowed Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const AppBadge.warning(
                      text: 'Borrowed',
                      icon: Icons.arrow_downward,
                      size: AppBadgeSize.small,
                    ),
                    const SizedBox(height: 6),
                    _buildAmountText(context, totalBorrowed),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
      return Center(
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
      physics: const BouncingScrollPhysics(),
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
    final provider = context.read<FinanceProvider>();
    final pct = loan.progressPercent;

    return GestureDetector(
      onTap: () => _openDetail(context, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.themeSurface,
          borderRadius: BorderRadius.circular(20),
        ),
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
                    'Watching: ${loan.trackedSenderName ?? loan.personName}',
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

            // Action Buttons Row: Record Payment & Delete
            Row(
              children: [
                Expanded(
                  child: AppButton.primary(
                    text: 'Record Payment',
                    icon: Icons.account_balance_wallet_outlined,
                    height: 42,
                    onPressed: () => _showPaymentSheet(context, provider, loan),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _confirmDelete(context, provider),
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
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, FinanceProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(loan: loan),
      ),
    );
  }

  void _showPaymentSheet(
      BuildContext context, FinanceProvider provider, LoanRecord loan) {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(loan: loan, provider: provider),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider) {
    AppConfirmDialog.show(
      context: context,
      title: 'Delete Loan?',
      message:
          'Are you sure you want to delete the loan for ${loan.personName}? All payment history will be lost.',
      confirmText: 'Delete',
      isDestructive: true,
      onConfirm: () async {
        await provider.deleteLoan(loan.id!);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loan Detail Screen
// ─────────────────────────────────────────────────────────────────────────────
class LoanDetailScreen extends StatelessWidget {
  final LoanRecord loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    // Get current version from provider
    final current = provider.loanRecords
        .firstWhere((l) => l.id == loan.id, orElse: () => loan);
    final payments = provider.paymentsForLoan(current.id!);
    final fmt = NumberFormat('#,##0.00');
    final isLent = current.loanType == 'lent';
    final accentColor =
        isLent ? AppColors.positive : AppColors.warning;

    return Scaffold(
      backgroundColor: context.themeBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.themeTextPrimary),
        title: Text(
          current.personName,
          style: TextStyle(
              color: context.themeTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!current.isPaid) ...[
            AppButton.pill(
              text: 'Extend',
              icon: Icons.event_repeat_rounded,
              isSelected: false,
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: current.dueDate.isBefore(DateTime.now())
                      ? DateTime.now()
                      : current.dueDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.positive,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  await provider.updateLoanDueDate(current.id!, picked);
                }
              },
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  AppBottomSheet.show(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        RecordPaymentSheet(loan: current, provider: provider),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, color: accentColor, size: 14),
                      const SizedBox(width: 4),
                      Text('Payment',
                          style: TextStyle(
                              color: accentColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          // ── Progress hero ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                // Circular progress
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: current.progressPercent,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.07),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(current.progressPercent * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w700),
                          ),
                          const Text('repaid',
                              style: TextStyle(
                                  color: AppColors.textSoft, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _DetailStat('Principal',
                        fmt.format(current.principalAmount), Colors.white),
                    _DetailStat('Paid', fmt.format(current.paidAmount),
                        AppColors.positive),
                    _DetailStat('Remaining',
                        fmt.format(current.remainingAmount), accentColor),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.07)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isLent ? '↑ Lent on' : '↓ Borrowed on',
                      style: const TextStyle(
                          color: AppColors.textSoft, fontSize: 12),
                    ),
                    Text(DateFormat('MMM d, y').format(current.loanDate),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      current.isOverdue
                          ? '⚠ Overdue by ${current.daysOverdue}d'
                          : '📅 Due on',
                      style: TextStyle(
                          color: current.isOverdue
                              ? AppColors.negative
                              : AppColors.textSoft,
                          fontSize: 11),
                    ),
                    Text(DateFormat('MMM d, y').format(current.dueDate),
                        style: TextStyle(
                            color: current.isOverdue
                                ? AppColors.negative
                                : Colors.white,
                            fontSize: 11,
                            fontWeight: current.isOverdue
                                ? FontWeight.w700
                                : FontWeight.normal)),
                  ],
                ),
                if (current.trackedSenderName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🔍 Tracking sender',
                          style: TextStyle(
                              color: AppColors.gold, fontSize: 11)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          current.trackedSenderName!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
                if (current.note != null && current.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📝 Note',
                          style: TextStyle(
                              color: AppColors.textSoft, fontSize: 11)),
                      Flexible(
                        child: Text(current.note!,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Payment history ────────────────────────────────────────────
          if (payments.isNotEmpty) ...[
            const Text('Payment History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...payments.map((p) => _PaymentTile(
                  payment: p,
                  loanId: current.id!,
                  accentColor: accentColor,
                )),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        color: AppColors.textSecondary.withValues(alpha: 0.3),
                        size: 40),
                    const SizedBox(height: 10),
                    const Text('No payments recorded yet',
                        style:
                            TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],

          // ── Linked Messages ────────────────────────────────────────────
          // Collect the originating transaction + any repayment transactions
          // that were auto-linked via SMS, then display their raw messages.
          Builder(builder: (context) {
            // 1. Originating transaction (the one that created this loan)
            final originTx = current.linkedTransactionId != null
                ? provider.transactions
                    .where((t) => t.id == current.linkedTransactionId)
                    .cast<dynamic>()
                    .firstOrNull
                : null;

            // 2. Repayment transactions linked to each payment
            final repaymentTxs = payments
                .where((p) => p.linkedTransactionId != null)
                .map((p) => (
                      payment: p,
                      tx: provider.transactions
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
                const SizedBox(height: 28),
                const Text(
                  'LINKED MESSAGES',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
          }),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _DetailStat(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: AppColors.textSoft, fontSize: 10)),
      ],
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
        color: widget.accentColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // ── Header row (always visible) ─────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isPrimary
                          ? Icons.receipt_long_outlined
                          : Icons.payments_outlined,
                      color: widget.accentColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.sublabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.accentColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // ── Expandable raw message ───────────────────────────────────
          if (_expanded)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                widget.rawMessage,
                style: const TextStyle(
                  color: AppColors.textSoft,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final LoanPayment payment;
  final int loanId;
  final Color accentColor;
  const _PaymentTile(
      {required this.payment, required this.loanId, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.payments_outlined, color: accentColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${NumberFormat('#,##0.00').format(payment.amount)} ETB',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                Text(
                  DateFormat('MMM d, y · hh:mm a').format(payment.paymentDate),
                  style:
                      const TextStyle(color: AppColors.textSoft, fontSize: 10),
                ),
                if (payment.note != null && payment.note!.isNotEmpty)
                  Text(payment.note!,
                      style: const TextStyle(
                          color: AppColors.textSoft, fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              AppConfirmDialog.show(
                context: context,
                title: 'Remove payment?',
                message: 'Are you sure you want to remove this payment record?',
                confirmText: 'Remove',
                isDestructive: true,
                onConfirm: () async {
                  await provider.deleteLoanPaymentRecord(payment.id!, loanId);
                },
              );
            },
            child: const Icon(Icons.close_rounded,
                color: AppColors.negative, size: 16),
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
  final FinanceProvider provider;
  final String? linkedTransactionId;
  final double? prefilledAmount;
  final String? prefilledName;
  final String? prefilledTrackedSender;
  final String? prefilledType;

  const AddLoanSheet({
    super.key,
    required this.provider,
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
  late Set<String> _selectedBanks;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  bool _isNoteExpanded = false;

  @override
  void initState() {
    super.initState();
    // Default select all available bank channels
    _selectedBanks = Set<String>.from(widget.provider.bankSenderNames);

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (ctx, child) {
        return Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.positive,
                surface: AppColors.bgMid,
              ),
            ),
            child: child!);
      },
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

    await widget.provider.createLoan(
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
    final allPersonNames = widget.provider.allTrackedPersonNames;
    final bankNames = widget.provider.bankSenderNames;

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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // ── Auto-detected Loan Type Toggle (When no prefilled type) ─
          if (widget.prefilledType == null) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _TypeToggle(
                    label: '↑ Money Lent Out',
                    active: _loanType == 'lent',
                    activeColor: AppColors.positive,
                    onTap: () => setState(() => _loanType = 'lent'),
                  ),
                  _TypeToggle(
                    label: '↓ Debt Borrowed',
                    active: _loanType == 'borrowed',
                    activeColor: AppColors.warning,
                    onTap: () => setState(() => _loanType = 'borrowed'),
                  ),
                ],
              ),
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
                    borderRadius: BorderRadius.circular(10),
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
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: bankNames.map((bank) {
                      final isSelected = _selectedBanks.contains(bank);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: GestureDetector(
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
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.positive.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
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
                                  size: 12,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  bank,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Expandable Note / Remarks Section ─────────────────────
          if (!_isNoteExpanded) ...[
            GestureDetector(
              onTap: () => setState(() => _isNoteExpanded = true),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: AppColors.positive, size: 15),
                    SizedBox(width: 4),
                    Text(
                      'Add Note / Remarks',
                      style: TextStyle(
                        color: AppColors.positive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Note / Remarks',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _noteCtrl.clear();
                    _isNoteExpanded = false;
                  }),
                  child: const Icon(Icons.close_rounded, color: AppColors.textSoft, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _SheetField(
              controller: _noteCtrl,
              hint: 'Optional note / remarks…',
              icon: Icons.notes_rounded,
            ),
          ],
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
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AppColors.surfaceElevated, height: 1, thickness: 1),
                    itemBuilder: (_, i) {
                      final name = _filtered[i];
                      final isSelected = _selectedNames.contains(name);
                      return InkWell(
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
                              horizontal: 4, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.positive.withValues(alpha: 0.15)
                                      : AppColors.gold.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        color: isSelected ? AppColors.positive : AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.positive : Colors.white,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isSelected ? AppColors.positive : AppColors.textSecondary,
                                size: 20,
                              ),
                            ],
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

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _TypeToggle(
      {required this.label,
      required this.active,
      required this.activeColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? activeColor.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? activeColor : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onTap: onTap,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: prefixWidget != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: prefixWidget,
              )
            : (icon != null
                ? Icon(icon, color: AppColors.textSecondary, size: 18)
                : null),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        suffixIcon: suffixIcon,
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: AppColors.previewCardBg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Record Payment Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class RecordPaymentSheet extends StatefulWidget {
  final LoanRecord loan;
  final FinanceProvider provider;
  const RecordPaymentSheet(
      {super.key, required this.loan, required this.provider});

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
    await widget.provider.recordLoanPayment(
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
  final FinanceProvider provider;

  const _PendingApprovalsBanner({
    required this.requests,
    required this.loans,
    required this.provider,
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
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
                        borderRadius: BorderRadius.circular(14),
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
                                            text: 'Possible match for '),
                                        TextSpan(
                                          text: loanName,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        TextSpan(
                                            text:
                                                ' (tracking: ${req.trackedName})'),
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
                                    await widget.provider
                                        .approveLoanRepaymentRequest(req);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Payment approved & applied ✓'),
                                          backgroundColor: AppColors.positive,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reject
                              Expanded(
                                child: AppButton.destructive(
                                  text: 'Reject',
                                  icon: Icons.close_rounded,
                                  height: 36,
                                  fontSize: 12,
                                  iconSize: 14,
                                  onPressed: () async {
                                    await widget.provider
                                        .rejectLoanRepaymentRequest(req);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Payment request rejected'),
                                          backgroundColor: AppColors.textSoft,
                                          duration: Duration(seconds: 2),
                                        ),
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
