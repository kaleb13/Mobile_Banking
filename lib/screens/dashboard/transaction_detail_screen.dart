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
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../presentation/viewmodels/loans_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/link_extractor.dart';
import '../../utils/counterparty_matcher.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/app_menu_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_note_card.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/custom_progress_bar.dart';
import '../../widgets/counterparty_insight_sheet.dart';
import '../loans/loan_management_screen.dart';
import 'internal_transfer_picker_sheet.dart';
import 'reason_selection_sheet.dart';
import 'reason_link_drawer.dart';
import 'split_transaction_sheet.dart';
import '../../models/transaction_split.dart';

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
      BuildContext context, TransactionsViewModel txVM, LoansViewModel loansVM) async {
    final currentTx = txVM.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;

    AppReason? initial = _selectedReason;
    if (initial == null && currentTx.resolvedReason != null) {
      initial = txVM.reasons
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
    await _save(txVM);

    if (mounted) {
      setState(() {
        _selectedReason = null;
      });
    }

    if (!mounted || !context.mounted) return;

    final latestTx = txVM.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;

    final chosenName = chosen!.name.trim().toLowerCase();

    if (chosenName == 'loan' || chosenName.contains('loan')) {
      final existingLoan = loansVM.loanRecords
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
        ),
      );
    }
  }

  Future<void> _save(TransactionsViewModel txVM) async {
    final currentTx = txVM.transactions
        .where((t) => t.id == widget.transaction.id)
        .firstOrNull ?? widget.transaction;
    if (currentTx.id == null) return;

    final noteText = _noteController.text.trim();
    bool changesMade = false;

    if (_selectedReason != null) {
      final isSub = _selectedReason!.isSubcategory;
      final isTop = _selectedReason!.isTopLevelCategory;
      await txVM.updateTransactionReason(
        currentTx.id!,
        reason: _selectedReason!.name,
        reasonId: _selectedReason!.id,
        categoryId: isSub ? _selectedReason!.parentId : (isTop ? _selectedReason!.id : null),
        subcategoryId: isSub ? _selectedReason!.id : null,
        note: noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    } else if (noteText != (currentTx.note ?? '')) {
      await txVM.updateTransactionNote(
        currentTx.id!,
        noteText.isNotEmpty ? noteText : null,
      );
      changesMade = true;
    }

    if (mounted && context.mounted && changesMade) {
      if (_selectedReason != null) {
        final reasonName = _selectedReason!.name.trim();
        final rLower = reasonName.toLowerCase();
        final isIncome = currentTx.type == 'income';

        String toastSubtitle;
        String toastDetails;
        Map<String, String> toastMetadata;

        if (rLower == 'loan' || rLower.contains('loan')) {
          toastSubtitle = 'Assigned to Loan & Debt Tracker';
          toastDetails =
              'This transaction is tagged as a loan. You can track repayments, due dates, and person balances by creating a loan record directly from the banner card or in the Loan Manager.';
          toastMetadata = {
            'Reason': reasonName,
            'Direction': isIncome ? 'Borrowed' : 'Lent',
            'Status': 'Ready for Tracking',
          };
        } else if (rLower == 'cash') {
          toastSubtitle = 'Categorized as Cash Withdrawal';
          toastDetails =
              'This withdrawal is recorded in your Cash Wallet. You can now log individual daily expenses and micro-purchases against this cash withdrawal from the breakdown card.';
          toastMetadata = {
            'Reason': 'Cash',
            'Wallet': 'Cash Ledger',
            'Action': 'Log Deductions',
          };
        } else if (rLower == 'internal transfer' || rLower.contains('transfer')) {
          toastSubtitle = 'Categorized as Internal Transfer';
          toastDetails =
              'This transaction represents moving funds between your own accounts or wallets. It is excluded from total expense/income calculations to prevent double-counting. You can link it to the corresponding opposite transaction.';
          toastMetadata = {
            'Reason': 'Transfer',
            'Impact': 'Neutral (No PnL change)',
          };
        } else if (rLower == 'pass-through' || rLower == 'pass through' || rLower == 'bounce' || rLower.contains('reversal')) {
          toastSubtitle = 'Categorized as Pass-Through';
          toastDetails =
              'This transaction is for transit or pass-through money that does not belong to you. It is completely excluded from expense analysis and financial calculations.';
          toastMetadata = {
            'Reason': 'Pass-Through',
            'Impact': 'Excluded from analytics & expenses',
          };
        } else {
          toastSubtitle = 'Assigned to $reasonName';
          toastDetails =
              'This transaction has been categorized under $reasonName. You can optionally link this reason to ${currentTx.sender} so future messages are automatically classified.';
          toastMetadata = {
            'Reason': reasonName,
            'Flow': isIncome ? 'Income' : 'Expense',
          };
        }

        AppToast.success(
          context,
          message: 'Details Saved',
          subtitle: toastSubtitle,
          details: toastDetails,
          metadata: toastMetadata,
        );
      } else {
        AppToast.success(
          context,
          message: 'Details Saved',
          subtitle: 'Personal note updated',
          details: 'Your private notes and references for this transaction have been safely stored.',
        );
      }
    }
  }

  Future<void> _confirmDeleteFromApp(
      BuildContext context, TransactionsViewModel txVM) async {
    if (widget.transaction.id == null) return;

    final shouldDelete = await AppConfirmDialog.show(
      context: context,
      title: 'Delete Transaction?',
      message:
          'Are you sure you want to delete this transaction? Your wallet balances and charts will update immediately.',
      details:
          'The original SMS will remain safely in your phone\'s inbox.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDestructive: true,
      onConfirm: () {},
    );

    if (shouldDelete == true && context.mounted) {
      await txVM.deleteTransaction(widget.transaction.id!);
      if (context.mounted) {
        AppToast.info(
          context,
          message: 'Transaction Deleted',
          subtitle: 'Original SMS remains safe in your phone.',
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
    final txVM = Provider.of<TransactionsViewModel>(context);
    final cashVM = Provider.of<CashWalletViewModel>(context);
    final loansVM = Provider.of<LoansViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);

    final currentTx = txVM.transactions
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
      linkedLoan = loansVM.loanRecords.firstWhere(
        (l) => l.linkedTransactionId == currentTx.id,
      );
    } catch (_) {
      linkedLoan = null;
    }

    final bool isCashWithDeductions = (currentTx.reason?.toLowerCase() == 'cash' ||
            currentTx.customReasonText?.toLowerCase() == 'cash' ||
            currentTx.resolvedReason?.toLowerCase() == 'cash') &&
        cashVM.spendingsForTransaction(currentTx.id ?? '').isNotEmpty;

    // True if this transaction is auto-locked (Telebirr credit/repayment)
    final bool isAutoLocked = currentTx.isReasonLocked;
    // True if reason editing is blocked by any lock (linked loan OR auto-lock OR cash with active deductions)
    final bool isReasonBlocked = linkedLoan != null || isAutoLocked || isCashWithDeductions;

    AppReasonLink? activeLink;
    if (activeReasonId != null) {
      final links = txVM.linksForReason(activeReasonId);
      final idx = links.indexWhere((l) =>
          l.linkedName.toLowerCase() ==
          currentTx.sender.toLowerCase());
      if (idx != -1) activeLink = links[idx];
    }

    // Special reasons have dedicated tile renderer — hide the generic Link User button for these
    const specialReasonNames = {
      'loan', 'pass-through', 'pass through', 'bounce', 'internal transfer', 'cash'
    };
    final activeReasonName = (_selectedReason?.name ??
            currentTx.resolvedReason ??
            '')
        .trim()
        .toLowerCase();
    final isSpecialReason = specialReasonNames.contains(activeReasonName) ||
        activeReasonName.contains('loan');

    final bankInfo = _getBankInfo();
    final splits = txVM.getSplitsForTransaction(currentTx.id ?? '');

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
          leading: const Padding(
            padding: EdgeInsets.only(left: 12.0),
            child: AppBackButton(),
          ),
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
                    await txVM.toggleTransactionBookmark(currentTx.id!);
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
            AppMenuButton<String>.dark(
              minWidth: 170,
              items: const [
                AppMenuItem<String>(
                  value: 'delete',
                  label: 'Delete Transaction',
                  icon: Icons.delete_outline_rounded,
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeleteFromApp(context, txVM);
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
                        if (settingsVM.isBalanceVisible)
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
                                    .format(currentTx.amount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                '.${(currentTx.amount % 1).toStringAsFixed(2).split('.')[1]}',
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
                          )
                        else
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
                              const SizedBox(width: 6),
                              const Text(
                                '••••••••',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 18),

                        // ── 1. SPLIT TRANSACTION BREAKDOWN / LOAN / INTERNAL TRANSFER CARD (TOP MOST) ──
                        if (splits.isNotEmpty) ...[
                          _buildSplitBreakdownCard(context, txVM, settingsVM, currentTx, splits),
                          const SizedBox(height: 14),
                        ] else if (linkedLoan != null) ...[
                          _buildLoanTrackingCard(context, linkedLoan, loansVM, settingsVM),
                          const SizedBox(height: 14),
                        ] else if (currentTx.linkedTransactionId != null && currentTx.linkedTransactionId!.isNotEmpty) ...[
                          _buildInternalTransferCard(context, txVM, currentTx),
                          const SizedBox(height: 14),
                        ] else if (activeReasonName == 'loan' || activeReasonName.contains('loan')) ...[
                          _buildCreateLoanPromptCard(context, currentTx),
                          const SizedBox(height: 14),
                        ] else if (activeReasonName == 'internal transfer' || activeReasonName.contains('internal transfer') || activeReasonName == 'transfer') ...[
                          _buildLinkInternalTransferPromptCard(context, currentTx),
                          const SizedBox(height: 14),
                        ] else if ((currentLabel?.toLowerCase() == 'cash' || currentTx.reason?.toLowerCase() == 'cash') && currentTx.type == 'expense') ...[
                          _buildCashSpendingBreakdownCard(context, cashVM, settingsVM, txVM),
                          const SizedBox(height: 14),
                        ],

                        // ── 2. ASSIGNED REASON CARD (WHEN NOT SPLIT) ───────────────────────────
                        if (splits.isEmpty) ...[
                          _buildAssignedReasonCard(
                            context,
                            txVM,
                            cashVM,
                            loansVM,
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
                        ],

                        // ── 3. TRANSACTION DETAIL INFO CARD (ALWAYS EXPANDED) ───────────────────
                        _buildTransactionInfoCard(context, bankInfo, isIncome),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(0, 14, 0, 24 + MediaQuery.paddingOf(context).bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Collapsible Personal Note Section ──────────────────
                    _buildCollapsiblePersonalNoteCard(context, txVM),

                    const SizedBox(height: 14),

                    // ── Collapsible Raw Message Source Section ─────────────
                    _buildCollapsibleRawMessageCard(context),

                    if (widget.transaction.hasLinks) ...[
                      const SizedBox(height: 14),
                      // ── Collapsible Receipt Link Section ───────────────────
                      _buildCollapsibleReceiptLinkCard(context),
                    ],

                    if (!isReasonBlocked) ...[
                      const SizedBox(height: 14),
                      // ── Link Reason Feature Info Section ───────────────────
                      _buildLinkReasonInfoSection(context),
                    ],

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
      iconWidget = SvgPicture.asset('assets/images/CBEBirr_Logo.svg', width: 24, height: 24, fit: BoxFit.contain);
      bankName = 'CBE Birr Mobile Banking';
      shortName = 'CbeBirr';
      bg = AppColors.cbeBirrPink.withValues(alpha: 0.15);
    } else if (combined.contains('TELEBIRR')) {
      bg = AppColors.telebirrGreenSoft;
      iconWidget = SvgPicture.asset(
        'assets/images/Telebirr_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.telebirrGreen, BlendMode.srcIn),
      );
      bankName = 'Telebirr Digital Wallet';
      shortName = 'Telebirr';
    } else if (combined.contains('AHADU')) {
      bg = AppColors.cardAhaduRed.withValues(alpha: 0.15);
      iconWidget = AppSvgIcon('assets/images/Ahadu_Logo.svg', size: 24, surfaceColor: bg);
      bankName = 'Ahadu Bank';
      shortName = 'Ahadu';
    } else if (combined.contains('ABYSSINIA') || combined.contains('BOA')) {
      bg = AppColors.cardBoaBg.withValues(alpha: 0.18);
      iconWidget = AppSvgIcon('assets/images/Bank_of_Abyssinia_Icon.svg', size: 24, surfaceColor: bg);
      bankName = 'Bank of Abyssinia S.C.';
      shortName = 'BOA';
    } else if (combined.contains('DASHEN')) {
      bg = AppColors.cardDashenLight.withValues(alpha: 0.18);
      iconWidget = AppSvgIcon('assets/images/Dashen_Bank_Logo.svg', size: 24, surfaceColor: bg);
      bankName = 'Dashen Bank S.C.';
      shortName = 'Dashen';
    } else if (combined.contains('AWASH')) {
      bg = AppColors.cardAwashDark.withValues(alpha: 0.15);
      iconWidget = SvgPicture.asset(
        'assets/images/Awash_Bank_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
      bankName = 'Awash Bank S.C.';
      shortName = 'Awash';
    } else if (combined.contains('ZEMEN')) {
      bg = AppColors.cardZemenDark.withValues(alpha: 0.15);
      iconWidget = SvgPicture.asset(
        'assets/images/ZemenBank_Logo.svg',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      );
      bankName = 'Zemen Bank S.C.';
      shortName = 'Zemen';
    } else if (combined.contains('CBE') || combined.contains('COMMERCIAL BANK')) {
      bg = AppColors.slackPurple.withValues(alpha: 0.15);
      iconWidget = SvgPicture.asset('assets/images/CBE logo.svg', width: 24, height: 24, fit: BoxFit.contain);
      bankName = 'Commercial Bank of Ethiopia';
      shortName = 'CBE';
    } else if (combined.contains('CASH')) {
      bg = AppColors.positive.withValues(alpha: 0.15);
      iconWidget = const AppSvgIcon(
        'assets/images/Wallet Icon.svg',
        size: 22,
        color: AppColors.positive,
      );
      bankName = 'Cash Wallet';
      shortName = 'Cash';
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
    ({Widget icon, String name, String shortName, String subtitle, Color bgColor}) bankInfo,
    bool isIncome,
  ) {
    final String counterparty = widget.transaction.sender.isNotEmpty
        ? widget.transaction.sender
        : 'External Party';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
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
            isIncome ? 'From (Sender)' : 'To (Recipient)',
            _limitWords(
              CounterpartyMatcher.normalize(counterparty).isNotEmpty
                  ? CounterpartyMatcher.normalize(counterparty)
                  : counterparty,
              maxWords: 3,
            ),
            onTap: widget.transaction.sender.isNotEmpty &&
                    widget.transaction.sender != 'Manual Entry' &&
                    widget.transaction.sender != 'Cash'
                ? () {
                    CounterpartyInsightSheet.show(
                      context,
                      personName: widget.transaction.sender,
                    );
                  }
                : null,
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

  Widget _buildCashSpendingBreakdownCard(
      BuildContext context,
      CashWalletViewModel cashVM,
      SettingsViewModel settingsVM,
      TransactionsViewModel txVM) {
    if (widget.transaction.id == null) return const SizedBox.shrink();
    final spendings = cashVM.spendingsForTransaction(widget.transaction.id!);
    final totalSpent = cashVM.getCashWithdrawalSpentAmount(widget.transaction.id!);
    final remaining = cashVM.getCashWithdrawalRemainingAmount(widget.transaction.id!, widget.transaction.amount);
    final double progress = (totalSpent / widget.transaction.amount).clamp(0.0, 1.0);
    final fmtShort = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
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
                              await cashVM.deleteCashTransaction(s.id!);
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
                _showDeductCashFromWithdrawalModal(context, cashVM, settingsVM, txVM, widget.transaction);
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

  void _showDeductCashFromWithdrawalModal(
      BuildContext context,
      CashWalletViewModel cashVM,
      SettingsViewModel settingsVM,
      TransactionsViewModel txVM,
      AppTransaction bankTx) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final pendingAttachments = <TransactionAttachment>[];
    AppReason? selectedReason;
    final fmtShort = NumberFormat('#,##0.00');

    AppDrawer.show(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final remaining = cashVM.getCashWithdrawalRemainingAmount(bankTx.id!, bankTx.amount);
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
            headerCard: const AppDrawerHeaderCard(
              icon: Icons.money_off_rounded,
              title: 'Deduct Cash',
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

                      await cashVM.addCashTransaction(cashTx);
                      if (context.mounted) Navigator.pop(ctx);
                    },
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                AppTextField(
                  controller: amountController,
                  maxLength: 14,
                  label:
                      'AMOUNT (${settingsVM.currentCurrency.shortLabel})',
                  hint: '0.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.account_balance_wallet_outlined,
                  backgroundColor: AppColors.previewCardBg,
                  borderRadius: BorderRadius.circular(16),
                  style: TextStyle(
                    color: isExceeded ? AppColors.negative : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (_) => setModalState(() {}),
                ),
                if (isExceeded) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: AppBadge.destructive(
                      text:
                          'Exceeds remaining limit of ${fmtShort.format(remaining)} ${settingsVM.currentCurrency.shortLabel}',
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
                          : AppColors.drawerCard,
                      borderRadius: AppRadius.cardRadius,
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

  Widget _buildCollapsibleInfoRow(
    IconData icon,
    String label,
    String value, {
    Widget? customValue,
    String? tooltipText,
    VoidCallback? onTap,
  }) {
    final effectiveTooltip = tooltipText ?? (value.isNotEmpty ? value : null);

    Widget row = Padding(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                child: Text(
                                  value,
                                  style: TextStyle(
                                    color: onTap != null
                                        ? AppColors.brandGreen
                                        : Colors.white,
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
                                style: TextStyle(
                                  color: onTap != null
                                      ? AppColors.brandGreen
                                      : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.insights_rounded,
                      size: 13,
                      color: AppColors.brandGreen,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: row,
      );
    }
    return row;
  }

  IconData _getReasonCategoryIcon(String? label, [TransactionsViewModel? txVM]) {
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
        name.contains('restaurant') ||
        name.contains('cafe') ||
        name.contains('coffee') ||
        name.contains('dining') ||
        name.contains('grocer') ||
        name.contains('supermarket')) {
      return Icons.restaurant_rounded;
    }
    if (name.contains('goods') ||
        name.contains('shopping') ||
        name.contains('cloth') ||
        name.contains('store') ||
        name.contains('market') ||
        name.contains('electronics')) {
      return Icons.shopping_bag_outlined;
    }
    if (name.contains('transport') ||
        name.contains('fuel') ||
        name.contains('gas') ||
        name.contains('ride') ||
        name.contains('taxi') ||
        name.contains('bus') ||
        name.contains('flight') ||
        name.contains('travel') ||
        name.contains('car')) {
      return Icons.directions_bus_rounded;
    }
    if (name.contains('mobile') ||
        name.contains('airtime') ||
        name.contains('internet') ||
        name.contains('wifi') ||
        name.contains('data') ||
        name.contains('telecom') ||
        name.contains('phone')) {
      return Icons.phone_android_rounded;
    }
    if (name.contains('housing') ||
        name.contains('rent') ||
        name.contains('home') ||
        name.contains('apartment') ||
        name.contains('house')) {
      return Icons.home_rounded;
    }
    if (name.contains('medical') ||
        name.contains('health') ||
        name.contains('pharmacy') ||
        name.contains('hospital') ||
        name.contains('clinic') ||
        name.contains('doctor') ||
        name.contains('medicine') ||
        name.contains('gym') ||
        name.contains('fitness')) {
      return Icons.local_hospital_outlined;
    }
    if (name.contains('education') ||
        name.contains('school') ||
        name.contains('college') ||
        name.contains('university') ||
        name.contains('tuition') ||
        name.contains('course') ||
        name.contains('book')) {
      return Icons.school_outlined;
    }
    if (name.contains('entertainment') ||
        name.contains('movie') ||
        name.contains('cinema') ||
        name.contains('music') ||
        name.contains('game') ||
        name.contains('gaming')) {
      return Icons.movie_outlined;
    }
    if (name.contains('utility') ||
        name.contains('utilities') ||
        name.contains('bill') ||
        name.contains('electricity') ||
        name.contains('water') ||
        name.contains('power') ||
        name.contains('dstv') ||
        name.contains('tv')) {
      return Icons.bolt_rounded;
    }
    if (name.contains('salary') ||
        name.contains('payroll') ||
        name.contains('income') ||
        name.contains('wage') ||
        name.contains('freelance') ||
        name.contains('bonus')) {
      return Icons.account_balance_wallet_outlined;
    }
    if (name.contains('investment') ||
        name.contains('saving') ||
        name.contains('stock') ||
        name.contains('crypto') ||
        name.contains('shares') ||
        name.contains('interest')) {
      return Icons.trending_up_rounded;
    }
    if (name.contains('loan') ||
        name.contains('lend') ||
        name.contains('borrow') ||
        name.contains('debt') ||
        name.contains('credit')) {
      return Icons.handshake_outlined;
    }
    if (name.contains('pass-through') ||
        name.contains('pass through') ||
        name.contains('bounce') ||
        name.contains('reversal') ||
        name.contains('refund') ||
        name.contains('return')) {
      return Icons.undo_rounded;
    }
    if (name.contains('internal transfer') ||
        name.contains('transfer') ||
        name.contains('swap')) {
      return Icons.swap_horiz_rounded;
    }
    if (name.contains('cash') ||
        name.contains('atm') ||
        name.contains('withdraw')) {
      return Icons.payments_outlined;
    }

    if (txVM != null) {
      final reasonObj = txVM.reasons.where((r) => r.name.toLowerCase() == name).firstOrNull;
      if (reasonObj != null && reasonObj.isSubcategory && reasonObj.parentId != null) {
        final parent = txVM.reasons.where((r) => r.id == reasonObj.parentId).firstOrNull;
        if (parent != null && parent.name.toLowerCase() != name) {
          return _getReasonCategoryIcon(parent.name, null);
        }
      }
    }

    return Icons.category_outlined;
  }

  Widget _buildSplitBreakdownCard(
    BuildContext context,
    TransactionsViewModel txVM,
    SettingsViewModel settingsVM,
    AppTransaction currentTx,
    List<TransactionSplit> splits,
  ) {
    final currency = settingsVM.currentCurrency.shortLabel;
    final fmtShort = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
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
                  color: AppColors.brandGreen.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_split_rounded,
                    color: AppColors.brandGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Split Breakdown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${splits.length} categories itemized',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              AppBadge.success(
                text: '${fmtShort.format(currentTx.amount)} $currency',
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 10),
          ...splits.map((s) {
            final reasonLabel =
                s.reasonName ?? s.customReasonText ?? 'Category';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getReasonCategoryIcon(reasonLabel, txVM),
                    color: AppColors.brandGreen,
                    size: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reasonLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (s.note != null && s.note!.isNotEmpty)
                          Text(
                            s.note!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${currentTx.type == 'income' ? '+' : '-'}${fmtShort.format(s.amount)} $currency',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  text: 'Edit Splits',
                  icon: Icons.edit_rounded,
                  height: 40,
                  fontSize: 12,
                  onPressed: () {
                    SplitTransactionSheet.show(
                      context,
                      transaction: currentTx,
                      initialSplits: splits,
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              AppButton.softDestructive(
                text: 'Remove',
                icon: Icons.delete_outline_rounded,
                fullWidth: false,
                height: 40,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: () async {
                  await AppConfirmDialog.show(
                    context: context,
                    title: 'Remove Splits?',
                    message:
                        'This will revert this transaction back to a single category.',
                    confirmText: 'Remove',
                    isDestructive: true,
                    onConfirm: () async {
                      if (currentTx.id != null) {
                        await txVM.deleteTransactionSplits(currentTx.id!);
                        if (context.mounted) {
                          AppToast.info(context,
                              message: 'Transaction splits removed');
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedReasonCard(
    BuildContext context,
    TransactionsViewModel txVM,
    CashWalletViewModel cashVM,
    LoansViewModel loansVM,
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
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          onTap: isReasonBlocked
              ? () {
                  if (isAutoLocked) {
                    AppToast.warning(
                      context,
                      message: 'Reason is locked for this transaction',
                    );
                    return;
                  }
                  if (linkedLoan != null) {
                    AppToast.warning(
                      context,
                      message: 'To change reason, delete loan record first',
                    );
                    return;
                  }
                  if (isCashLocked) {
                    final spendings = cashVM.spendingsForTransaction(widget.transaction.id ?? '');
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
                            await cashVM.deleteCashTransaction(s.id!);
                          }
                        }
                        if (context.mounted) {
                          _showReasonPicker(context, txVM, loansVM);
                        }
                      },
                    );
                    return;
                  }
                }
              : () => _showReasonPicker(context, txVM, loansVM),
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
                          : _getReasonCategoryIcon(currentLabel, txVM),
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
                                ? 'Locked • System auto-categorized'
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
                if (!isReasonBlocked && !isSpecialReason) ...[
                  AppButton.secondary(
                    text: 'Split',
                    icon: Icons.call_split_rounded,
                    fullWidth: false,
                    height: 28,
                    fontSize: 11,
                    iconSize: 13,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    onPressed: () {
                      SplitTransactionSheet.show(
                        context,
                        transaction: widget.transaction,
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (!isReasonBlocked && activeReasonId != null && !isSpecialReason) ...[
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
                if (!isReasonBlocked)
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

  Widget _buildCollapsiblePersonalNoteCard(BuildContext context, TransactionsViewModel txVM) {
    return AppNoteCard(
      controller: _noteController,
      title: 'PERSONAL NOTE',
      hintText: 'Add a private note about this transaction...',
      attachments: widget.transaction.attachments,
      isCollapsible: true,
      initialExpanded: _isPersonalNoteExpanded,
      accentColor: AppColors.positive,
      onChanged: (_) => setState(() {}),
      onEditingComplete: () => _save(txVM),
      onAttachMedia: (filePath, fileType, fileName) async {
        await txVM.addAttachment(
          widget.transaction.id!,
          filePath,
          fileType,
          fileName: fileName,
        );
      },
      onDeleteAttachment: (att) {
        txVM.deleteAttachment(widget.transaction.id!, att.id);
      },
    );
  }

  Widget _buildCollapsibleRawMessageCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
      BuildContext context, LoanRecord loan, LoansViewModel loansVM, SettingsViewModel settingsVM) {
    final isLent = loan.loanType == 'lent';
    final accentColor =
        isLent ? AppColors.positive : AppColors.warning;
    final fmt = NumberFormat('#,##0.00');

    return GestureDetector(
      onLongPress: () => _showLoanOptionsSheet(context, loan, loansVM, settingsVM),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                    settingsVM.animateToTab(3);
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
      BuildContext context, LoanRecord loan, LoansViewModel loansVM, SettingsViewModel settingsVM) {
    AppDrawer.show(
      context: context,
      builder: (ctx) => AppDrawer(
        heightFactor: null,
        isBodyScrollable: false,
        headerCard: const AppDrawerHeaderCard(
          icon: Icons.handshake_outlined,
          title: 'Loan Options',
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppDrawerActionTile(
              icon: Icons.open_in_new_rounded,
              title: 'Open in Loan Manager',
              subtitle: 'View repayments & full schedule',
              onTap: () {
                Navigator.pop(ctx);
                settingsVM.animateToTab(3);
                Navigator.popUntil(context, (route) => route.isFirst);
              },
            ),
            AppDrawerActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Loan Record',
              subtitle: 'Deletes loan tracking & unlocks reason editing',
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
                  await loansVM.deleteLoan(loan.id!);
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
      BuildContext context, AppTransaction currentTx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
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
      BuildContext context, AppTransaction currentTx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInternalTransferCard(
      BuildContext context, TransactionsViewModel txVM, AppTransaction currentTx) {
    AppTransaction? linkedTx;
    if (currentTx.linkedTransactionId != null) {
      linkedTx = txVM.transactions
          .where((t) => t.id == currentTx.linkedTransactionId)
          .firstOrNull;
    }
    if (linkedTx == null && currentTx.bankReference != null && currentTx.bankReference!.isNotEmpty) {
      linkedTx = txVM.transactions
          .where((t) =>
              t.bankReference == currentTx.bankReference &&
              t.amount == currentTx.amount &&
              t.id != currentTx.id &&
              t.type != currentTx.type)
          .firstOrNull;
    }

    final bool isDualSim = linkedTx != null && currentTx.simSlot != linkedTx.simSlot;
    final String title = isDualSim ? 'Dual-SIM Internal Transfer' : 'Linked Internal Transfer';
    final String subtitle = isDualSim
        ? 'Transferred between SIM 1 & SIM 2'
        : 'Auto-paired matching transaction';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row (Title, Icon & Locked Badge - No Unlink Button) ──
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.sync_alt_rounded,
                    color: AppColors.brandGreen,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const AppBadge.warning(
                text: 'Locked',
                icon: Icons.lock_rounded,
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Linked Transaction Preview Tile ──
          if (linkedTx != null) ...[
            Material(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailScreen(transaction: linkedTx!),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                AppBadge(
                                  text: '${linkedTx.name} • SIM ${linkedTx.simSlot + 1}',
                                  size: AppBadgeSize.small,
                                  customBgColor: linkedTx.simSlot == 0
                                      ? AppColors.sim1BadgeBg
                                      : AppColors.sim2BadgeBg,
                                  customTextColor: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                if (linkedTx.type == 'income')
                                  const AppBadge.success(
                                    text: 'Inflow (+)',
                                    size: AppBadgeSize.small,
                                  )
                                else
                                  const AppBadge.destructive(
                                    text: 'Outflow (-)',
                                    size: AppBadgeSize.small,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              linkedTx.sender.isNotEmpty
                                  ? (linkedTx.type == 'income'
                                      ? 'From: ${linkedTx.sender}'
                                      : 'To: ${linkedTx.sender}')
                                  : 'Ref: ${linkedTx.bankReference ?? linkedTx.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('dd MMM yyyy • hh:mm a').format(linkedTx.date),
                              style: const TextStyle(
                                color: AppColors.textDisabled,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${linkedTx.type == 'income' ? '+' : '-'}${NumberFormat('#,##0.00').format(linkedTx.amount)} ETB',
                            style: TextStyle(
                              color: linkedTx.type == 'income'
                                  ? AppColors.positive
                                  : AppColors.negative,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                                size: 15,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linked reference: ${currentTx.bankReference ?? currentTx.linkedTransactionId}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
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
