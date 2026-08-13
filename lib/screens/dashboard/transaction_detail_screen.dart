import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/loan_record.dart';
import '../../models/cash_transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../loans/loan_management_screen.dart';
import 'internal_transfer_picker_sheet.dart';
import 'reason_selection_sheet.dart';

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
  bool _isPersonalNoteExpanded = false;
  bool _isRawMessageExpanded = false;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: widget.transaction.note ?? widget.transaction.customReasonText ?? '');
    if (_noteController.text.trim().isNotEmpty || widget.transaction.attachments.isNotEmpty) {
      _isPersonalNoteExpanded = true;
    }
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

    AppReason? chosen;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (sheetCtx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: ReasonSelectionSheet(
            initialReason: initial,
            onReasonSelected: (reason) {
              chosen = reason;
            },
          ),
        );
      },
    );

    // Sheet is now FULLY dismissed (animation complete).
    if (chosen == null || !mounted || !context.mounted) return;

    setState(() {
      _selectedReason = chosen!;
    });

    // Save the reason to the DB first.
    await _save(provider);

    if (!mounted || !context.mounted) return;

    // ── Always trigger the follow-up modal for special reasons, regardless
    //    of whether the reason changed — the user explicitly selected it.
    final chosenName = chosen!.name.trim().toLowerCase();

    if (chosenName == 'loan' || chosenName.contains('loan')) {
      if (!mounted || !context.mounted) return;
      final shouldCreate = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
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

      if (shouldCreate == true && mounted && context.mounted) {
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
      final isSub = _selectedReason!.isSubcategory;
      final isTop = _selectedReason!.isTopLevelCategory;
      await provider.updateTransactionReason(
        widget.transaction.id!,
        reasonId: _selectedReason!.id,
        categoryId: isSub ? _selectedReason!.parentId : (isTop ? _selectedReason!.id : null),
        subcategoryId: isSub ? _selectedReason!.id : null,
        note: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else if (noteText != (widget.transaction.note ?? '')) {
      await provider.updateTransactionNote(
        widget.transaction.id!,
        noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    }

    if (mounted && context.mounted && changesMade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Details saved ✓'),
          backgroundColor: AppColors.positive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _attachMedia(BuildContext context, FinanceProvider provider) async {
    if (widget.transaction.id == null) return;
    final pathController = TextEditingController();
    final filePath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.attach_file_rounded, color: AppColors.positive, size: 20),
            SizedBox(width: 8),
            Text('Attach Media / Receipt', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: pathController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter local file path or file URL...',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, pathController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive),
            child: const Text('Attach'),
          ),
        ],
      ),
    );

    if (filePath != null && filePath.isNotEmpty) {
      final ext = filePath.toLowerCase();
      String type = 'image';
      if (ext.endsWith('.pdf')) {
        type = 'pdf';
      } else if (ext.endsWith('.mp3') || ext.endsWith('.wav') || ext.endsWith('.m4a')) {
        type = 'audio';
      }

      final fileName = filePath.contains('/') ? filePath.split('/').last : filePath.split('\\').last;

      await provider.addAttachment(
        widget.transaction.id!,
        filePath,
        type,
        fileName: fileName,
      );

      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media attached ✓'),
            backgroundColor: AppColors.positive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteTransaction(
      BuildContext context, FinanceProvider provider) async {
    if (widget.transaction.id == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 22),
            SizedBox(width: 10),
            Text('Delete Transaction?',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this transaction? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true && context.mounted) {
      await provider.deleteTransaction(widget.transaction.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction deleted'),
            backgroundColor: AppColors.negative,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  String _limitWords(String text, {int maxWords = 2}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return trimmed;
    return words.take(maxWords).join(' ');
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
          centerTitle: false,
          titleSpacing: 0,
          title: const Text(
            'Transaction Details',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const AppBackButton(),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeleteTransaction(context, provider);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: AppColors.negative, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Delete Message',
                        style: TextStyle(
                          color: AppColors.negative,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                    padding: const EdgeInsets.only(top: 110, bottom: 0),
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

                        // ── 1. LOAN TRACKING / CREATE LOAN CARD (TOP MOST) ──────────────────────
                        if (linkedLoan != null) ...[
                          _buildLoanTrackingCard(context, linkedLoan, provider),
                          const SizedBox(height: 14),
                        ] else if (currentLabel?.toLowerCase().contains('loan') == true) ...[
                          _buildCreateLoanCard(context, provider),
                          const SizedBox(height: 14),
                        ] else if (widget.transaction.linkedTransactionId != null) ...[
                          _buildInternalTransferCard(context, provider),
                          const SizedBox(height: 14),
                        ] else if ((currentLabel?.toLowerCase() == 'cash' || widget.transaction.reason?.toLowerCase() == 'cash') && widget.transaction.type == 'expense') ...[
                          _buildCashSpendingBreakdownCard(context, provider),
                          const SizedBox(height: 14),
                        ],

                        // ── 2. ASSIGNED REASON CARD ─────────────────────────────────────────────
                        _buildAssignedReasonCard(
                          context,
                          provider,
                          currentLabel,
                          activeReasonId,
                          isSpecialReason,
                          isReasonBlocked,
                          isAutoLocked,
                          linkedLoan,
                          activeLink,
                          isIncome,
                        ),
                        const SizedBox(height: 14),

                        // ── 3. TRANSACTION DETAIL INFO CARD (ALWAYS EXPANDED) ───────────────────
                        _buildTransactionInfoCard(context, provider, bankInfo, isIncome),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Collapsible Personal Note Section ──────────────────
                    _buildCollapsiblePersonalNoteCard(context, provider),

                    const SizedBox(height: 14),

                    // ── Collapsible Raw Message Source Section ─────────────
                    _buildCollapsibleRawMessageCard(context),

                    const SizedBox(height: 14),

                    // ── Link Reason Feature Info Section ───────────────────
                    _buildLinkReasonInfoSection(context),

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

  ({Widget icon, String name, String shortName, String subtitle, Color bgColor}) _getBankInfo() {
    final senderStr = widget.transaction.sender.trim();
    final nameStr = widget.transaction.name.trim();
    final combined = '$senderStr $nameStr'.toUpperCase();

    Widget iconWidget;
    String bankName;
    String shortName;
    Color bg;

    if (combined.contains('CBE BIRR') || combined.contains('CBEBIRR')) {
      iconWidget = Image.asset('assets/images/CBEBirr Logo.png', width: 24, height: 24);
      bankName = 'CBE Birr Mobile Banking';
      shortName = 'CbeBirr';
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
      shortName = 'Telebirr';
      bg = AppColors.telebirrGreenSoft;
    } else if (combined.contains('AHADU')) {
      iconWidget = Image.asset('assets/images/Ahadu_Logo.png', width: 24, height: 24);
      bankName = 'Ahadu Bank';
      shortName = 'Ahadu';
      bg = AppColors.cardAhaduRed.withValues(alpha: 0.15);
    } else if (combined.contains('CBE') || combined.contains('COMMERCIAL BANK')) {
      iconWidget = Image.asset('assets/images/CBE logo 1.webp', width: 24, height: 24);
      bankName = 'Commercial Bank of Ethiopia';
      shortName = 'CBE';
      bg = AppColors.slackPurple.withValues(alpha: 0.15);
    } else if (combined.contains('CASH')) {
      iconWidget = const Icon(Icons.account_balance_wallet_outlined, color: AppColors.positive, size: 22);
      bankName = 'Cash Wallet';
      shortName = 'Cash';
      bg = AppColors.positive.withValues(alpha: 0.15);
    } else {
      iconWidget = const Icon(Icons.account_balance_outlined, color: AppColors.positive, size: 22);
      bankName = senderStr.isNotEmpty ? senderStr : 'Mobile Banking';
      shortName = senderStr.isNotEmpty ? senderStr : 'Bank';
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
      shortName: shortName,
      subtitle: subtitleText,
      bgColor: bg,
    );
  }
  Widget _buildTransactionInfoCard(
    BuildContext context,
    FinanceProvider provider,
    ({Widget icon, String name, String shortName, String subtitle, Color bgColor}) bankInfo,
    bool isIncome,
  ) {
    final String counterparty = widget.transaction.sender.isNotEmpty
        ? widget.transaction.sender
        : 'External Party';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Bank Logo, Bank Name & Person Name
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                      _limitWords(bankInfo.name, maxWords: 2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SMS received from ${bankInfo.shortName}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // Details List (Person/Counterparty, Transaction ID, Category, Date & Balance)
          _buildCollapsibleInfoRow(
            isIncome ? Icons.call_received_rounded : Icons.call_made_rounded,
            isIncome ? 'From (Sender)' : 'For (Recipient)',
            _limitWords(counterparty, maxWords: 2),
          ),
          _buildCollapsibleInfoRow(
              Icons.fingerprint, 'Transaction ID', widget.transaction.id ?? 'Pending'),
          _buildCollapsibleInfoRow(
              Icons.grid_view_rounded, 'SMS Category', widget.transaction.category),
          _buildCollapsibleInfoRow(
              Icons.calendar_today_outlined,
              'Date & Time',
              DateFormat('MMMM dd, yyyy • HH:mm').format(widget.transaction.date)),
          _buildCollapsibleInfoRow(
            Icons.account_balance_wallet_outlined,
            'Post Balance',
            '',
            customValue: CurrencyTextWidget(
              amount: widget.transaction.totalBalance,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSpendingBreakdownCard(BuildContext context, FinanceProvider provider) {
    if (widget.transaction.id == null) return const SizedBox.shrink();
    final spendings = provider.spendingsForTransaction(widget.transaction.id!);
    final totalSpent = provider.getCashWithdrawalSpentAmount(widget.transaction.id!);
    final remaining = provider.getCashWithdrawalRemainingAmount(widget.transaction.id!, widget.transaction.amount);
    final double progress = (totalSpent / widget.transaction.amount).clamp(0.0, 1.0);
    final fmtShort = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_outlined, color: AppColors.positive, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cash Spending Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${spendings.length} ${spendings.length == 1 ? 'deduction' : 'deductions'} linked',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.positive.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${fmtShort.format(remaining)} ETB Left',
                  style: const TextStyle(
                    color: AppColors.positive,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.negative : AppColors.positive,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: ${fmtShort.format(totalSpent)} ETB',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
              ),
              Text(
                'Total: ${fmtShort.format(widget.transaction.amount)} ETB',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),

          if (spendings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 10),
            ...spendings.map((s) {
              final reasonLabel = s.reasonName ?? s.description ?? 'Cash Expense';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.outbox_rounded, color: AppColors.negative, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reasonLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (s.description != null && s.description!.isNotEmpty && s.description != reasonLabel)
                            Text(s.description!, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Text(
                      '-${fmtShort.format(s.amount)} ETB',
                      style: const TextStyle(color: AppColors.negative, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () {
                _showDeductCashFromWithdrawalModal(context, provider, widget.transaction);
              },
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.positive, size: 16),
              label: const Text(
                'Deduct Cash Expense from this withdrawal',
                style: TextStyle(color: AppColors.positive, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.positive.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeductCashFromWithdrawalModal(BuildContext context, FinanceProvider provider, AppTransaction bankTx) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    AppReason? selectedReason;
    final fmtShort = NumberFormat('#,##0.00');

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final remaining = provider.getCashWithdrawalRemainingAmount(bankTx.id!, bankTx.amount);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 24,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Deduct Cash Expense', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Linked to ${bankTx.name} (${fmtShort.format(remaining)} ETB left)', style: const TextStyle(color: AppColors.positive, fontSize: 11)),
                        ],
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                      suffixText: 'ETB',
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.positive, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: ctx,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => ReasonSelectionSheet(
                          initialReason: selectedReason,
                          onReasonSelected: (r) => setModalState(() => selectedReason = r),
                        ),
                      );
                    },
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppColors.positive, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedReason?.name ?? 'Select Expense Reason',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_right, color: Colors.white54, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Note (Optional)',
                      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      onPressed: () async {
                        final amtStr = amountController.text.trim();
                        final amt = double.tryParse(amtStr);
                        if (amt == null || amt <= 0) return;

                        final cashTx = CashTransaction(
                          type: 'expense',
                          amount: amt,
                          date: DateTime.now(),
                          description: noteController.text.trim(),
                          reasonId: selectedReason?.id,
                          reasonName: selectedReason?.name,
                          linkedTransactionId: bankTx.id,
                        );

                        await provider.addCashTransaction(cashTx);
                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Deduction', style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildCollapsibleInfoRow(IconData icon, String label, String value,
      {Widget? customValue}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 15),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (customValue != null)
            customValue
          else
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getReasonCategoryIcon(String? label) {
    if (label == null || label.trim().isEmpty || label.trim().toLowerCase() == 'uncategorized') {
      return Icons.help_outline_rounded; // Question mark icon when no reason is assigned
    }

    final name = label.toLowerCase().trim();

    if (name.contains('food') ||
        name.contains('breakfast') ||
        name.contains('lunch') ||
        name.contains('dinner') ||
        name.contains('snack') ||
        name.contains('bakery') ||
        name.contains('restaurant')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('goods') || name.contains('shopping') || name.contains('supermarket')) {
      return Icons.shopping_bag_outlined;
    }
    if (name.contains('transport') ||
        name.contains('fuel') ||
        name.contains('ride') ||
        name.contains('taxi') ||
        name.contains('bus')) {
      return Icons.directions_bus_rounded;
    }
    if (name.contains('mobile') ||
        name.contains('airtime') ||
        name.contains('internet') ||
        name.contains('wifi') ||
        name.contains('data') ||
        name.contains('phone')) {
      return Icons.phone_android_rounded;
    }
    if (name.contains('housing') || name.contains('rent')) {
      return Icons.home_rounded;
    }
    if (name.contains('medical') ||
        name.contains('health') ||
        name.contains('pharmacy') ||
        name.contains('hospital')) {
      return Icons.local_hospital_outlined;
    }
    if (name.contains('education') || name.contains('school')) {
      return Icons.school_outlined;
    }
    if (name.contains('entertainment') || name.contains('movie')) {
      return Icons.movie_outlined;
    }
    if (name.contains('utility') || name.contains('utilities') || name.contains('bill') || name.contains('electricity') || name.contains('water')) {
      return Icons.bolt_rounded;
    }
    if (name.contains('salary') || name.contains('payroll') || name.contains('income')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (name.contains('loan') || name.contains('lend') || name.contains('borrow')) {
      return Icons.handshake_outlined;
    }
    if (name.contains('bounce') || name.contains('reversal')) {
      return Icons.replay_rounded;
    }
    if (name.contains('internal transfer') || name.contains('transfer')) {
      return Icons.swap_horiz_rounded;
    }
    if (name.contains('cash')) {
      return Icons.payments_outlined;
    }

    return Icons.category_outlined;
  }

  Widget _buildAssignedReasonCard(
    BuildContext context,
    FinanceProvider provider,
    String? currentLabel,
    int? activeReasonId,
    bool isSpecialReason,
    bool isReasonBlocked,
    bool isAutoLocked,
    LoanRecord? linkedLoan,
    AppReasonLink? activeLink,
    bool isIncome,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () {
            if (linkedLoan != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('In order to change the reason, delete the loan record from Loan Manager first.'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            if (isAutoLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reason is locked — this transaction was auto-created from a Telebirr credit SMS.'),
                  backgroundColor: AppColors.warning,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            _showReasonPicker(context, provider);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (currentLabel != null
                                ? AppColors.positive
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isReasonBlocked
                            ? Icons.lock_outline
                            : _getReasonCategoryIcon(currentLabel),
                        color: isReasonBlocked
                            ? AppColors.warning
                            : (currentLabel != null
                                ? AppColors.positive
                                : AppColors.textSecondary),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLabel ?? 'Uncategorized',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activeReasonId != null && !isSpecialReason) ...[
                      GestureDetector(
                        onTap: () async {
                          if (activeLink != null) {
                            await provider.deleteReasonLink(activeLink.id!);
                          } else {
                            await provider.addReasonLink(
                              reasonId: activeReasonId,
                              linkedName: widget.transaction.sender,
                              linkType: isIncome ? 'sender' : 'receiver',
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: activeLink != null
                                ? AppColors.negative.withValues(alpha: 0.12)
                                : AppColors.positive.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activeLink != null
                                  ? AppColors.negative.withValues(alpha: 0.25)
                                  : AppColors.positive.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                activeLink != null ? Icons.link_off : Icons.add_link,
                                color: activeLink != null
                                    ? AppColors.negative
                                    : AppColors.positive,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                activeLink != null ? 'Unlink' : 'Link',
                                style: TextStyle(
                                  color: activeLink != null
                                      ? AppColors.negative
                                      : AppColors.positive,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Icon(
                      isReasonBlocked ? Icons.lock : Icons.chevron_right,
                      color: isReasonBlocked ? AppColors.warning : AppColors.textSecondary,
                      size: isReasonBlocked ? 16 : 20,
                    ),
                  ],
                ),
                if (isReasonBlocked) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 14),
                        const SizedBox(width: 8),
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
        ),
      ),
    );
  }

  Widget _buildCollapsiblePersonalNoteCard(BuildContext context, FinanceProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () {
            setState(() {
              _isPersonalNoteExpanded = !_isPersonalNoteExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_alt_outlined, color: AppColors.positive, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'PERSONAL NOTE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _attachMedia(context, provider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.positive.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.attach_file_rounded, color: AppColors.positive, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Attach Media',
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: AnimatedRotation(
                        turns: _isPersonalNoteExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add a private note about this transaction...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                        onEditingComplete: () {
                          FocusScope.of(context).unfocus();
                          _save(provider);
                        },
                      ),
                      if (widget.transaction.attachments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'ATTACHMENTS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.transaction.attachments.map((att) {
                            IconData attIcon = Icons.image_rounded;
                            if (att.fileType == 'pdf') attIcon = Icons.picture_as_pdf_rounded;
                            if (att.fileType == 'audio') attIcon = Icons.audiotrack_rounded;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(attIcon, color: AppColors.positive, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    att.fileName ?? att.fileType.toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      provider.deleteAttachment(widget.transaction.id!, att.id);
                                    },
                                    child: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                  crossFadeState: _isPersonalNoteExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleRawMessageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: () {
            setState(() {
              _isRawMessageExpanded = !_isRawMessageExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.message_outlined, color: AppColors.positive, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'RAW MESSAGE SOURCE',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.transaction.rawMessage));
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
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.positive.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.positive.withValues(alpha: 0.2)),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: AnimatedRotation(
                        turns: _isRawMessageExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
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
                    ],
                  ),
                  crossFadeState: _isRawMessageExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 280),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinkReasonInfoSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'Automatic Reason Linking',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Linking a reason to a sender automatically assigns that reason to future transactions from the same direction (outgoing to outgoing, or incoming to incoming). You can view and manage linked rules anytime under Settings > Category Management.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
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
              AppColors.background,
              AppColors.bgMid,
            ],
          ),
        ),
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
                style: TextStyle(color: AppColors.positive, fontWeight: FontWeight.bold)),
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
              ? AppColors.positive.withValues(alpha: 0.12)
              : AppColors.surfaceCard.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.positive
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.positive.withValues(alpha: 0.2)
                    : AppColors.surfaceCard.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star_border,
                  color:
                      isSelected ? AppColors.positive : AppColors.textSecondary,
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
                              ? AppColors.positive
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
                  color: AppColors.positive, size: 20),
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
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Center(
              child: InteractiveDragHandle(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                onTap: () => Navigator.pop(ctx),
                onVerticalDragUpdate: (details) {
                  if ((details.primaryDelta ?? 0) > 3) {
                    Navigator.pop(ctx);
                  }
                },
                padding: const EdgeInsets.only(bottom: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text('Select Reason',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
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
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (normalSystem.isNotEmpty) ...[
                      _sectionLabel('System Categories'),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      ...specialSystem
                          .map((r) => _buildSpecialTile(r)),
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
                                color: AppColors.positive
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add,
                                  size: 16, color: AppColors.positive),
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
            const SizedBox(height: 16),
            // Primary Action Button (Matching Freeze Account button layout)
            GestureDetector(
              onTap: _selectedReason == null
                  ? null
                  : () {
                      widget.onSave(_selectedReason!);
                    },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: _selectedReason == null
                      ? AppColors.positive.withValues(alpha: 0.3)
                      : AppColors.positive,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    'Save Changes',
                    style: TextStyle(
                      color: _selectedReason == null
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppColors.background,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
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
              ? AppColors.positive.withValues(alpha: 0.15)
              : AppColors.surfaceCard.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.positive
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reason.isSystem)
              const Icon(Icons.verified_outlined,
                  size: 13, color: AppColors.positive),
            if (reason.isSystem) const SizedBox(width: 4),
            Text(reason.name,
                style: TextStyle(
                    color: isSelected
                        ? AppColors.positive
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
