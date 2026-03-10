import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/loan_record.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../loans/loan_management_screen.dart';
import 'internal_transfer_picker_sheet.dart';

class TransactionDetailScreen extends StatefulWidget {
  final AppTransaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TextEditingController _noteController;
  AppReason? _selectedReason;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: widget.transaction.customReasonText ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showReasonPicker(BuildContext context, FinanceProvider provider) {
    AppReason? initial = _selectedReason;
    if (initial == null && widget.transaction.resolvedReason != null) {
      initial = provider.reasons
          .where((r) =>
              r.name.toLowerCase() ==
              widget.transaction.resolvedReason!.toLowerCase())
          .firstOrNull;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BottomSheetContext) {
        return _ReasonPickerSheet(
          provider: provider,
          initialReason: initial,
          onSave: (reason) {
            setState(() {
              _selectedReason = reason;
            });
            _save(provider);
          },
        );
      },
    );
  }

  Future<void> _save(FinanceProvider provider) async {
    print('DEBUG: _save called for transaction ${widget.transaction.id}');
    if (widget.transaction.id == null) {
      print('DEBUG: transaction ID is null, aborting _save');
      return;
    }

    final noteText = _noteController.text.trim();
    // Use the potentially new _selectedReason if available
    final currentResolvedReason =
        _selectedReason?.name ?? widget.transaction.resolvedReason ?? '';

    print('DEBUG: currentResolvedReason is "$currentResolvedReason"');

    bool changesMade = false;

    if (_selectedReason != null) {
      print(
          'DEBUG: updating reason to ${_selectedReason!.name} (ID: ${_selectedReason!.id})');
      // Re-save even if same reason to ensure new notes take effect
      await provider.updateTransactionReason(
        widget.transaction.id!,
        reasonId: _selectedReason!.id,
        customReasonText: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else if (noteText != (widget.transaction.customReasonText ?? '')) {
      print('DEBUG: updating notes only ($noteText)');
      await provider.updateTransactionReason(
        widget.transaction.id!,
        customReasonText: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else {
      print('DEBUG: no changes made');
    }

    if (mounted) {
      print('DEBUG: showing snackbar, mounted');
      if (changesMade) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reason saved ✓'),
            backgroundColor: AppColors.primaryBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      print('DEBUG: checking reason "$currentResolvedReason" for modals');
      // Check the new reason name to trigger modals
      if (currentResolvedReason.toLowerCase() == 'loan' && mounted) {
        print('DEBUG: showing loan modal');
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        final shouldCreate = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.handshake_outlined,
                    color: Color(0xFF3EB489), size: 20),
                SizedBox(width: 8),
                Text('Create Loan Record?',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: Text(
              'This transaction (${NumberFormat("#,##0.00").format(widget.transaction.amount)} ETB) '
              'was tagged as a loan.\n\nWould you like to track its repayment in the Loan Manager?',
              style: const TextStyle(color: AppColors.textGray, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Skip',
                    style: TextStyle(color: AppColors.textGray)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create Loan',
                    style: TextStyle(color: Color(0xFF3EB489))),
              ),
            ],
          ),
        );
        if (shouldCreate == true && mounted) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddLoanSheet(
              provider: provider,
              linkedTransactionId: widget.transaction.id,
              prefilledAmount: widget.transaction.amount,
              prefilledName: widget.transaction.name,
              prefilledTrackedSender: widget.transaction.sender,
              prefilledType:
                  widget.transaction.type == 'expense' ? 'lent' : 'borrowed',
            ),
          );
        }
      } else if (currentResolvedReason.toLowerCase() == 'internal transfer' &&
          mounted) {
        print('DEBUG: condition met for internal transfer modal');
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) {
          print('DEBUG: unmounted before showing IT modal');
          return;
        }
        if (widget.transaction.linkedTransactionId == null) {
          print('DEBUG: linkedTransactionId is null, showing modal');
          // Show the picker
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => InternalTransferPickerSheet(
              sourceTransaction: widget.transaction,
              provider: provider,
            ),
          );
        } else {
          print(
              'DEBUG: linkedTransactionId is NOT null! (${widget.transaction.linkedTransactionId})');
        }
      } else {
        print(
            'DEBUG: reason "$currentResolvedReason" did not match internal transfer, or not mounted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final bool isIncome = widget.transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.mintGreen : AppColors.alertRed;

    // Resolved current label to show in the chip
    final String? currentLabel =
        _selectedReason?.name ?? widget.transaction.resolvedReason;

    final int? activeReasonId =
        _selectedReason?.id ?? widget.transaction.reasonId;

    // Find linked loan if any
    LoanRecord? linkedLoan;
    try {
      linkedLoan = provider.loanRecords.firstWhere(
        (l) => l.linkedTransactionId == widget.transaction.id,
      );
    } catch (_) {
      linkedLoan = null;
    }

    AppReasonLink? activeLink;
    if (activeReasonId != null) {
      final links = provider.linksForReason(activeReasonId);
      final idx = links.indexWhere((l) =>
          l.linkedName.toLowerCase() ==
          widget.transaction.sender.toLowerCase());
      if (idx != -1) activeLink = links[idx];
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF1F1F25),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'Transaction Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w400,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              'assets/images/BackForNav.svg',
              colorFilter:
                  const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              width: 20,
              height: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 20),
              onPressed: () {}, // For future share functionality
            ),
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
                    padding: const EdgeInsets.only(top: 120, bottom: 40),
                    child: Column(
                      children: [
                        // Animated Success Glow
                        Hero(
                          tag: 'tx_icon_${widget.transaction.id}',
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isIncome
                                  ? AppColors.mintGreen.withValues(alpha: 0.1)
                                  : AppColors.alertRed.withValues(alpha: 0.1),
                              border: Border.all(
                                color: (isIncome
                                        ? AppColors.mintGreen
                                        : AppColors.alertRed)
                                    .withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              isIncome ? Icons.south_west : Icons.north_east,
                              size: 32,
                              color: isIncome
                                  ? AppColors.mintGreen
                                  : AppColors.alertRed,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Currency + Amount with premium split decimals
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              sign,
                              style: TextStyle(
                                color: amountColor,
                                fontSize: 48,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormat('#,##0')
                                  .format(widget.transaction.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              '.${(widget.transaction.amount % 1).toStringAsFixed(2).split('.')[1]}',
                              style: const TextStyle(
                                color: AppColors.labelGray,
                                fontSize: 28,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ETB',
                          style: const TextStyle(
                            color: AppColors.labelGray,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.mintGreen,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'TRANSACTION SUCCESSFUL',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (linkedLoan != null) ...[
                          const SizedBox(height: 24),
                          _buildLoanTrackingCard(context, linkedLoan, provider),
                        ] else if (widget.transaction.linkedTransactionId !=
                            null) ...[
                          const SizedBox(height: 24),
                          _buildInternalTransferCard(context, provider),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Reason Section ────────────────────────────
                    // ── Reason Card ────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.03)),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ASSIGNED REASON',
                                style: TextStyle(
                                  color: AppColors.textGray,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              if (activeReasonId != null)
                                GestureDetector(
                                  onTap: () async {
                                    if (activeLink != null) {
                                      await provider
                                          .deleteReasonLink(activeLink.id!);
                                    } else {
                                      await provider.addReasonLink(
                                        reasonId: activeReasonId,
                                        linkedName: widget.transaction.sender,
                                        linkType:
                                            isIncome ? 'sender' : 'receiver',
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: activeLink != null
                                          ? AppColors.alertRed
                                              .withValues(alpha: 0.1)
                                          : AppColors.primaryBlue
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          activeLink != null
                                              ? Icons.link_off
                                              : Icons.add_link,
                                          color: activeLink != null
                                              ? AppColors.alertRed
                                              : AppColors.primaryBlue,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          activeLink != null
                                              ? 'Unlink User'
                                              : 'Link User',
                                          style: TextStyle(
                                            color: activeLink != null
                                                ? AppColors.alertRed
                                                : AppColors.primaryBlue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => _showReasonPicker(context, provider),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlue
                                          .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.tag,
                                        color: AppColors.primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentLabel ?? 'Uncategorized',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          currentLabel != null
                                              ? 'Tap to change reason'
                                              : 'Assign a reason for tracking',
                                          style: const TextStyle(
                                            color: AppColors.labelGray,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right,
                                      color: AppColors.textGray),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'PERSONAL NOTE',
                            style: TextStyle(
                              color: AppColors.textGray,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14),
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText:
                                  'Add a private note about this expense...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.2)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.02),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.05)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.05)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: AppColors.primaryBlue),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                            onEditingComplete: () {
                              FocusScope.of(context).unfocus();
                              _save(provider);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'TRANSACTION INFO',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Detail Items
                    _buildInfoPanel([
                      _buildInfoItem(Icons.fingerprint, 'Transaction ID',
                          widget.transaction.id ?? 'Pending'),
                      _buildInfoItem(Icons.grid_view_rounded, 'Category',
                          widget.transaction.category),
                      _buildInfoItem(Icons.account_balance_wallet_outlined,
                          'Account', widget.transaction.sender),
                      _buildInfoItem(
                          Icons.calendar_today_outlined,
                          'Date & Time',
                          DateFormat('MMMM dd, yyyy • HH:mm')
                              .format(widget.transaction.date)),
                      _buildInfoItem(Icons.account_balance, 'Post Balance',
                          '${NumberFormat('#,##0.00').format(widget.transaction.totalBalance)} ETB'),
                    ]),
                    const SizedBox(height: 32),
                    const Text(
                      'RAW MESSAGE SOURCE',
                      style: TextStyle(
                        color: AppColors.textGray,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Text(
                        widget.transaction.rawMessage,
                        style: const TextStyle(
                          color: AppColors.labelGray,
                          height: 1.6,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Container(
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
      ),
    );
  }

  Widget _buildInfoPanel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textGray, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.labelGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanTrackingCard(
      BuildContext context, LoanRecord loan, FinanceProvider provider) {
    final isLent = loan.loanType == 'lent';
    final accentColor =
        isLent ? const Color(0xFF3EB489) : const Color(0xFFE67E22);
    final fmt = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.handshake_outlined,
                    color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLent
                          ? 'Lent to ${loan.personName}'
                          : 'Borrowed from ${loan.personName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      loan.isPaid ? 'Fully Settled ✓' : 'In Progress',
                      style: TextStyle(
                        color: loan.isPaid ? AppColors.mintGreen : accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  provider.setScreenIndex(3);
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'View Manager',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repaid: ${fmt.format(loan.paidAmount)} ETB',
                style:
                    const TextStyle(color: AppColors.labelGray, fontSize: 11),
              ),
              Text(
                'Remaining: ${fmt.format(loan.remainingAmount)} ETB',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: loan.progressPercent,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternalTransferCard(
      BuildContext context, FinanceProvider provider) {
    AppTransaction? linkedTx;
    try {
      linkedTx = provider.transactions
          .firstWhere((t) => t.id == widget.transaction.linkedTransactionId);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_alt,
                    color: AppColors.primaryBlue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Internal Transfer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      linkedTx != null
                          ? 'Linked to ${linkedTx.sender}'
                          : 'Linked to another transaction',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (linkedTx != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Opposite Amount:',
                  style: TextStyle(color: AppColors.labelGray, fontSize: 11),
                ),
                Text(
                  '${NumberFormat('#,##0.00').format(linkedTx.amount)} ETB (${linkedTx.type == 'income' ? '+' : '-'})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
//  Reason picker bottom sheet
// ─────────────────────────────────────────────────────────
class _ReasonPickerSheet extends StatefulWidget {
  final FinanceProvider provider;
  final AppReason? initialReason;
  final ValueChanged<AppReason> onSave;

  const _ReasonPickerSheet({
    required this.provider,
    required this.initialReason,
    required this.onSave,
  });

  @override
  State<_ReasonPickerSheet> createState() => _ReasonPickerSheetState();
}

class _ReasonPickerSheetState extends State<_ReasonPickerSheet> {
  AppReason? _selectedReason;

  @override
  void initState() {
    super.initState();
    _selectedReason = widget.initialReason;
  }

  void _showAddReasonDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason',
            style: TextStyle(color: AppColors.textWhite)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Reason name…',
            hintStyle:
                TextStyle(color: AppColors.textGray.withValues(alpha: 0.6)),
            filled: true,
            fillColor: AppColors.surfaceLight.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                await widget.provider.addReason(name);
                if (mounted) {
                  final newReason = widget.provider.reasons
                      .where((r) => r.name.toLowerCase() == name.toLowerCase())
                      .firstOrNull;
                  if (newReason != null) {
                    setState(() {
                      _selectedReason = newReason;
                    });
                  }
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add',
                style: TextStyle(color: AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialTile(AppReason reason) {
    bool isSelected = _selectedReason?.id == reason.id;
    String desc = '';
    final lower = reason.name.toLowerCase();
    if (lower == 'bounce') {
      desc = 'Excludes this transaction from income/expense calculations';
    } else if (lower == 'internal transfer') {
      desc = 'Links to another transaction to balance them out';
    } else if (lower == 'cash') {
      desc = 'Used for ATM withdrawals and physical cash deposits';
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.15)
              : AppColors.surfaceLight.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.surfaceLight.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryBlue.withValues(alpha: 0.2)
                    : AppColors.surfaceLight.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_border,
                  color:
                      isSelected ? AppColors.primaryBlue : AppColors.textGray,
                  size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(reason.name,
                      style: TextStyle(
                          color: isSelected
                              ? AppColors.primaryBlue
                              : AppColors.textWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            color: AppColors.textGray, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.primaryBlue, size: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FinanceProvider>(builder: (ctx, provider, _) {
      final systemReasons = provider.reasons.where((r) => r.isSystem).toList();
      final userReasons = provider.reasons.where((r) => !r.isSystem).toList();

      final specialNames = ['bounce', 'internal transfer', 'cash'];
      final normalSystem = systemReasons
          .where((r) => !specialNames.contains(r.name.toLowerCase()))
          .toList();
      final specialSystem = systemReasons
          .where((r) => specialNames.contains(r.name.toLowerCase()))
          .toList();

      return Container(
        margin: const EdgeInsets.all(16),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textGray.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Select Reason',
                      style: TextStyle(
                          color: AppColors.textWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: AppColors.textGray, size: 20),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (normalSystem.isNotEmpty) ...[
                      _sectionLabel('System Categories'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: normalSystem
                            .map((r) => _ReasonChip(
                                  reason: r,
                                  isSelected: _selectedReason?.id == r.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedReason = r;
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (specialSystem.isNotEmpty) ...[
                      _sectionLabel('Special Reasons'),
                      const SizedBox(height: 4),
                      ...specialSystem
                          .map((r) => _buildSpecialTile(r))
                          ,
                      const SizedBox(height: 12),
                    ],
                    // My Reasons
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _sectionLabel('My Reasons'),
                        const Spacer(),
                        GestureDetector(
                            onTap: _showAddReasonDialog,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add,
                                  size: 16, color: AppColors.primaryBlue),
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (userReasons.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: userReasons
                            .map((r) => _ReasonChip(
                                  reason: r,
                                  isSelected: _selectedReason?.id == r.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedReason = r;
                                    });
                                  },
                                ))
                            .toList(),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No custom reasons yet.',
                            style: TextStyle(
                                color: AppColors.textGray, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            // Save button
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      )
                    ]),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedReason == null
                        ? null
                        : () {
                            print(
                                'DEBUG: Button clicked with reason ${_selectedReason!.name}');
                            Navigator.of(context).pop();
                            widget.onSave(_selectedReason!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      disabledBackgroundColor:
                          AppColors.primaryBlue.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Save Changes',
                        style: TextStyle(
                            color: _selectedReason == null
                                ? AppColors.textWhite.withValues(alpha: 0.5)
                                : const Color(0xFF1F1F25),
                            fontWeight: FontWeight.bold)),
                  ),
                )),
          ],
        ),
      );
    });
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.textGray,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5)),
      );
}

class _ReasonChip extends StatelessWidget {
  final AppReason reason;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReasonChip({
    required this.reason,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.2)
              : AppColors.surfaceLight.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.surfaceLight.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason.isSystem)
              const Icon(Icons.verified_outlined,
                  size: 13, color: AppColors.primaryBlue),
            if (reason.isSystem) const SizedBox(width: 4),
            Text(reason.name,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : AppColors.textWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
