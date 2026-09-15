import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/reason.dart';
import '../../../models/transaction.dart';
import '../../../models/transaction_attachment.dart';
import '../../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../../presentation/viewmodels/transactions_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_note_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/counterparty_selector_modal.dart';
import '../reason_selection_sheet.dart';

/// Shows the manual cash addition drawer.
void showAddCashModal(
  BuildContext context,
  CashWalletViewModel viewModel, {
  TransactionsViewModel? transactionsViewModel,
}) {
  final txVM = transactionsViewModel ?? context.read<TransactionsViewModel>();
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final pendingAttachments = <TransactionAttachment>[];
  String? selectedCounterparty;
  AppReason? selectedReason;
  DateTime selectedDate = DateTime.now();
  bool isSaving = false;

  AppDrawer.show(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final amtStr = amountController.text.trim();
          final amt = double.tryParse(amtStr);
          final bool isValid = amt != null && amt > 0;

          return AppDrawer(
            heightFactor: 0.88,
            headerCard: const AppDrawerHeaderCard(
              icon: Icons.add_circle_outline_rounded,
              title: 'Add Cash',
            ),
            bottomAction: AppButton.primary(
              text: 'Add to Balance',
              isLoading: isSaving,
              height: 48,
              onPressed: !isValid
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      try {
                        final currentBal = viewModel.cashBalance;
                        final newBal = currentBal + amt;

                        final tx = AppTransaction(
                          id: AppTransaction.generateManualId('SHIBRE_CASH'),
                          bankName: 'Cash Wallet',
                          amount: amt,
                          type: 'income',
                          date: selectedDate,
                          counterparty: selectedCounterparty != null &&
                                  selectedCounterparty!.trim().isNotEmpty
                              ? selectedCounterparty!.trim()
                              : 'Cash Inflow',
                          sourceTag: 'Manual',
                          rawMessage: '',
                          isAutoDetected: false,
                          totalBalance: newBal,
                          reasonId: selectedReason?.id,
                          reason: selectedReason?.name,
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                          attachments: List.from(pendingAttachments),
                        );

                        await txVM.addTransaction(tx);
                        viewModel.recalcBalance();

                        if (context.mounted) {
                          Navigator.pop(context);
                          AppToast.success(
                            context,
                            message: 'Cash Added: ${amt.toStringAsFixed(2)} ETB',
                            subtitle: 'Funds added to Cash Wallet',
                            details:
                                'Added ${amt.toStringAsFixed(2)} ETB to your physical cash wallet. Your total cash balance has been updated.',
                            metadata: {
                              'Wallet': 'Cash Wallet',
                              'Amount': '${amt.toStringAsFixed(2)} ETB',
                              if (selectedCounterparty != null)
                                'Payer': selectedCounterparty!,
                              if (selectedReason != null)
                                'Reason': selectedReason!.name,
                            },
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (context.mounted) {
                          AppToast.error(context,
                              message: 'Failed to add cash: $e');
                        }
                      }
                    },
            ),
            child: ListView(
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Amount Field
                AppTextField(
                  controller: amountController,
                  maxLength: 14,
                  label: 'AMOUNT (ETB)',
                  hint: '0.00',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefixIcon: Icons.account_balance_wallet_outlined,
                  backgroundColor: AppColors.previewCardBg,
                  borderRadius: AppRadius.cardRadius,
                  onChanged: (_) => setModalState(() {}),
                ),
                const SizedBox(height: 14),

                // 2. Counterparty Selection (Payer / Source)
                GestureDetector(
                  onTap: () async {
                    final picked = await CounterpartySelectorModal.show(
                      context: context,
                      existingCounterparties: txVM.uniqueCounterparties,
                      currentCounterparty: selectedCounterparty,
                      title: 'Received From (Payer)',
                    );
                    if (picked != null) {
                      setModalState(() {
                        selectedCounterparty = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.previewCardBg,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RECEIVED FROM (PAYER / SOURCE)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedCounterparty ??
                                    'Select or enter payer...',
                                style: TextStyle(
                                  color: selectedCounterparty != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSoft,
                                  fontSize: 14,
                                  fontWeight: selectedCounterparty != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_right_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Reason Selection (Income category)
                GestureDetector(
                  onTap: () {
                    ReasonSelectionSheet.show(
                      context,
                      initialReason: selectedReason,
                      transactionType: 'income',
                      onReasonSelected: (reason) {
                        setModalState(() {
                          selectedReason = reason;
                        });
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.previewCardBg,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined,
                            color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'REASON / CATEGORY (OPTIONAL)',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedReason?.name ??
                                    'Select income category...',
                                style: TextStyle(
                                  color: selectedReason != null
                                      ? AppColors.textPrimary
                                      : AppColors.textSoft,
                                  fontSize: 14,
                                  fontWeight: selectedReason != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_right_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Date & Time Tile
                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (pickedDate != null && context.mounted) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (pickedTime != null) {
                        setModalState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.previewCardBg,
                      borderRadius: AppRadius.cardRadius,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.textSecondary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DATE & TIME',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy • HH:mm')
                                    .format(selectedDate),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 5. Personal Note & Attachment Card
                AppNoteCard(
                  controller: noteController,
                  title: 'PERSONAL NOTE',
                  hintText: 'e.g. Sold old bicycle, pocket cash (optional)...',
                  attachments: pendingAttachments,
                  isCollapsible: true,
                  initialExpanded: false,
                  accentColor: AppColors.positive,
                  backgroundColor: AppColors.previewCardBg,
                  onAttachMedia: (filePath, fileType, fileName) async {
                    setModalState(() {
                      pendingAttachments.add(
                        TransactionAttachment(
                          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                          transactionId: 'cash_inflow',
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
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}
