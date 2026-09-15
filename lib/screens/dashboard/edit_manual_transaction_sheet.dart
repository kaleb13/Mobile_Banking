import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../models/transaction_attachment.dart';
import '../../models/reason.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_note_card.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/counterparty_selector_modal.dart';
import 'reason_selection_sheet.dart';

/// Drawer sheet allowing users to edit manual transactions (Cash Wallet or manual bank entries).
class EditManualTransactionSheet extends StatefulWidget {
  final AppTransaction transaction;
  final TransactionsViewModel txVM;
  final CashWalletViewModel? cashVM;

  const EditManualTransactionSheet({
    super.key,
    required this.transaction,
    required this.txVM,
    this.cashVM,
  });

  static Future<void> show({
    required BuildContext context,
    required AppTransaction transaction,
    required TransactionsViewModel txVM,
    CashWalletViewModel? cashVM,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (_) => EditManualTransactionSheet(
        transaction: transaction,
        txVM: txVM,
        cashVM: cashVM,
      ),
    );
  }

  @override
  State<EditManualTransactionSheet> createState() =>
      _EditManualTransactionSheetState();
}

class _EditManualTransactionSheetState
    extends State<EditManualTransactionSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final List<TransactionAttachment> _attachments;
  late String _type;
  String? _selectedCounterparty;
  AppReason? _selectedReason;
  late DateTime _selectedDate;
  bool _isSaving = false;

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy · hh:mm a');

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount > 0
          ? widget.transaction.amount.toStringAsFixed(2)
          : '',
    );
    _noteController =
        TextEditingController(text: widget.transaction.note ?? '');
    _attachments = List.from(widget.transaction.attachments);
    _type = widget.transaction.type;
    _selectedCounterparty = widget.transaction.counterparty;
    _selectedDate = widget.transaction.date;

    // Resolve initial reason
    if (widget.transaction.reasonId != null) {
      _selectedReason = widget.txVM.reasons
          .where((r) => r.id == widget.transaction.reasonId)
          .firstOrNull;
    }
    if (_selectedReason == null &&
        widget.transaction.resolvedReason != null) {
      _selectedReason = widget.txVM.reasons
          .where((r) =>
              r.name.toLowerCase() ==
              widget.transaction.resolvedReason!.toLowerCase())
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.brandGreen,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.brandGreen,
                surface: AppColors.surface,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == 'income';
    final amtVal = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final bool canSave = amtVal > 0 && !_isSaving;

    return AppDrawer(
      heightFactor: null,
      isBodyScrollable: true,
      headerCard: const AppDrawerHeaderCard(
        icon: Icons.edit_note_rounded,
        title: 'Edit Transaction',
      ),
      bottomAction: AppButton.primary(
        text: _isSaving ? 'Saving...' : 'Save Changes',
        height: 48,
        onPressed: canSave
            ? () async {
                setState(() => _isSaving = true);
                try {
                  final String? cleanNote = _noteController.text.trim().isEmpty
                      ? null
                      : _noteController.text.trim();

                  final String effectiveCounterparty =
                      _selectedCounterparty != null &&
                              _selectedCounterparty!.trim().isNotEmpty
                          ? _selectedCounterparty!.trim()
                          : (isIncome ? 'Cash Inflow' : 'Cash Outflow');

                  final updated = widget.transaction.copyWith(
                    amount: amtVal,
                    type: _type,
                    counterparty: effectiveCounterparty,
                    reasonId: _selectedReason?.id,
                    clearReasonId: _selectedReason == null,
                    categoryId: _selectedReason?.isSubcategory == true
                        ? _selectedReason?.parentId
                        : _selectedReason?.id,
                    clearCategoryId: _selectedReason == null,
                    subcategoryId: _selectedReason?.isSubcategory == true
                        ? _selectedReason?.id
                        : null,
                    clearSubcategoryId: _selectedReason?.isSubcategory != true,
                    reason: _selectedReason?.name,
                    clearReason: _selectedReason == null,
                    customReasonText: _selectedReason?.name,
                    clearCustomReason: _selectedReason == null,
                    date: _selectedDate,
                    note: cleanNote,
                    clearNote: cleanNote == null,
                    attachments: List.from(_attachments),
                  );

                  await widget.txVM.updateManualTransaction(updated);

                  if (widget.transaction.bankName.toLowerCase() ==
                      'cash wallet') {
                    widget.cashVM?.recalcBalance();
                  }

                  if (context.mounted) {
                    Navigator.pop(context);
                    AppToast.success(
                      context,
                      message: 'Transaction Updated',
                      subtitle:
                          '${amtVal.toStringAsFixed(2)} ETB · $effectiveCounterparty',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() => _isSaving = false);
                    AppToast.error(
                      context,
                      message: 'Failed to update transaction',
                      subtitle: e.toString(),
                    );
                  }
                }
              }
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Direction / Type Selector (Income vs Expense Pills)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _type = 'income';
                      if (_selectedCounterparty == 'Cash Expense' ||
                          _selectedCounterparty == 'Cash Outflow') {
                        _selectedCounterparty = 'Cash Inflow';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isIncome
                          ? AppColors.positive.withValues(alpha: 0.18)
                          : AppColors.buttonSecondary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call_received_rounded,
                          size: 16,
                          color: isIncome
                              ? AppColors.positive
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Income',
                          style: TextStyle(
                            color: isIncome
                                ? AppColors.positive
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _type = 'expense';
                      if (_selectedCounterparty == 'Cash Inflow') {
                        _selectedCounterparty = 'Cash Outflow';
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isIncome
                          ? AppColors.negative.withValues(alpha: 0.18)
                          : AppColors.buttonSecondary,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.call_made_rounded,
                          size: 16,
                          color: !isIncome
                              ? AppColors.negative
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Expense',
                          style: TextStyle(
                            color: !isIncome
                                ? AppColors.negative
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Amount Input
          AppTextField(
            controller: _amountController,
            maxLength: 14,
            label: 'AMOUNT (ETB)',
            hint: '0.00',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.account_balance_wallet_outlined,
            backgroundColor: AppColors.previewCardBg,
            borderRadius: AppRadius.cardRadius,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // 3. Counterparty Selection (Payer or Recipient)
          GestureDetector(
            onTap: () async {
              final picked = await CounterpartySelectorModal.show(
                context: context,
                existingCounterparties: widget.txVM.uniqueCounterparties,
                currentCounterparty: _selectedCounterparty,
                title: isIncome
                    ? 'Received From (Payer)'
                    : 'Paid To (Recipient)',
              );
              if (picked != null) {
                setState(() {
                  _selectedCounterparty = picked;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        Text(
                          isIncome
                              ? 'RECEIVED FROM (PAYER / SOURCE)'
                              : 'PAID TO (RECIPIENT)',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedCounterparty ??
                              (isIncome
                                  ? 'Select or enter payer...'
                                  : 'Select or enter recipient...'),
                          style: TextStyle(
                            color: _selectedCounterparty != null
                                ? AppColors.textPrimary
                                : AppColors.textSoft,
                            fontSize: 14,
                            fontWeight: _selectedCounterparty != null
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

          // 4. Reason / Category Selection
          GestureDetector(
            onTap: () {
              ReasonSelectionSheet.show(
                context,
                initialReason: _selectedReason,
                transactionType: _type,
                onReasonSelected: (reason) {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          _selectedReason?.name ??
                              'Select $_type category...',
                          style: TextStyle(
                            color: _selectedReason != null
                                ? AppColors.textPrimary
                                : AppColors.textSoft,
                            fontSize: 14,
                            fontWeight: _selectedReason != null
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

          // 5. Date & Time Selection
          GestureDetector(
            onTap: _pickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          'TRANSACTION DATE & TIME',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _dateFormat.format(_selectedDate),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_calendar_outlined,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 6. Personal Note & Attachment Card
          AppNoteCard(
            controller: _noteController,
            title: 'PERSONAL NOTE',
            hintText: 'Add a private note (optional)...',
            attachments: _attachments,
            isCollapsible: true,
            initialExpanded: _noteController.text.trim().isNotEmpty || _attachments.isNotEmpty,
            accentColor: isIncome ? AppColors.positive : AppColors.gold,
            backgroundColor: AppColors.previewCardBg,
            onAttachMedia: (filePath, fileType, fileName) async {
              setState(() {
                _attachments.add(
                  TransactionAttachment(
                    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                    transactionId: widget.transaction.id ?? 'manual_edit',
                    filePath: filePath,
                    fileType: fileType,
                    fileName: fileName,
                    createdAt: DateTime.now().toIso8601String(),
                  ),
                );
              });
            },
            onDeleteAttachment: (att) {
              setState(() {
                _attachments.removeWhere((a) => a.id == att.id);
              });
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
