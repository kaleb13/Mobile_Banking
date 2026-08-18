import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/loan_record.dart';
import '../../models/cash_transaction.dart';
import '../../models/transaction_attachment.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/link_extractor.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_note_card.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/custom_progress_bar.dart';
import '../loans/loan_management_screen.dart';
import 'internal_transfer_picker_sheet.dart';
import 'reason_selection_sheet.dart';
import 'reason_link_drawer.dart';

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
  bool _isReceiptLinkExpanded = false;
  bool _isMenuOpen = false;

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
    final currentTx = provider.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;

    AppReason? initial = _selectedReason;
    if (initial == null && currentTx.resolvedReason != null) {
      initial = provider.reasons
          .where((r) =>
              r.name.toLowerCase() ==
              currentTx.resolvedReason!.toLowerCase())
          .firstOrNull;
    }

    AppReason? chosen;

    await AppDrawer.show(
      context: context,
      builder: (sheetCtx) {
        return ReasonSelectionSheet(
          initialReason: initial,
          transactionType: widget.transaction.type,
          onReasonSelected: (reason) {
            chosen = reason;
          },
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

    final latestTx = provider.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;

    final chosenName = chosen!.name.trim().toLowerCase();

    if (chosenName == 'loan' || chosenName.contains('loan')) {
      final existingLoan = provider.loanRecords
          .where((l) => l.linkedTransactionId == latestTx.id)
          .firstOrNull;
      if (mounted && context.mounted) {
        final shouldCreate = await AppConfirmDialog.show(
          context: context,
          title: existingLoan == null ? 'Create Loan Record?' : 'Manage Loan Record',
          icon: Icons.handshake_outlined,
          iconColor: AppColors.positive,
          message: existingLoan == null
              ? 'This transaction (${NumberFormat("#,##0.00").format(latestTx.amount)} ETB) was tagged as a loan.\n\nWould you like to track its repayment in the Loan Manager?'
              : 'This transaction is tagged as a loan (${existingLoan.personName} - ${NumberFormat("#,##0.00").format(existingLoan.principalAmount)} ETB).\n\nWould you like to open the Loan Sheet to view or update it?',
          confirmText: existingLoan == null ? 'Create Loan' : 'Open Loan Sheet',
          cancelText: 'Skip',
          onConfirm: () {},
        );

        if (shouldCreate == true && mounted && context.mounted) {
          await AppDrawer.show(
            context: context,
            builder: (_) => AddLoanSheet(
              provider: provider,
              linkedTransactionId: latestTx.id,
              prefilledAmount: latestTx.amount,
              prefilledName: existingLoan?.personName ?? latestTx.sender,
              prefilledTrackedSender: latestTx.sender,
              prefilledType:
                  latestTx.type == 'expense' ? 'lent' : 'borrowed',
            ),
          );
        }
      }
    } else if (chosenName == 'internal transfer') {
      if (!context.mounted) return;
      await AppDrawer.show(
        context: context,
        builder: (_) => InternalTransferPickerSheet(
          sourceTransaction: latestTx,
          provider: provider,
        ),
      );
    }
  }

  Future<void> _save(FinanceProvider provider) async {
    final currentTx = provider.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;
    if (currentTx.id == null) return;

    final noteText = _noteController.text.trim();
    bool changesMade = false;

    if (_selectedReason != null) {
      final isSub = _selectedReason!.isSubcategory;
      final isTop = _selectedReason!.isTopLevelCategory;
      await provider.updateTransactionReason(
        currentTx.id!,
        reasonId: _selectedReason!.id,
        categoryId: isSub ? _selectedReason!.parentId : (isTop ? _selectedReason!.id : null),
        subcategoryId: isSub ? _selectedReason!.id : null,
        note: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else if (noteText != (currentTx.note ?? '')) {
      await provider.updateTransactionNote(
        currentTx.id!,
        noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    }

    if (mounted && context.mounted && changesMade) {
      AppToast.success(context, message: 'Details saved');
    }
  }

  Future<void> _confirmDeleteTransaction(
      BuildContext context, FinanceProvider provider) async {
    if (widget.transaction.id == null) return;
    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Delete Transaction?',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.negative,
      message:
          'Are you sure you want to delete this transaction? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () {},
    );

    if (shouldDelete == true && context.mounted) {
      await provider.deleteTransaction(widget.transaction.id!);
      if (context.mounted) {
        AppToast.info(context, message: 'Transaction deleted');
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
    final currentTx = provider.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;

    final bool isIncome = currentTx.type == 'income';
    final sign = isIncome ? '+' : '-';
    final amountColor = isIncome ? AppColors.positive : AppColors.negative;

    // Resolved current label to show in the chip
    final String? currentLabel =
        _selectedReason?.name ?? currentTx.resolvedReason;

    final int? activeReasonId =
        _selectedReason?.id ?? currentTx.reasonId;

    // Find linked loan if any
    LoanRecord? linkedLoan;
    try {
      linkedLoan = provider.loanRecords.firstWhere(
        (l) => l.linkedTransactionId == currentTx.id,
      );
    } catch (_) {
      linkedLoan = null;
    }

    final bool isCashWithDeductions = (currentTx.reason?.toLowerCase() == 'cash' ||
            currentTx.customReasonText?.toLowerCase() == 'cash' ||
            currentTx.resolvedReason?.toLowerCase() == 'cash') &&
        provider.spendingsForTransaction(currentTx.id ?? '').isNotEmpty;

    // True if this transaction is auto-locked (Telebirr credit/repayment)
    final bool isAutoLocked = currentTx.isReasonLocked;
    // True if reason editing is blocked by any lock (linked loan OR auto-lock OR cash with active deductions)
    final bool isReasonBlocked = linkedLoan != null || isAutoLocked || isCashWithDeductions;

    AppReasonLink? activeLink;
    if (activeReasonId != null) {
      final links = provider.linksForReason(activeReasonId);
      final idx = links.indexWhere((l) =>
          l.linkedName.toLowerCase() ==
          currentTx.sender.toLowerCase());
      if (idx != -1) activeLink = links[idx];
    }

    // Special reasons have dedicated tile renderer — hide the generic Link User button for these
    const specialReasonNames = {
      'loan', 'bounce', 'internal transfer', 'cash'
    };
    final activeReasonName = (_selectedReason?.name ??
            currentTx.resolvedReason ??
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
            if (currentTx.id != null) ...[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: currentTx.isBookmarked
                      ? AppColors.gold.withValues(alpha: 0.15)
                      : AppColors.buttonSecondary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(
                    currentTx.isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    color: currentTx.isBookmarked ? AppColors.gold : Colors.white,
                    size: 19,
                  ),
                  tooltip: currentTx.isBookmarked
                      ? 'Remove Bookmark'
                      : 'Bookmark Transaction',
                  onPressed: () async {
                    await provider.toggleTransactionBookmark(currentTx.id!);
                    if (context.mounted) {
                      final isNowBookmarked = !currentTx.isBookmarked;
                      if (isNowBookmarked) {
                        AppToast.success(context, message: 'Transaction bookmarked');
                      } else {
                        AppToast.info(context, message: 'Bookmark removed');
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 6),
            ],
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.white.withValues(alpha: 0.15),
                highlightColor: Colors.white.withValues(alpha: 0.12),
              ),
              child: PopupMenuButton<String>(
                onOpened: () => setState(() => _isMenuOpen = true),
                onCanceled: () => setState(() => _isMenuOpen = false),
                offset: const Offset(0, 42),
                constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
                borderRadius: BorderRadius.circular(100),
                padding: EdgeInsets.zero,
                icon: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _isMenuOpen
                        ? AppColors.buttonSecondary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.more_vert_rounded,
                      color: Colors.white, size: 20),
                ),
                color: AppColors.surface,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  setState(() => _isMenuOpen = false);
                  if (value == 'delete') {
                    _confirmDeleteTransaction(context, provider);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Delete',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.negative,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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

                        // ── 1. LOAN TRACKING / INTERNAL TRANSFER CARD (TOP MOST) ──
                        if (linkedLoan != null) ...[
                          _buildLoanTrackingCard(context, linkedLoan, provider),
                          const SizedBox(height: 14),
                        ] else if (currentTx.linkedTransactionId != null) ...[
                          _buildInternalTransferCard(context, provider, currentTx),
                          const SizedBox(height: 14),
                        ] else if (!isAutoLocked && (activeReasonName == 'loan' || activeReasonName.contains('loan'))) ...[
                          _buildCreateLoanPromptCard(context, provider, currentTx),
                          const SizedBox(height: 14),
                        ] else if (!isAutoLocked && (activeReasonName == 'internal transfer' || activeReasonName.contains('internal transfer') || activeReasonName == 'transfer')) ...[
                          _buildLinkInternalTransferPromptCard(context, provider, currentTx),
                          const SizedBox(height: 14),
                        ] else if ((currentLabel?.toLowerCase() == 'cash' || currentTx.reason?.toLowerCase() == 'cash') && currentTx.type == 'expense') ...[
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
                          isCashWithDeductions,
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

                    if (widget.transaction.hasLinks) ...[
                      const SizedBox(height: 14),
                      // ── Collapsible Receipt Link Section ───────────────────
                      _buildCollapsibleReceiptLinkCard(context),
                    ],

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
      iconWidget = SvgPicture.asset('assets/images/Ahadu_Logo.svg', width: 24, height: 24, fit: BoxFit.contain);
      bankName = 'Ahadu Bank';
      shortName = 'Ahadu';
      bg = AppColors.cardAhaduRed.withValues(alpha: 0.15);
    } else if (combined.contains('ABYSSINIA') || combined.contains('BOA')) {
      iconWidget = SvgPicture.asset('assets/images/Bank_of_Abyssinia_Icon.svg', width: 24, height: 24, fit: BoxFit.contain);
      bankName = 'Bank of Abyssinia S.C.';
      shortName = 'BOA';
      bg = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (combined.contains('DASHEN')) {
      iconWidget = SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      bankName = 'Dashen Bank S.C.';
      shortName = 'Dashen';
      bg = AppColors.cardDashenLight.withValues(alpha: 0.18);
    } else if (combined.contains('CBE') || combined.contains('COMMERCIAL BANK')) {
      iconWidget = Image.asset('assets/images/CBE logo 1.webp', width: 24, height: 24);
      bankName = 'Commercial Bank of Ethiopia';
      shortName = 'CBE';
      bg = AppColors.slackPurple.withValues(alpha: 0.15);
    } else if (combined.contains('CASH')) {
      iconWidget = SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.positive, BlendMode.srcIn),
      );
      bankName = 'Cash Wallet';
      shortName = 'Cash';
      bg = AppColors.positive.withValues(alpha: 0.15);
    } else {
      iconWidget = const Icon(Icons.account_balance_outlined, color: AppColors.positive, size: 22);
      bankName = senderStr.isNotEmpty ? senderStr : 'Mobile Banking';
      shortName = senderStr.isNotEmpty ? senderStr : 'Bank';
      bg = AppColors.buttonSecondary;
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
        color: AppColors.surface,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
              AppBadge.success(
                text: '${fmtShort.format(remaining)} ETB Left',
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar
          CustomProgressBar(
            progress: progress,
            height: 10,
            progressColor:
                progress >= 1.0 ? AppColors.negative : AppColors.positive,
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
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.textSoft, size: 16),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                      tooltip: 'Delete deduction',
                      onPressed: () {
                        AppConfirmDialog.show(
                          context: context,
                          title: 'Delete Deduction?',
                          message:
                              'Remove this ${fmtShort.format(s.amount)} ETB $reasonLabel deduction and return the funds to this withdrawal balance?',
                          confirmText: 'Delete',
                          isDestructive: true,
                          onConfirm: () async {
                            if (s.id != null) {
                              await provider.deleteCashTransaction(s.id!);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 12),
          if (remaining > 0)
            AppButton.secondary(
              height: 38,
              icon: Icons.add_circle_outline_rounded,
              text: 'Deduct Cash Expense',
              onPressed: () {
                _showDeductCashFromWithdrawalModal(context, provider, widget.transaction);
              },
            )
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: AppBadge.success(
                  text: 'Fully Allocated (100%)',
                  icon: Icons.check_circle_rounded,
                  size: AppBadgeSize.medium,
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
    final pendingAttachments = <TransactionAttachment>[];
    AppReason? selectedReason;
    final fmtShort = NumberFormat('#,##0.00');

    AppDrawer.show(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final remaining = provider.getCashWithdrawalRemainingAmount(bankTx.id!, bankTx.amount);
          final enteredAmt = double.tryParse(amountController.text.trim());
          final bool isExceeded = enteredAmt != null && enteredAmt > remaining;
          final bool isValid = enteredAmt != null && enteredAmt > 0 && !isExceeded && selectedReason != null;
          final String buttonText = isExceeded
              ? 'Exceeds Remaining Limit'
              : (selectedReason == null
                  ? 'Select Reason to Save'
                  : (enteredAmt == null || enteredAmt <= 0
                      ? 'Enter Amount'
                      : 'Save Deduction'));

          return AppDrawer(
            heightFactor: 0.85,
            headerCard: AppDrawerHeaderCard(
              icon: Icons.money_off_rounded,
              iconColor: AppColors.positive,
              title: 'Deduct Cash Expense',
              subtitle: 'Linked to ${bankTx.name} (${fmtShort.format(remaining)} ETB left)',
            ),
            bottomAction: AppButton.primary(
              text: buttonText,
              height: 48,
              onPressed: !isValid
                  ? null
                  : () async {
                      final amtStr = amountController.text.trim();
                      final amt = double.tryParse(amtStr);
                      if (amt == null || amt <= 0 || selectedReason == null || amt > remaining) return;

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
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: isExceeded ? AppColors.negative : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.15)),
                    suffixText: provider.currentCurrency.shortLabel,
                    suffixStyle: TextStyle(
                      color: isExceeded ? AppColors.negative : AppColors.textSoft,
                      fontSize: 16,
                    ),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide.none),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                if (isExceeded) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: AppBadge.destructive(
                      text:
                          'Exceeds remaining limit of ${fmtShort.format(remaining)} ${provider.currentCurrency.shortLabel}',
                      icon: Icons.error_outline_rounded,
                      size: AppBadgeSize.medium,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: () {
                    AppBottomSheet.show(
                      context: ctx,
                      isScrollControlled: true,
                      builder: (_) => ReasonSelectionSheet(
                        initialReason: selectedReason,
                        transactionType: 'expense',
                        isCashSpending: true,
                        onReasonSelected: (r) => setModalState(() => selectedReason = r),
                      ),
                    );
                  },
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selectedReason != null
                          ? AppColors.positive.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category_rounded,
                          color: selectedReason != null
                              ? AppColors.positive
                              : AppColors.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedReason?.name ?? 'Select Expense Reason (Required)',
                            style: TextStyle(
                              color: selectedReason != null
                                  ? Colors.white
                                  : AppColors.gold,
                              fontSize: 13,
                              fontWeight: selectedReason != null
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_right, color: Colors.white54, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppNoteCard(
                  controller: noteController,
                  title: 'NOTE & RECEIPT',
                  hintText: 'Add an optional note or attach receipts...',
                  attachments: pendingAttachments,
                  isCollapsible: true,
                  initialExpanded: false,
                  accentColor: AppColors.positive,
                  onAttachMedia: (filePath, fileType, fileName) async {
                    setModalState(() {
                      pendingAttachments.add(TransactionAttachment(
                        id: 'att_${DateTime.now().millisecondsSinceEpoch}',
                        transactionId: bankTx.id ?? '',
                        filePath: filePath,
                        fileType: fileType,
                        fileName: fileName,
                        createdAt: DateTime.now().toIso8601String(),
                      ));
                    });
                  },
                  onDeleteAttachment: (att) {
                    setModalState(() {
                      pendingAttachments.removeWhere((a) => a.id == att.id);
                    });
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildCollapsibleInfoRow(IconData icon, String label, String value,
      {Widget? customValue, String? tooltipText}) {
    final effectiveTooltip = tooltipText ?? (value.isNotEmpty ? value : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: customValue ??
                  (effectiveTooltip != null
                      ? Tooltip(
                          message: effectiveTooltip,
                          triggerMode: TooltipTriggerMode.longPress,
                          preferBelow: false,
                          showDuration: const Duration(seconds: 3),
                          waitDuration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : Text(
                          value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
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
    bool isCashLocked,
    LoanRecord? linkedLoan,
    AppReasonLink? activeLink,
    bool isIncome,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
          onTap: () async {
            if (linkedLoan != null) {
              AppToast.warning(
                context,
                message: 'To change reason, delete loan record first',
              );
              return;
            }
            if (isAutoLocked) {
              AppToast.warning(
                context,
                message: 'Reason is locked — auto-created from SMS',
              );
              return;
            }
            if (isCashLocked) {
              final spendings = provider.spendingsForTransaction(widget.transaction.id ?? '');
              AppConfirmDialog.show(
                context: context,
                title: 'Reason Locked',
                message:
                    'This transaction has ${spendings.length} active cash ${spendings.length == 1 ? 'deduction' : 'deductions'} linked to it. To change the reason away from Cash, all linked deductions must be removed first.\n\nWould you like to delete all linked deductions and change the reason now?',
                confirmText: 'Clear & Edit',
                cancelText: 'Keep Locked',
                isDestructive: true,
                onConfirm: () async {
                  for (final s in spendings) {
                    if (s.id != null) {
                      await provider.deleteCashTransaction(s.id!);
                    }
                  }
                  if (context.mounted) {
                    _showReasonPicker(context, provider);
                  }
                },
              );
              return;
            }
            _showReasonPicker(context, provider);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Single solid filled lock icon with matching soft tint when locked, or clean translucent white when unlocked
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isReasonBlocked
                        ? AppColors.warning.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isReasonBlocked
                          ? Icons.lock_rounded
                          : _getReasonCategoryIcon(currentLabel),
                      color: isReasonBlocked
                          ? AppColors.warning
                          : Colors.white,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentLabel ?? 'Uncategorized',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isReasonBlocked
                            ? (isAutoLocked
                                ? 'Locked • Telebirr credit transaction'
                                : (isCashLocked
                                    ? 'Locked • Linked deductions active'
                                    : 'Locked • Linked loan record'))
                            : (currentLabel != null
                                ? 'Tap to change reason'
                                : 'Assign a reason for tracking'),
                        style: TextStyle(
                          color: isReasonBlocked
                              ? Colors.white54
                              : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeReasonId != null && !isSpecialReason) ...[
                  if (activeLink != null)
                    AppButton.softDestructive(
                      text: 'Unlink',
                      icon: Icons.link_off_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      onPressed: () {
                        UnlinkReasonDrawer.show(
                          context: context,
                          link: activeLink,
                          reasonName: currentLabel ?? 'Reason',
                          contactName: widget.transaction.sender,
                          currentTransactionId: widget.transaction.id,
                        );
                      },
                    )
                  else
                    AppButton.secondary(
                      text: 'Link',
                      icon: Icons.add_link_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      onPressed: () {
                        LinkReasonDrawer.show(
                          context: context,
                          reasonId: activeReasonId,
                          reasonName: currentLabel ?? 'Reason',
                          contactName: widget.transaction.sender,
                          linkType: isIncome ? 'sender' : 'receiver',
                          currentTransactionId: widget.transaction.id,
                        );
                      },
                    ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsiblePersonalNoteCard(BuildContext context, FinanceProvider provider) {
    return AppNoteCard(
      controller: _noteController,
      title: 'PERSONAL NOTE',
      hintText: 'Add a private note about this transaction...',
      attachments: widget.transaction.attachments,
      isCollapsible: true,
      initialExpanded: _isPersonalNoteExpanded,
      accentColor: AppColors.positive,
      onChanged: (_) => setState(() {}),
      onEditingComplete: () => _save(provider),
      onAttachMedia: (filePath, fileType, fileName) async {
        await provider.addAttachment(
          widget.transaction.id!,
          filePath,
          fileType,
          fileName: fileName,
        );
      },
      onDeleteAttachment: (att) {
        provider.deleteAttachment(widget.transaction.id!, att.id);
      },
    );
  }

  Widget _buildCollapsibleRawMessageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                    AppButton.secondary(
                      text: 'Copy',
                      icon: Icons.copy_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.transaction.rawMessage));
                        AppToast.success(context, message: 'Raw message copied to clipboard');
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
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

  Widget _buildCollapsibleReceiptLinkCard(BuildContext context) {
    final links = widget.transaction.extractedLinks;
    if (links.isEmpty) return const SizedBox.shrink();

    final primaryLink = links.first;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
              _isReceiptLinkExpanded = !_isReceiptLinkExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link_rounded, color: AppColors.positive, size: 18),
                    const SizedBox(width: 10),
                    const Text(
                      'RECEIPT LINK',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    AppButton.secondary(
                      text: 'Copy',
                      icon: Icons.copy_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: primaryLink));
                        AppToast.success(context, message: 'Receipt link copied to clipboard');
                      },
                    ),
                    const SizedBox(width: 6),
                    AppButton.primary(
                      text: 'Open',
                      icon: Icons.open_in_browser_rounded,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      onPressed: () async {
                        final uri = Uri.parse(LinkExtractor.normalizeUrl(primaryLink));
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            AppToast.error(context, message: 'Unable to open link');
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: AnimatedRotation(
                        turns: _isReceiptLinkExpanded ? 0.5 : 0.0,
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
                      ...links.map((link) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () async {
                                final uri = Uri.parse(LinkExtractor.normalizeUrl(link));
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  if (context.mounted) {
                                    AppToast.error(context, message: 'Unable to open link');
                                  }
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.open_in_new_rounded,
                                      color: AppColors.positive,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        link,
                                        style: const TextStyle(
                                          color: AppColors.textSoft,
                                          height: 1.4,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.positive,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )),
                    ],
                  ),
                  crossFadeState: _isReceiptLinkExpanded
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
                      const SizedBox(height: 4),
                      loan.isPaid
                          ? const AppBadge.success(
                              text: 'SETTLED',
                              icon: Icons.check_circle_rounded,
                              size: AppBadgeSize.small,
                            )
                          : const AppBadge.warning(
                              text: 'IN PROGRESS',
                              icon: Icons.schedule_rounded,
                              size: AppBadgeSize.small,
                            ),
                    ],
                  ),
                ),
                AppButton.secondary(
                  text: 'View Manager',
                  fullWidth: false,
                  height: 30,
                  fontSize: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  onPressed: () {
                    provider.setScreenIndex(3);
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
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
            CustomProgressBar(
              progress: loan.progressPercent,
              height: 10,
              progressColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showLoanOptionsSheet(
      BuildContext context, LoanRecord loan, FinanceProvider provider) {
    AppDrawer.show(
      context: context,
      builder: (ctx) => AppDrawer(
        heightFactor: null,
        isBodyScrollable: false,
        headerCard: AppDrawerHeaderCard(
          icon: Icons.handshake_outlined,
          iconColor: AppColors.positive,
          title: 'Loan Options',
          subtitle: loan.personName,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: Colors.white.withValues(alpha: 0.04),
              leading: const Icon(Icons.open_in_new, color: AppColors.brandGreen),
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
                final confirm = await AppConfirmDialog.show(
                  context: context,
                  title: 'Delete Loan Record?',
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.negative,
                  message:
                      'Are you sure you want to delete this loan record?\n\nDeleting it will stop tracking its repayments and unlock the reason section so you can change it.',
                  confirmText: 'Delete Loan',
                  cancelText: 'Cancel',
                  isDestructive: true,
                  onConfirm: () {},
                );
                if (confirm == true && mounted) {
                  await provider.deleteLoan(loan.id!);
                  if (mounted && context.mounted) {
                    AppToast.info(
                      context,
                      message: 'Loan record deleted',
                      subtitle: 'Reason editing is now unlocked',
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

  Widget _buildCreateLoanPromptCard(
      BuildContext context, FinanceProvider provider, AppTransaction currentTx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.positive.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.handshake_outlined,
                color: AppColors.positive, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Loan Record',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Track repayment & schedule for this transaction',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Create',
            icon: Icons.add_rounded,
            fullWidth: false,
            height: 32,
            fontSize: 11.5,
            iconSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onPressed: () async {
              await AppDrawer.show(
                context: context,
                builder: (_) => AddLoanSheet(
                  provider: provider,
                  linkedTransactionId: currentTx.id,
                  prefilledAmount: currentTx.amount,
                  prefilledName: currentTx.sender,
                  prefilledTrackedSender: currentTx.sender,
                  prefilledType:
                      currentTx.type == 'expense' ? 'lent' : 'borrowed',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLinkInternalTransferPromptCard(
      BuildContext context, FinanceProvider provider, AppTransaction currentTx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_alt,
                color: AppColors.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link Internal Transfer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Match with corresponding debit/credit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppButton.primary(
            text: 'Link',
            icon: Icons.add_link_rounded,
            fullWidth: false,
            height: 32,
            fontSize: 11.5,
            iconSize: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onPressed: () async {
              await AppDrawer.show(
                context: context,
                builder: (_) => InternalTransferPickerSheet(
                  sourceTransaction: currentTx,
                  provider: provider,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInternalTransferCard(
      BuildContext context, FinanceProvider provider, AppTransaction currentTx) {
    AppTransaction? linkedTx;
    try {
      linkedTx = provider.transactions
          .firstWhere((t) => t.id == currentTx.linkedTransactionId);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
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
              AppButton.softDestructive(
                text: 'Unlink',
                icon: Icons.link_off_rounded,
                fullWidth: false,
                height: 28,
                fontSize: 10.5,
                iconSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                onPressed: () async {
                  final shouldUnlink = await AppConfirmDialog.show(
                    context: context,
                    title: 'Unlink Transfer?',
                    icon: Icons.link_off_rounded,
                    iconColor: AppColors.negative,
                    message:
                        'Are you sure you want to unlink this internal transfer?',
                    confirmText: 'Unlink',
                    cancelText: 'Cancel',
                    isDestructive: true,
                    onConfirm: () {},
                  );
                  if (shouldUnlink == true && context.mounted) {
                    await provider.unlinkInternalTransfer(currentTx.id!);
                    if (context.mounted) {
                      AppToast.info(context, message: 'Internal transfer unlinked');
                    }
                  }
                },
              ),
            ],
          ),
          if (linkedTx != null) ...[
            const SizedBox(height: 12),
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
