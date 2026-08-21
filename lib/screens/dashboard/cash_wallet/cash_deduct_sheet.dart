import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/cash_transaction.dart';
import '../../../models/expense_definition.dart';
import '../../../models/reason.dart';
import '../../../models/transaction.dart';
import '../../../models/transaction_attachment.dart';
import '../../../providers/finance_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_badges.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_note_card.dart';
import '../../../widgets/app_switch.dart';
import '../../../widgets/app_text_field.dart';
import '../reason_selection_sheet.dart';

/// Shows the unified cash expense deduction drawer with amount validation,
/// template selection, reason selection, optional note/receipt attachments,
/// and bank withdrawal linking.
void showCashDeductModal(BuildContext context, FinanceProvider provider) {
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
          final enteredAmt = double.tryParse(amountController.text.trim());
          String? limitError;
          if (enteredAmt != null && enteredAmt > 0) {
            if (selectedWithdrawal != null) {
              final rem = provider.getCashWithdrawalRemainingAmount(
                  selectedWithdrawal!.id!, selectedWithdrawal!.amount);
              if (enteredAmt > rem) {
                limitError =
                    'Exceeds remaining withdrawal balance of ${fmtShort.format(rem)} ETB';
              }
            } else if (provider.cashBalance > 0 &&
                enteredAmt > provider.cashBalance) {
              limitError =
                  'Exceeds available cash balance of ${fmtShort.format(provider.cashBalance)} ETB';
            }
          }
          final bool isExceeded = limitError != null;
          final bool isValid = enteredAmt != null &&
              enteredAmt > 0 &&
              !isExceeded &&
              selectedReason != null;
          final String buttonText = isExceeded
              ? 'Exceeds Available Balance'
              : (selectedReason == null
                  ? 'Select Reason to Record'
                  : (enteredAmt == null || enteredAmt <= 0
                      ? 'Enter Amount'
                      : 'Record Expense'));

          return AppDrawer(
            heightFactor: 0.88,
            headerCard: AppDrawerHeaderCard(
              icon: Icons.money_off_rounded,
              iconColor: AppColors.positive,
              title: 'Deduct Cash Expense',
              subtitle:
                  'Available: ${fmtShort.format(provider.cashBalance)} ETB',
            ),
            bottomAction: AppButton.primary(
              text: buttonText,
              height: 48,
              onPressed: !isValid
                  ? null
                  : () async {
                      final amtStr = amountController.text.trim();
                      final amt = double.tryParse(amtStr);
                      if (amt == null || amt <= 0 || selectedReason == null) {
                        return;
                      }

                      if (selectedWithdrawal != null) {
                        final rem = provider.getCashWithdrawalRemainingAmount(
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

                      await provider.addCashTransaction(tx);

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
                        await provider.addExpenseDefinition(newDef);
                      }

                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                // Template Quick Selector
                if (provider.expenseDefinitions.isNotEmpty) ...[
                  const Text(
                    'Saved Templates',
                    style: TextStyle(color: AppColors.textSoft, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: provider.expenseDefinitions.length,
                      itemBuilder: (context, index) {
                        final def = provider.expenseDefinitions[index];
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
                                        provider.reasons.firstWhere(
                                      (r) => r.id == def.reasonId,
                                      orElse: () => provider.reasons.first,
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  variant: AppTextFieldVariant.modal,
                  backgroundColor: Colors.transparent,
                  style: TextStyle(
                    color: isExceeded ? AppColors.negative : Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  hint: '0.00',
                  hintColor: Colors.white.withValues(alpha: 0.1),
                  prefixText: provider.currentCurrency.shortLabel + ' ',
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
                if (provider.activeBankCashWithdrawals.isNotEmpty) ...[
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
                        ...provider.activeBankCashWithdrawals.map((w) {
                          final rem = provider
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
                                      '${fmtShort.format(provider.getCashWithdrawalRemainingAmount(selectedWithdrawal!.id!, selectedWithdrawal!.amount))} ETB remaining',
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
