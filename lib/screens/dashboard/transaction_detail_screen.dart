import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/loan_record.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
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

  Future<void> _showReasonPicker(
      BuildContext context, FinanceProvider provider) async {
    AppReason? initial = _selectedReason;
    if (initial == null && widget.transaction.resolvedReason != null) {
      initial = provider.reasons
          .where((r) =>
              r.name.toLowerCase() ==
              widget.transaction.resolvedReason!.toLowerCase())
          .firstOrNull;
    }

    // Track which reason the user chose inside the sheet.
    AppReason? chosen;

    // AWAIT the sheet so _save only runs after the dismiss animation completes.
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _ReasonPickerSheet(
          provider: provider,
          initialReason: initial,
          onSave: (reason) {
            chosen = reason;
            // Pop the sheet from here — parent will detect the close via await.
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );

    // Sheet is now FULLY dismissed (animation complete).
    if (chosen == null || !context.mounted) return;

    setState(() {
      _selectedReason = chosen!;
    });

    // Save the reason to the DB first.
    await _save(provider);

    if (!context.mounted) return;

    // ── Always trigger the follow-up modal for special reasons, regardless
    //    of whether the reason changed — the user explicitly hit Save.
    final chosenName = chosen!.name.trim().toLowerCase();

    if (chosenName == 'loan' || chosenName.contains('loan')) {
      if (!context.mounted) return;
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.handshake_outlined, color: AppColors.positive, size: 20),
              SizedBox(width: 8),
              Text('Create Loan Record?',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Text(
            'This transaction (${NumberFormat("#,##0.00").format(widget.transaction.amount)} ETB) '
            'was tagged as a loan.\n\nWould you like to track its repayment in the Loan Manager?',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Skip',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create Loan',
                  style: TextStyle(color: AppColors.positive)),
            ),
          ],
        ),
      );
      if (shouldCreate == true && context.mounted) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddLoanSheet(
            provider: provider,
            linkedTransactionId: widget.transaction.id,
            prefilledAmount: widget.transaction.amount,
            prefilledName: widget.transaction.sender,
            prefilledTrackedSender: widget.transaction.sender,
            prefilledType:
                widget.transaction.type == 'expense' ? 'lent' : 'borrowed',
          ),
        );
      }
    } else if (chosenName == 'internal transfer') {
      if (!context.mounted) return;
      if (widget.transaction.linkedTransactionId == null) {
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
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final shouldUnlink = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.sync_alt, color: AppColors.gold, size: 20),
                SizedBox(width: 8),
                Text('Already Linked',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            content: const Text(
              'This transaction is already linked to another internal transfer.\n\nWould you like to unlink it?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Keep Link',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Unlink',
                    style: TextStyle(color: AppColors.negative)),
              ),
            ],
          ),
        );
        if (shouldUnlink == true && context.mounted) {
          await provider.unlinkInternalTransfer(widget.transaction.id!);
          if (context.mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Internal transfer unlinked'),
                backgroundColor: AppColors.negative,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _save(FinanceProvider provider) async {
    if (widget.transaction.id == null) return;

    final noteText = _noteController.text.trim();
    bool changesMade = false;

    if (_selectedReason != null) {
      await provider.updateTransactionReason(
        widget.transaction.id!,
        reasonId: _selectedReason!.id,
        customReasonText: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else if (noteText != (widget.transaction.customReasonText ?? '')) {
      await provider.updateTransactionReason(
        widget.transaction.id!,
        customReasonText: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    }

    if (mounted && changesMade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reason saved ✓'),
          backgroundColor: AppColors.gold,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // NOTE: Loan / Internal Transfer follow-up modals are now handled
    // in _showReasonPicker() directly after this method returns, so that
    // they ALWAYS appear when the user saves one of those special reasons —
    // regardless of whether the reason was already set to the same value.
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final bool isIncome = widget.transaction.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.positive : AppColors.negative;

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

    // True if this transaction is auto-locked (Telebirr credit/repayment)
    final bool isAutoLocked = widget.transaction.isReasonLocked;
    // True if reason editing is blocked by any lock (linked loan OR auto-lock)
    final bool isReasonBlocked = linkedLoan != null || isAutoLocked;

    AppReasonLink? activeLink;
    if (activeReasonId != null) {
      final links = provider.linksForReason(activeReasonId);
      final idx = links.indexWhere((l) =>
          l.linkedName.toLowerCase() ==
          widget.transaction.sender.toLowerCase());
      if (idx != -1) activeLink = links[idx];
    }

    // Special reasons have dedicated tile renderer — hide the generic Link User button for these
    const specialReasonNames = {
      'loan', 'bounce', 'internal transfer', 'cash'
    };
    final activeReasonName = (_selectedReason?.name ??
            widget.transaction.resolvedReason ??
            '')
        .trim()
        .toLowerCase();
    final isSpecialReason = specialReasonNames.contains(activeReasonName) ||
        activeReasonName.contains('loan');

    final bankInfo = _getBankInfo();

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
          centerTitle: true,
          title: const Text(
            'Transaction Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const AppBackButton(),
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
                    padding: const EdgeInsets.only(top: 110, bottom: 20),
                    child: Column(
                      children: [
                        // Animated Hero Icon
                        Hero(
                          tag: 'tx_icon_${widget.transaction.id}',
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isIncome
                                  ? AppColors.positive.withValues(alpha: 0.12)
                                  : AppColors.negative.withValues(alpha: 0.12),
                              border: Border.all(
                                color: (isIncome
                                        ? AppColors.positive
                                        : AppColors.negative)
                                    .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
                              size: 30,
                              color: isIncome
                                  ? AppColors.positive
                                  : AppColors.negative,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Currency + Amount with premium split decimals & active currency symbol
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              sign,
                              style: TextStyle(
                                color: amountColor,
                                fontSize: 44,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormat('#,##0')
                                  .format(widget.transaction.amount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              '.${(widget.transaction.amount % 1).toStringAsFixed(2).split('.')[1]}',
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 26,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CurrencySymbolWidget(
                              size: 22,
                              color: AppColors.textSoft,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── Prominent Bank / Provider Branding Card ──────
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard, // Color(0xFF111821)
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: bankInfo.bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(child: bankInfo.icon),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bankInfo.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (bankInfo.subtitle.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        bankInfo.subtitle,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.positive.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.positive.withValues(alpha: 0.2)),
                                ),
                                child: const Text(
                                  'SUCCESS',
                                  style: TextStyle(
                                    color: AppColors.positive,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (linkedLoan != null) ...[
                          const SizedBox(height: 16),
                          _buildLoanTrackingCard(context, linkedLoan, provider),
                        ] else if (currentLabel?.toLowerCase().contains('loan') == true) ...[
                          const SizedBox(height: 16),
                          _buildCreateLoanCard(context, provider),
                        ] else if (widget.transaction.linkedTransactionId != null) ...[
                          const SizedBox(height: 16),
                          _buildInternalTransferCard(context, provider),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Reason Card ────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard, // Color(0xFF111821)
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ASSIGNED REASON',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              if (activeReasonId != null && !isSpecialReason)
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
                                          ? AppColors.negative
                                              .withValues(alpha: 0.12)
                                          : AppColors.positive
                                              .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: activeLink != null
                                            ? AppColors.negative.withValues(alpha: 0.25)
                                            : AppColors.positive.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          activeLink != null
                                              ? Icons.link_off
                                              : Icons.add_link,
                                          color: activeLink != null
                                              ? AppColors.negative
                                              : AppColors.positive,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          activeLink != null
                                              ? 'Unlink User'
                                              : 'Link User',
                                          style: TextStyle(
                                            color: activeLink != null
                                                ? AppColors.negative
                                                : AppColors.positive,
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
                          const SizedBox(height: 14),
                          GestureDetector(
                            onTap: () {
                              // Locked because a loan record is linked
                              if (linkedLoan != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'In order to change the reason, delete the loan record from Loan Manager first.'),
                                    backgroundColor: AppColors.warning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              // Locked because it's an auto-detected Telebirr credit/repayment
                              if (isAutoLocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Reason is locked — this transaction was auto-created from a Telebirr credit SMS.'),
                                    backgroundColor: AppColors.warning,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              _showReasonPicker(context, provider);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isReasonBlocked
                                        ? AppColors.warning.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.06)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.positive
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                        isReasonBlocked
                                            ? Icons.lock_outline
                                            : Icons.tag,
                                        color: isReasonBlocked
                                            ? AppColors.warning
                                            : AppColors.positive,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentLabel ?? 'Uncategorized',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isReasonBlocked
                                              ? (isAutoLocked
                                                  ? 'Auto-locked • Telebirr credit transaction'
                                                  : 'Locked • Delete loan in manager to change')
                                              : (currentLabel != null
                                                  ? 'Tap to change reason'
                                                  : 'Assign a reason for tracking'),
                                          style: TextStyle(
                                            color: isReasonBlocked
                                                ? AppColors.warning
                                                : AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                      isReasonBlocked
                                          ? Icons.lock
                                          : Icons.chevron_right,
                                      color: isReasonBlocked
                                          ? AppColors.warning
                                          : AppColors.textSecondary,
                                      size: isReasonBlocked ? 18 : 22),
                                ],
                              ),
                            ),
                          ),
                          if (isReasonBlocked) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      color: AppColors.warning, size: 16),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isAutoLocked
                                          ? 'This transaction was auto-created from a Telebirr credit SMS. The reason is set to Loan and cannot be changed.'
                                          : 'To change this transaction\'s reason, delete the linked loan record from Loan Manager first.',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Personal Note Card ───────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard, // Color(0xFF111821)
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PERSONAL NOTE',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
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
                                  'Add a private note about this transaction...',
                              hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25)),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.03),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.06)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: AppColors.positive),
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

                    const SizedBox(height: 24),

                    // ── Transaction Info Card ───────────────────────
                    const Text(
                      'TRANSACTION INFO',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoPanel([
                      _buildInfoItem(Icons.fingerprint, 'Transaction ID',
                          widget.transaction.id ?? 'Pending'),
                      _buildInfoItem(Icons.account_balance_outlined, 'Provider',
                          bankInfo.name),
                      _buildInfoItem(Icons.grid_view_rounded, 'Category',
                          widget.transaction.category),
                      _buildInfoItem(
                          Icons.calendar_today_outlined,
                          'Date & Time',
                          DateFormat('MMMM dd, yyyy • HH:mm')
                              .format(widget.transaction.date)),
                      _buildInfoItem(
                        Icons.account_balance_wallet_outlined,
                        'Post Balance',
                        '',
                        customValueWidget: CurrencyTextWidget(
                          amount: widget.transaction.totalBalance,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Raw Message Source Card ─────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'RAW MESSAGE SOURCE',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(
                                text: widget.transaction.rawMessage));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Raw message copied to clipboard'),
                                backgroundColor: AppColors.positive,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.positive.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.positive.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.positive,
                                  size: 13,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    color: AppColors.positive,
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
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceCard, // Color(0xFF111821)
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Text(
                        widget.transaction.rawMessage,
                        style: const TextStyle(
                          color: AppColors.textSoft,
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

  ({Widget icon, String name, String subtitle, Color bgColor}) _getBankInfo() {
    final senderStr = widget.transaction.sender.trim();
    final nameStr = widget.transaction.name.trim();
    final combined = '$senderStr $nameStr'.toUpperCase();

    Widget iconWidget;
    String bankName;
    Color bg;

    if (combined.contains('CBE BIRR') || combined.contains('CBEBIRR')) {
      iconWidget = Image.asset('assets/images/CBEBirr Logo.png', width: 24, height: 24);
      bankName = 'CBE Birr Mobile Banking';
      bg = AppColors.cbeBirrPink.withValues(alpha: 0.15);
    } else if (combined.contains('TELEBIRR')) {
      iconWidget = Image.asset(
        'assets/images/Telebirr Logo.png',
        width: 24,
        height: 24,
        color: AppColors.telebirrGreen,
        colorBlendMode: BlendMode.srcIn,
      );
      bankName = 'Telebirr Digital Wallet';
      bg = AppColors.telebirrGreenSoft;
    } else if (combined.contains('AHADU')) {
      iconWidget = Image.asset('assets/images/Ahadu_Logo.png', width: 24, height: 24);
      bankName = 'Ahadu Bank';
      bg = AppColors.cardAhaduRed.withValues(alpha: 0.15);
    } else if (combined.contains('CBE') || combined.contains('COMMERCIAL BANK')) {
      iconWidget = Image.asset('assets/images/CBE logo 1.png', width: 24, height: 24);
      bankName = 'Commercial Bank of Ethiopia';
      bg = AppColors.slackPurple.withValues(alpha: 0.15);
    } else if (combined.contains('CASH')) {
      iconWidget = const Icon(Icons.account_balance_wallet_outlined, color: AppColors.positive, size: 22);
      bankName = 'Cash Wallet';
      bg = AppColors.positive.withValues(alpha: 0.15);
    } else {
      iconWidget = const Icon(Icons.account_balance_outlined, color: AppColors.positive, size: 22);
      bankName = senderStr.isNotEmpty ? senderStr : 'Mobile Banking';
      bg = AppColors.surfaceElevated;
    }

    String subtitleText = '';
    if (senderStr.isNotEmpty && senderStr.toUpperCase() != bankName.toUpperCase()) {
      subtitleText = senderStr;
    } else if (widget.transaction.customReasonText?.isNotEmpty == true) {
      subtitleText = widget.transaction.customReasonText!;
    } else {
      subtitleText = widget.transaction.type.toUpperCase();
    }

    return (
      icon: iconWidget,
      name: bankName,
      subtitle: subtitleText,
      bgColor: bg,
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
              AppColors.background,
              AppColors.bgMid,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard, // Color(0xFF111821)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value,
      {Widget? customValueWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                customValueWidget ??
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
        isLent ? AppColors.positive : AppColors.warning;
    final fmt = NumberFormat('#,##0.00');

    return GestureDetector(
      onLongPress: () => _showLoanOptionsSheet(context, loan, provider),
      child: Container(
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
                        loan.isPaid ? 'Fully Settled ✓' : 'In Progress (Hold for options)',
                        style: TextStyle(
                          color: loan.isPaid ? AppColors.positive : accentColor,
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
                      const TextStyle(color: AppColors.textSoft, fontSize: 11),
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
      ),
    );
  }

  void _showLoanOptionsSheet(
      BuildContext context, LoanRecord loan, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: InteractiveDragHandle(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                onTap: () => Navigator.pop(ctx),
                padding: const EdgeInsets.only(bottom: 12),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.handshake_outlined,
                    color: AppColors.gold, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loan Options (${loan.personName})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: Colors.white.withValues(alpha: 0.04),
              leading: const Icon(Icons.open_in_new, color: AppColors.gold),
              title: const Text('Open in Loan Manager',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('View repayments & full schedule',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                provider.setScreenIndex(3);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: AppColors.negative.withValues(alpha: 0.1),
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.negative),
              title: const Text('Delete Loan Record',
                  style: TextStyle(
                      color: AppColors.negative,
                      fontWeight: FontWeight.bold)),
              subtitle: const Text(
                  'Deletes loan tracking & unlocks reason editing',
                  style: TextStyle(color: AppColors.textSoft, fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                if (!mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Loan Record?',
                        style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to delete this loan record?\n\nDeleting it will stop tracking its repayments and unlock the reason section so you can change it.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dCtx, true),
                        child: const Text('Delete Loan',
                            style: TextStyle(color: AppColors.negative)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await provider.deleteLoan(loan.id!);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Loan record deleted. Reason editing is now unlocked.'),
                        backgroundColor: AppColors.gold,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateLoanCard(
      BuildContext context, FinanceProvider provider) {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddLoanSheet(
            provider: provider,
            linkedTransactionId: widget.transaction.id,
            prefilledAmount: widget.transaction.amount,
            prefilledName: widget.transaction.sender,
            prefilledTrackedSender: widget.transaction.sender,
            prefilledType:
                widget.transaction.type == 'expense' ? 'lent' : 'borrowed',
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard, // Color(0xFF111821)
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.positive.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined,
                  color: AppColors.positive, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track as Loan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Create loan record to track repayments',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.positive,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Create',
                style: TextStyle(
                  color: AppColors.background,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
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
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard, // Color(0xFF111821)
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.positive.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
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
                  color: AppColors.positive.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync_alt,
                    color: AppColors.positive, size: 18),
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
                        color: AppColors.positive,
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
                  style: TextStyle(color: AppColors.textSoft, fontSize: 11),
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('New Reason',
            style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Reason name…',
            hintStyle:
                TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: AppColors.surfaceCard.withValues(alpha: 0.1),
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
                style: TextStyle(color: AppColors.textSecondary)),
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
                style: TextStyle(color: AppColors.gold)),
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
    } else if (lower == 'loan' || lower.contains('loan')) {
      desc = 'Marks this as a loan — track its repayment in Loan Manager';
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
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.surfaceCard.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.surfaceCard.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : AppColors.surfaceCard.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_border,
                  color:
                      isSelected ? AppColors.gold : AppColors.textSecondary,
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
                              ? AppColors.gold
                              : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.gold, size: 20),
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

      // Special reasons: Bounce, Internal Transfer, Cash, Loan
      const specialNames = {'bounce', 'internal transfer', 'cash', 'loan'};
      bool isSpecial(AppReason r) =>
          specialNames.contains(r.name.trim().toLowerCase()) ||
          r.name.trim().toLowerCase().contains('loan');

      final normalSystem = systemReasons
          .where((r) => !isSpecial(r))
          .toList();
      final specialSystem = systemReasons
          .where((r) => isSpecial(r))
          .toList();

      return Container(
        margin: const EdgeInsets.all(16),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            InteractiveDragHandle(
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              onTap: () => Navigator.pop(ctx),
              onVerticalDragUpdate: (details) {
                if ((details.primaryDelta ?? 0) > 3) {
                  Navigator.pop(ctx);
                }
              },
              padding: const EdgeInsets.only(top: 10, bottom: 4),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('Select Reason',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
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
                                color: AppColors.gold
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add,
                                  size: 16, color: AppColors.gold),
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
                                color: AppColors.textSecondary, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
            // Save button
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.surface,
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
                            // onSave will pop the sheet from the parent
                            widget.onSave(_selectedReason!);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      disabledBackgroundColor:
                          AppColors.gold.withValues(alpha: 0.3),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text('Save Changes',
                        style: TextStyle(
                            color: _selectedReason == null
                                ? AppColors.textPrimary.withValues(alpha: 0.5)
                                : AppColors.background,
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
                color: AppColors.textSecondary,
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
              ? AppColors.gold.withValues(alpha: 0.2)
              : AppColors.surfaceCard.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.surfaceCard.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason.isSystem)
              const Icon(Icons.verified_outlined,
                  size: 13, color: AppColors.gold),
            if (reason.isSystem) const SizedBox(width: 4),
            Text(reason.name,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
