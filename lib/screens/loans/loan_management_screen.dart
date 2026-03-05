import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/loan_record.dart';
import '../../models/loan_repayment_request.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

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

  static const _lentColor = Color(0xFF3EB489); // green
  static const _borrowColor = Color(0xFFE67E22); // amber
  static const _paidColor = AppColors.labelGray; // 80% white (was muted blue)

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
                Color(0xFF1F1F25),
                Color(0xFF1B1B21),
              ],
            ),
          ),
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _LoanHeader(
                    totalLent: totalLent, totalBorrowed: totalBorrowed),
              ),

              // ── Pending Approvals Banner ───────────────────────────────────
              if (provider.pendingRepaymentRequests.isNotEmpty)
                _PendingApprovalsBanner(
                  requests: provider.pendingRepaymentRequests,
                  loans: provider.loanRecords,
                  provider: provider,
                ),

              // ── Tab bar ───────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A34).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.labelGray,
                  labelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w400),
                  // Remove the default rectangular Material splash/ripple
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: _tabs.map((t) => Tab(height: 38, text: t)).toList(),
                ),
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
// Summary Header
// ─────────────────────────────────────────────────────────────────────────────
class _LoanHeader extends StatelessWidget {
  final double totalLent;
  final double totalBorrowed;
  const _LoanHeader({required this.totalLent, required this.totalBorrowed});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loan Manager',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3)),
              Text(
                'Track money owed and borrowed',
                style: TextStyle(color: AppColors.labelGray, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'You are owed',
                  amount: fmt.format(totalLent),
                  color: const Color(0xFF3EB489),
                  icon: Icons.arrow_circle_up_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'You owe',
                  amount: fmt.format(totalBorrowed),
                  color: const Color(0xFFE67E22),
                  icon: Icons.arrow_circle_down_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  const _SummaryCard(
      {required this.label,
      required this.amount,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(amount,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const Text('ETB',
              style: TextStyle(color: AppColors.labelGray, fontSize: 10)),
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
                color: AppColors.labelGray.withValues(alpha: 0.3), size: 52),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(
                    color: AppColors.labelGray,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(emptySubtitle,
                style:
                    const TextStyle(color: AppColors.labelGray, fontSize: 12),
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

  Widget _buildAvatar() {
    final nameUp = loan.personName.toUpperCase();
    final senderUp = (loan.trackedSenderName ?? '').toUpperCase();

    String? asset;
    if (nameUp.contains('TELEBIRR') || senderUp.contains('TELEBIRR')) {
      asset = 'assets/images/Telebirr Logo.png';
    } else if (nameUp.contains('CBE BIRR') ||
        nameUp.contains('CBEBIRR') ||
        senderUp.contains('CBE BIRR')) {
      asset = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('CBE') || senderUp.contains('CBE')) {
      asset = 'assets/images/CBE logo 1.png';
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: asset != null
            ? Image.asset(
                asset,
                width: 26,
                height: 26,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
              )
            : _fallbackAvatar(),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Text(
      loan.personName.isNotEmpty ? loan.personName[0].toUpperCase() : '?',
      style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    );
  }

  String _statusLabel() {
    if (loan.isPaid) return 'Paid';
    if (loan.isOverdue) return 'Overdue';
    final d = loan.daysUntilDue;
    if (d <= 0) return 'Due Today';
    if (d == 1) return '1 day left';
    if (d <= 7) return '$d days left';
    return DateFormat('MMM d').format(loan.dueDate);
  }

  Color _statusColor() {
    if (loan.isPaid) return AppColors.labelGray;
    if (loan.isOverdue) return AppColors.alertRed;
    final d = loan.daysUntilDue;
    if (d <= 3) return const Color(0xFFE67E22);
    return const Color(0xFF3EB489);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    final fmt = NumberFormat('#,##0.00');
    final shortFmt = NumberFormat('#,##0');
    final pct = loan.progressPercent;
    final statusColor = _statusColor();

    return GestureDetector(
      onTap: () => _openDetail(context, provider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: loan.isOverdue
                ? AppColors.alertRed.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Row 1: avatar + name + status ─────────────────────
                  Row(
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loan.personName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  loan.loanType == 'lent'
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: accentColor.withValues(alpha: 0.7),
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    loan.loanType == 'lent'
                                        ? 'Lent out'
                                        : 'Borrowed',
                                    style: const TextStyle(
                                        color: AppColors.labelGray,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (loan.note != null &&
                                    loan.note!.isNotEmpty) ...[
                                  const Text(' · ',
                                      style: TextStyle(
                                          color: AppColors.labelGray,
                                          fontSize: 11)),
                                  Flexible(
                                    child: Text(
                                      loan.note!,
                                      style: const TextStyle(
                                          color: AppColors.labelGray,
                                          fontSize: 11),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          _statusLabel(),
                          style: TextStyle(
                              color: statusColor.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Amounts row ────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Principal',
                                style: TextStyle(
                                    color: AppColors.labelGray, fontSize: 10)),
                            Text(
                              fmt.format(loan.principalAmount),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: -0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Remaining',
                                style: TextStyle(
                                    color: AppColors.labelGray, fontSize: 10)),
                            Text(
                              shortFmt.format(loan.remainingAmount),
                              style: TextStyle(
                                  color: loan.isPaid
                                      ? const Color(0xFF3EB489)
                                      : Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.3),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Progress bar ───────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}% repaid',
                          style: const TextStyle(
                              color: AppColors.labelGray, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Due ${DateFormat('MMM d, y').format(loan.dueDate)}',
                          style: TextStyle(
                              color: statusColor.withValues(alpha: 0.8),
                              fontSize: 10,
                              fontWeight: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // ── Tracked sender chip ────────────────────────────────
                  if (loan.trackedSenderName != null &&
                      loan.trackedSenderName!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          loan.isPaid
                              ? Icons.verified_rounded
                              : Icons.track_changes_rounded,
                          color: loan.isPaid
                              ? AppColors.labelGray
                              : AppColors.primaryBlue,
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            loan.isPaid
                                ? 'Auto-settled via: ${loan.trackedSenderName}'
                                : 'Watching: ${loan.trackedSenderName}',
                            style: TextStyle(
                                color: loan.isPaid
                                    ? AppColors.labelGray
                                    : AppColors.primaryBlue,
                                fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // ── Action bar ────────────────────────────────────────────────
            if (!loan.isPaid)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top:
                        BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    // Record payment
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.payment_rounded,
                        label: 'Record Payment',
                        color: Colors.white,
                        onTap: () => _showPaymentSheet(context, provider, loan),
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36,
                        color: Colors.white.withValues(alpha: 0.05)),
                    // Delete
                    _ActionTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: Colors.white.withValues(alpha: 0.5),
                      onTap: () => _confirmDelete(context, provider),
                      compact: true,
                    ),
                  ],
                ),
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
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Delete Loan?', style: TextStyle(color: Colors.white)),
        content: Text(
            'Are you sure you want to delete the loan for ${loan.personName}? All payment history will be lost.',
            style: const TextStyle(color: AppColors.labelGray)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.labelGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.alertRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await provider.deleteLoan(loan.id!);
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool compact;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.symmetric(horizontal: compact ? 16 : 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, color: color, size: 14),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
      ),
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
        isLent ? const Color(0xFF3EB489) : const Color(0xFFE67E22);

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F25),
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
                        primary: AppColors.primaryBlue,
                        surface: Color(0xFF1C1F24),
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
              color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
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
                                  color: AppColors.labelGray, fontSize: 10)),
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
                        const Color(0xFF3EB489)),
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
                          color: AppColors.labelGray, fontSize: 12),
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
                              ? AppColors.alertRed
                              : AppColors.labelGray,
                          fontSize: 11),
                    ),
                    Text(DateFormat('MMM d, y').format(current.dueDate),
                        style: TextStyle(
                            color: current.isOverdue
                                ? AppColors.alertRed
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
                              color: AppColors.primaryBlue, fontSize: 11)),
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
                              color: AppColors.labelGray, fontSize: 11)),
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
                        color: AppColors.textGray.withValues(alpha: 0.3),
                        size: 40),
                    const SizedBox(height: 10),
                    const Text('No payments recorded yet',
                        style:
                            TextStyle(color: AppColors.textGray, fontSize: 13)),
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
                    color: AppColors.textGray,
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
                      accentColor: const Color(0xFF3EB489),
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
            style: const TextStyle(color: AppColors.labelGray, fontSize: 10)),
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
                            color: AppColors.textGray,
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
                color: const Color(0xFF0D0E10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: SelectableText(
                widget.rawMessage,
                style: const TextStyle(
                  color: AppColors.labelGray,
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
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
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
                      const TextStyle(color: AppColors.labelGray, fontSize: 10),
                ),
                if (payment.note != null && payment.note!.isNotEmpty)
                  Text(payment.note!,
                      style: const TextStyle(
                          color: AppColors.labelGray, fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  title: const Text('Remove payment?',
                      style: TextStyle(color: Colors.white)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textGray))),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Remove',
                            style: TextStyle(color: AppColors.alertRed))),
                  ],
                ),
              );
              if (confirm == true) {
                await provider.deleteLoanPaymentRecord(payment.id!, loanId);
              }
            },
            child: const Icon(Icons.close_rounded,
                color: AppColors.alertRed, size: 16),
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
                primary: AppColors.primaryBlue,
                surface: Color(0xFF1C1F24),
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
            color: Color(0xFF141618),
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
                      color: const Color(0xFF1C1F24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _TypeToggle(
                          label: '↑ I Lent Money',
                          active: _loanType == 'lent',
                          activeColor: const Color(0xFF3EB489),
                          onTap: () => setState(() => _loanType = 'lent'),
                        ),
                        _TypeToggle(
                          label: '↓ I Borrowed',
                          active: _loanType == 'borrowed',
                          activeColor: const Color(0xFFE67E22),
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
                        color: AppColors.textGray,
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
                                  AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.people_outline_rounded,
                                color: AppColors.primaryBlue, size: 20),
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
                            color: AppColors.labelGray.withValues(alpha: 0.6),
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
                      color: const Color(0xFF1C1F24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.textGray, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Return by: ${DateFormat('MMM d, y').format(_dueDate)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textGray, size: 18),
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
                      color: const Color(0xFF1C1F24),
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
                                color: AppColors.primaryBlue, size: 18),
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
                                        color: AppColors.textGray,
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
                                color: AppColors.textGray,
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
                                      color: AppColors.primaryBlue
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.primaryBlue
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Icon(
                                        Icons.people_outline_rounded,
                                        color: AppColors.primaryBlue,
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
                                  color: AppColors.labelGray
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
                                    AppColors.labelGray.withValues(alpha: 0.55),
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
                                  color: AppColors.textGray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Auto-detects repayments from selected banks',
                              style: TextStyle(
                                  color: AppColors.labelGray, fontSize: 10),
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
                            color: AppColors.primaryBlue,
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
                                ? AppColors.primaryBlue.withValues(alpha: 0.15)
                                : const Color(0xFF1C1F24),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue.withValues(alpha: 0.5)
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
                                        color: AppColors.primaryBlue,
                                        size: 14)
                                    : const Icon(
                                        Icons.radio_button_unchecked_rounded,
                                        key: ValueKey('uncheck'),
                                        color: AppColors.textGray,
                                        size: 14),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                bank,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : AppColors.textGray,
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
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Color(0xFF1F1F25), strokeWidth: 2))
                        : const Text('Save Loan Record',
                            style: TextStyle(
                                color: Color(0xFF1F1F25),
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
        color: Color(0xFF141618),
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
                  color: AppColors.textGray, size: 18),
              hintText: 'Search…',
              hintStyle:
                  TextStyle(color: AppColors.textGray.withValues(alpha: 0.5)),
              filled: true,
              fillColor: const Color(0xFF1C1F24),
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
                        style: TextStyle(color: AppColors.textGray)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF2A2A34), height: 1, thickness: 1),
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
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: AppColors.primaryBlue,
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
                                  color: AppColors.textGray, size: 16),
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
                color: active ? activeColor : AppColors.textGray,
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
        prefixIcon: Icon(icon, color: AppColors.textGray, size: 18),
        hintText: hint,
        hintStyle: TextStyle(
            color: AppColors.textGray.withValues(alpha: 0.6), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1C1F24),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBlue),
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
        isLent ? const Color(0xFF3EB489) : const Color(0xFFE67E22);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
        decoration: const BoxDecoration(
          color: Color(0xFF141618),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
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
        color: const Color(0xFFE67E22).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: const Color(0xFFE67E22).withValues(alpha: 0.3)),
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
                      color: Color(0xFFE67E22), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.requests.length} Pending Loan Approval${widget.requests.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFE67E22),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFFE67E22),
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
                        color: const Color(0xFF1E1E26),
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
                                  color: const Color(0xFFE67E22)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Color(0xFFE67E22), size: 18),
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
                                          color: Color(0xFF3EB489),
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
                                    color: AppColors.textGray, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textGray),
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
                                          backgroundColor: Color(0xFF3EB489),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3EB489)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: const Color(0xFF3EB489)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.check_rounded,
                                            color: Color(0xFF3EB489), size: 14),
                                        SizedBox(width: 6),
                                        Text('Approve',
                                            style: TextStyle(
                                                color: Color(0xFF3EB489),
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
                                          backgroundColor: AppColors.labelGray,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: AppColors.alertRed
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.alertRed
                                              .withValues(alpha: 0.35)),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.close_rounded,
                                            color: AppColors.alertRed,
                                            size: 14),
                                        SizedBox(width: 6),
                                        Text('Reject',
                                            style: TextStyle(
                                                color: AppColors.alertRed,
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
