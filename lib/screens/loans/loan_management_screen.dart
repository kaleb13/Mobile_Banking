import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';

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
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadLoans();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
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

  Widget _buildAmountText(double amount) {
    final fmt = NumberFormat('#,##0.00');
    final formattedStr = fmt.format(amount);
    final parts = formattedStr.split('.');
    final intPart = parts[0];
    final fracPart = parts.length > 1 ? '.${parts[1]}' : '.00';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: intPart,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: '$fracPart ETB',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              const Text(
                'Loan Tracker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddLoanSheet(provider: provider),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add Loan',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00875A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 9.5,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Lent Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildAmountText(totalLent),
                  ],
                ),
              ),

              // Center Divider
              Container(
                height: 30,
                width: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),

              // Borrowed Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Borrowed',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.arrow_downward,
                            color: Colors.white,
                            size: 9.5,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildAmountText(totalBorrowed),
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
                color: AppColors.textSoft.withValues(alpha: 0.3), size: 52),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(emptySubtitle,
                style:
                    const TextStyle(color: AppColors.textSoft, fontSize: 12),
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

  Widget _buildAmount(double amount, {bool isRightAligned = false}) {
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          TextSpan(
            text: fracPart,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
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
          color: AppColors.tabBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Borrower / Lender Name
            Text(
              loan.personName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
                    const Text(
                      'Remaining',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildAmount(loan.remainingAmount),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Paid',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildAmount(loan.paidAmount, isRightAligned: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Centered Progress Bar Section
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final filledWidth = (totalWidth * pct).clamp(0.0, totalWidth);
                return Container(
                  height: 28,
                  width: totalWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      if (filledWidth > 0)
                        Container(
                          width: filledWidth,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A86B),
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      Center(
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}% Repaid',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
                  child: GestureDetector(
                    onTap: () => _showPaymentSheet(context, provider, loan),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Record Payment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _confirmDelete(context, provider),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordPaymentSheet(loan: loan, provider: provider),
    );
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Delete Loan?', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete the loan for ${loan.personName}? All payment history will be lost.',
            style: const TextStyle(color: AppColors.textSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteLoan(loan.id!);
    }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          current.personName,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!current.isPaid) ...[
            GestureDetector(
              onTap: () async {
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
                        surface: AppColors.bgMid,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  await provider.updateLoanDueDate(current.id!, picked);
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_repeat_rounded,
                        color: Colors.white70, size: 14),
                    SizedBox(width: 4),
                    Text('Extend',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
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
                    border:
                        Border.all(color: accentColor.withValues(alpha: 0.4)),
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
              color: AppColors.overlay.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        border: Border.all(color: widget.accentColor.withValues(alpha: 0.2)),
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
        color: AppColors.overlay.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Remove payment?',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: AppColors.negative))),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.deleteLoanPaymentRecord(payment.id!, loanId);
              }
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
  final _trackedNameCtrl = TextEditingController();
  // Multi-select repayment sources — all banks selected by default
  late Set<String> _selectedBanks;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  // Tracking toggle — only relevant when prefilledTrackedSender is set
  bool _trackingEnabled = true;

  @override
  void initState() {
    super.initState();
    // Pre-select all available bank senders by default
    _selectedBanks = Set<String>.from(widget.provider.bankSenderNames);

    if (widget.prefilledAmount != null) {
      _amountCtrl.text = widget.prefilledAmount!.toStringAsFixed(2);
    }
    if (widget.prefilledName != null) {
      _nameCtrl.text = widget.prefilledName!;
    }
    if (widget.prefilledTrackedSender != null) {
      // Pre-fill the custom tracking field with the transaction's sender
      _trackedNameCtrl.text = widget.prefilledTrackedSender!;
      _selectedBanks = {widget.prefilledTrackedSender!};
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
    _trackedNameCtrl.dispose();
    super.dispose();
  }

  /// Opens a searchable bottom sheet where the user can pick from
  /// all person names already tracked in their transaction history.
  void _pickPersonName(BuildContext context, List<String> names) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NamePickerSheet(
        title: _loanType == 'lent' ? 'Pick Borrower' : 'Pick Lender',
        names: names,
        onSelected: (name) {
          setState(() => _nameCtrl.text = name);
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
    if (widget.prefilledTrackedSender != null) {
      // When opened from a transaction: use the editable custom name or null if
      // the user turned tracking off.
      if (_trackingEnabled) {
        final custom = _trackedNameCtrl.text.trim();
        tracked = custom.isNotEmpty ? custom : null;
      } else {
        tracked = null;
      }
    } else {
      // Standard flow: build from multi-select bank chips
      tracked = _selectedBanks.isEmpty ? null : _selectedBanks.join(',');
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final allPersonNames = widget.provider.allTrackedPersonNames;
    final bankNames = widget.provider.bankSenderNames;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('New Loan Record',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),

                // ── Loan type toggle ────────────────────────────────────
                if (widget.prefilledType == null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _TypeToggle(
                          label: '↑ I Lent Money',
                          active: _loanType == 'lent',
                          activeColor: AppColors.positive,
                          onTap: () => setState(() => _loanType = 'lent'),
                        ),
                        _TypeToggle(
                          label: '↓ I Borrowed',
                          active: _loanType == 'borrowed',
                          activeColor: AppColors.warning,
                          onTap: () => setState(() => _loanType = 'borrowed'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Person name ─────────────────────────────────────────
                if (widget.prefilledName == null) ...[
                  // Label
                  Text(
                    _loanType == 'lent' ? 'Borrower\'s Name' : 'Lender\'s Name',
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  // Field row with optional 'pick from existing' button
                  Row(
                    children: [
                      Expanded(
                        child: _SheetField(
                          controller: _nameCtrl,
                          hint: _loanType == 'lent'
                              ? 'Borrower\'s name…'
                              : 'Lender\'s name…',
                          icon: Icons.person_outline_rounded,
                        ),
                      ),
                      if (allPersonNames.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _pickPersonName(context, allPersonNames),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.gold.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.gold
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.people_outline_rounded,
                                color: AppColors.gold, size: 20),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (allPersonNames.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Text(
                        'Tap 👤 to pick from ${allPersonNames.length} tracked name${allPersonNames.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            color: AppColors.textSoft.withValues(alpha: 0.6),
                            fontSize: 10),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

                // ── Amount ──────────────────────────────────────────────
                if (widget.prefilledAmount == null) ...[
                  _SheetField(
                      controller: _amountCtrl,
                      hint: 'Amount (ETB)…',
                      icon: Icons.attach_money_rounded,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: 12),
                ],

                // ── Due date ────────────────────────────────────────────
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.textSecondary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Return by: ${DateFormat('MMM d, y').format(_dueDate)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Tracked sender / repayment source ──────────────────
                // Case A: Opened from a transaction detail page — show compact
                //         editable tracking section with an enable/disable toggle.
                if (widget.prefilledTrackedSender != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Toggle row
                        Row(
                          children: [
                            const Icon(Icons.track_changes_rounded,
                                color: AppColors.gold, size: 18),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Track Repayment',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Auto-detect when this loan is repaid via SMS',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            AppSwitch(
                              value: _trackingEnabled,
                              onChanged: (v) =>
                                  setState(() => _trackingEnabled = v),
                            ),
                          ],
                        ),
                        // ── Tracked-name field (only when tracking is ON)
                        if (_trackingEnabled) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Repayment sender name',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _SheetField(
                                  controller: _trackedNameCtrl,
                                  hint: 'Name whose SMS triggers repayment…',
                                  icon: Icons.person_search_outlined,
                                ),
                              ),
                              if (widget.provider.allTrackedPersonNames
                                  .isNotEmpty) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (_) => _NamePickerSheet(
                                      title: 'Pick Tracked Sender',
                                      names:
                                          widget.provider.allTrackedPersonNames,
                                      onSelected: (name) => setState(
                                          () => _trackedNameCtrl.text = name),
                                    ),
                                  ),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.gold
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                        Icons.people_outline_rounded,
                                        color: AppColors.gold,
                                        size: 20),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4, top: 4),
                            child: Text(
                              'Leave as-is to track the original sender, or enter a different name',
                              style: TextStyle(
                                  color: AppColors.textSoft
                                      .withValues(alpha: 0.5),
                                  fontSize: 10),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          Text(
                            'Repayment will NOT be auto-detected. You can record it manually later.',
                            style: TextStyle(
                                color:
                                    AppColors.textSoft.withValues(alpha: 0.55),
                                fontSize: 10),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Case B: Standard flow (not from a transaction) — show bank chips
                if (widget.prefilledTrackedSender == null) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Repayment Source',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Auto-detects repayments from selected banks',
                              style: TextStyle(
                                  color: AppColors.textSoft, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      // "All" / "None" quick toggle
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
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Multi-select bank chips (all selected by default)
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
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold.withValues(alpha: 0.15)
                                : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.gold.withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 160),
                                child: isSelected
                                    ? const Icon(Icons.check_circle_rounded,
                                        key: ValueKey('check'),
                                        color: AppColors.gold,
                                        size: 14)
                                    : const Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        key: ValueKey('uncheck'),
                                        color: AppColors.textSecondary,
                                        size: 14),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                bank,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Note ────────────────────────────────────────────────
                _SheetField(
                    controller: _noteCtrl,
                    hint: 'Note (optional)…',
                    icon: Icons.notes_rounded),
                const SizedBox(height: 24),

                // ── Save button ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.background, strokeWidth: 2))
                        : const Text('Save Loan Record',
                            style: TextStyle(
                                color: AppColors.background,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  final ValueChanged<String> onSelected;

  const _NamePickerSheet({
    required this.title,
    required this.names,
    required this.onSelected,
  });

  @override
  State<_NamePickerSheet> createState() => _NamePickerSheetState();
}

class _NamePickerSheetState extends State<_NamePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.names;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Text(widget.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),

          // Search field
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary, size: 18),
              hintText: 'Search…',
              hintStyle:
                  TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: AppColors.surfaceCard,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),

          // Results list (capped height)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No matching names found',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: AppColors.overlay, height: 1, thickness: 1),
                    itemBuilder: (_, i) {
                      final name = _filtered[i];
                      return InkWell(
                        onTap: () {
                          widget.onSelected(name);
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppColors.gold
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14)),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary, size: 16),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
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
            border: active
                ? Border.all(color: activeColor.withValues(alpha: 0.4))
                : null,
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
  final IconData icon;
  final TextInputType? keyboardType;
  const _SheetField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
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
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    final isLent = widget.loan.loanType == 'lent';
    final accentColor =
        isLent ? AppColors.positive : AppColors.warning;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLent
                  ? 'Record payment from ${widget.loan.personName}'
                  : 'Record repayment to ${widget.loan.personName}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${NumberFormat('#,##0.00').format(widget.loan.remainingAmount)} ETB remaining',
              style: TextStyle(color: accentColor, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _SheetField(
              controller: _amountCtrl,
              hint: 'Amount paid (ETB)…',
              icon: Icons.attach_money_rounded,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            _SheetField(
              controller: _noteCtrl,
              hint: 'Note (optional)…',
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : const Text('Confirm Payment',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
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
        border:
            Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
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
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06)),
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
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.06)),
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
                                child: GestureDetector(
                                  onTap: () async {
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
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.positive
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.positive
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            color: AppColors.positive, size: 14),
                                        SizedBox(width: 6),
                                        Text('Approve',
                                            style: TextStyle(
                                                color: AppColors.positive,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Reject
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
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
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.negative
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.negative
                                              .withValues(alpha: 0.35)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.close_rounded,
                                            color: AppColors.negative,
                                            size: 14),
                                        SizedBox(width: 6),
                                        Text('Reject',
                                            style: TextStyle(
                                                color: AppColors.negative,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
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
