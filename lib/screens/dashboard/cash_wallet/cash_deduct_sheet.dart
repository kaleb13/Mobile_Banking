import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/cash_transaction.dart';
import '../../../models/expense_definition.dart';
import '../../../models/reason.dart';
import '../../../models/transaction.dart';
import '../../../models/transaction_attachment.dart';
import '../../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../../presentation/viewmodels/transactions_view_model.dart';
import '../../../presentation/viewmodels/settings_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_badges.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_note_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_toast.dart';
import '../reason_selection_sheet.dart';

/// Shows the unified cash expense deduction drawer with amount validation,
/// template selection, reason selection, optional note/receipt attachments,
/// and bank withdrawal linking.
void showCashDeductModal(
  BuildContext context, {
  CashWalletViewModel? cashViewModel,
  TransactionsViewModel? transactionsViewModel,
  SettingsViewModel? settingsViewModel,
}) {
  final cashVM = cashViewModel ?? context.read<CashWalletViewModel>();
  final txVM = transactionsViewModel ?? context.read<TransactionsViewModel>();
  final settingsVM = settingsViewModel ?? context.read<SettingsViewModel>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final pendingAttachments = <TransactionAttachment>[];
  AppReason? selectedReason;
  ExpenseDefinition? selectedTemplate;
  AppTransaction? selectedWithdrawal;
  bool isRecurring = false;
  final fmtShort = NumberFormat('#,##0.00');

  AppDrawer.show(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final double availableBal = selectedWithdrawal != null
              ? cashVM.getCashWithdrawalRemainingAmount(
                  selectedWithdrawal!.id!, selectedWithdrawal!.amount)
              : cashVM.cashBalance;

          final enteredAmt = double.tryParse(amountController.text.trim());
          String? limitError;
          if (availableBal <= 0) {
            limitError = selectedWithdrawal != null
                ? 'Selected withdrawal has 0.00 ETB remaining'
                : 'No available cash balance to deduct from (0.00 ETB)';
          } else if (enteredAmt != null && enteredAmt > 0) {
            if (enteredAmt > availableBal) {
              limitError =
                  'Exceeds available balance of ${fmtShort.format(availableBal)} ETB';
            }
          }

          final bool isExceeded = limitError != null;
          final bool isValid = enteredAmt != null &&
              enteredAmt > 0 &&
              !isExceeded &&
              availableBal > 0 &&
              enteredAmt <= availableBal &&
              selectedReason != null;
          final String buttonText = availableBal <= 0
              ? 'Insufficient Cash Balance'
              : (isExceeded
                  ? 'Exceeds Available Balance'
                  : (selectedReason == null
                      ? 'Select Reason to Record'
                      : (enteredAmt == null || enteredAmt <= 0
                          ? 'Enter Amount'
                          : 'Record Expense')));

          return AppDrawer(
            heightFactor: 0.88,
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
                      if (amt == null ||
                          amt <= 0 ||
                          selectedReason == null ||
                          availableBal <= 0 ||
                          amt > availableBal) {
                        return;
                      }

                      if (selectedWithdrawal != null) {
                        final rem = cashVM.getCashWithdrawalRemainingAmount(
                            selectedWithdrawal!.id!,
                            selectedWithdrawal!.amount);
                        if (amt > rem) return;
                      }

                      // Create the transaction
                      final tx = CashTransaction(
                        type: 'expense',
                        amount: amt,
                        date: DateTime.now(),
                        description: noteController.text.trim(),
                        reasonId: selectedReason?.id,
                        reasonName: selectedReason?.name,
                        expenseDefinitionId: selectedTemplate?.id,
                        linkedTransactionId: selectedWithdrawal?.id,
                      );

                      await cashVM.addCashTransaction(tx);

                      // If "Save as Template" is on, and no template selected, create it
                      if (isRecurring && selectedTemplate == null) {
                        final newDef = ExpenseDefinition(
                          name: selectedReason?.name ??
                              (noteController.text.trim().isNotEmpty
                                  ? noteController.text.trim()
                                  : 'New Template'),
                          defaultAmount: amt,
                          isRecurring: false,
                          reasonId: selectedReason?.id,
                        );
                        await cashVM.addExpenseDefinition(newDef);
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      AppToast.success(
                        context,
                        message: 'Expense Recorded: ${amt.toStringAsFixed(2)} ETB',
                        subtitle: selectedReason?.name ?? 'Cash expense',
                        details: 'Deducted ${amt.toStringAsFixed(2)} ETB from your cash wallet. Recorded under ${selectedReason?.name ?? "General Expense"}.',
                        metadata: {
                          'Wallet': 'Cash Wallet',
                          'Category': selectedReason?.name ?? 'General',
                          'Amount': '${amt.toStringAsFixed(2)} ETB',
                        },
                      );
                    },
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // Template Quick Selector
                if (cashVM.expenseDefinitions.isNotEmpty) ...[
                  const Text(
                    'Saved Templates',
                    style: TextStyle(color: AppColors.textSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cashVM.expenseDefinitions.length,
                      itemBuilder: (context, index) {
                        final def = cashVM.expenseDefinitions[index];
                        final isSelected = selectedTemplate?.id == def.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(def.name),
                            selected: isSelected,
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  selectedTemplate = def;
                                  amountController.text =
                                      def.defaultAmount.toStringAsFixed(0);
                                  if (def.reasonId != null) {
                                    selectedReason =
                                        txVM.reasons.firstWhere(
                                      (r) => r.id == def.reasonId,
                                      orElse: () => txVM.reasons.first,
                                    );
                                  }
                                } else {
                                  selectedTemplate = null;
                                }
                              });
                            },
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                            selectedColor:
                                AppColors.gold.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.gold
                                  : Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                AppTextField(
                  controller: amountController,
                  maxLength: 14,
                  label:
                      'AMOUNT (${settingsVM.currentCurrency.shortLabel})',
                  hint: '0.00',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                      text: limitError,
                      icon: Icons.error_outline_rounded,
                      size: AppBadgeSize.medium,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Reason Selector
                GestureDetector(
                  onTap: () {
                    AppBottomSheet.show(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => ReasonSelectionSheet(
                        initialReason: selectedReason,
                        transactionType: 'expense',
                        isCashSpending: true,
                        onReasonSelected: (r) {
                          setModalState(() => selectedReason = r);
                        },
                      ),
                    );
                  },
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedReason?.name ??
                                'Select Reason (Required)',
                            style: TextStyle(
                              color: selectedReason != null
                                  ? Colors.white
                                  : AppColors.gold,
                              fontSize: 14,
                              fontWeight: selectedReason != null
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSoft,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note & Receipt Card
                AppNoteCard(
                  controller: noteController,
                  title: 'NOTE & RECEIPT',
                  hintText: 'Short note (optional)...',
                  attachments: pendingAttachments,
                  isCollapsible: true,
                  initialExpanded: false,
                  accentColor: AppColors.gold,
                  onAttachMedia: (filePath, fileType, fileName) async {
                    setModalState(() {
                      pendingAttachments.add(
                        TransactionAttachment(
                          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                          transactionId:
                              selectedWithdrawal?.id ?? 'cash_expense',
                          filePath: filePath,
                          fileType: fileType,
                          fileName: fileName,
                          createdAt: DateTime.now().toIso8601String(),
                        ),
                      );
                    });
                  },
                  onDeleteAttachment: (att) {
                    setModalState(() {
                      pendingAttachments.removeWhere((a) => a.id == att.id);
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Bank Cash Withdrawal Linkage Selector
                if (txVM.activeBankCashWithdrawals.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: PopupMenuButton<AppTransaction?>(
                      initialValue: selectedWithdrawal,
                      onSelected: (tx) {
                        setModalState(() {
                          selectedWithdrawal = tx;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.cardRadius,
                      ),
                      color: AppColors.surface,
                      itemBuilder: (ctx) => [
                        const PopupMenuItem<AppTransaction?>(
                          value: null,
                          child: Text(
                            'General Cash Wallet (No specific withdrawal link)',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        ...txVM.activeBankCashWithdrawals.map((w) {
                          final rem = cashVM
                              .getCashWithdrawalRemainingAmount(
                                  w.id!, w.amount);
                          return PopupMenuItem<AppTransaction?>(
                            value: w,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${w.name} Withdrawal (${fmtShort.format(w.amount)} ETB)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${fmtShort.format(rem)} ETB remaining · ${DateFormat('MMM d').format(w.date)}',
                                  style: const TextStyle(
                                    color: AppColors.positive,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: AppColors.positive,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedWithdrawal != null
                                        ? '${selectedWithdrawal!.name} (${fmtShort.format(selectedWithdrawal!.amount)} ETB)'
                                        : 'Source Bank Withdrawal (Optional)',
                                    style: TextStyle(
                                      color: selectedWithdrawal != null
                                           ? Colors.white
                                           : AppColors.textSoft,
                                      fontSize: 13,
                                      fontWeight: selectedWithdrawal != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  if (selectedWithdrawal != null)
                                    Text(
                                      '${fmtShort.format(cashVM.getCashWithdrawalRemainingAmount(selectedWithdrawal!.id!, selectedWithdrawal!.amount))} ETB remaining',
                                      style: const TextStyle(
                                        color: AppColors.positive,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textSoft,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Recurring Toggle
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save as Template',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Easily reuse this amount and reason later',
                            style: TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSwitch(
                      value: isRecurring,
                      onChanged: (val) {
                        setModalState(() => isRecurring = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
