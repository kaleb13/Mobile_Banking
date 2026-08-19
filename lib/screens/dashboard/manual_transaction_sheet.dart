import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/currency_symbol_widget.dart';
import 'reason_selection_sheet.dart';

class ManualTransactionSheet extends StatefulWidget {
  final AppNotification? notification;
  final FinanceProvider provider;
  final AppSender? initialSender;
  final VoidCallback? onClose;

  const ManualTransactionSheet({
    super.key,
    this.notification,
    required this.provider,
    this.initialSender,
    this.onClose,
  });

  @override
  State<ManualTransactionSheet> createState() => _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<ManualTransactionSheet> {
  final _amountController = TextEditingController();
  final _receiverController = TextEditingController();
  AppSender? _selectedSender;
  AppReason? _selectedReason;
  String _type = 'expense'; // 'income' or 'expense'
  late final DateTime _fixedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fixedDate = widget.notification?.date ?? DateTime.now();
    _selectedSender = widget.initialSender;

    if (widget.notification != null) {
      final body = widget.notification!.body;
      final lowerBody = body.toLowerCase();
      if (lowerBody.contains('received') || lowerBody.contains('credited') || lowerBody.contains('deposit')) {
        _type = 'income';
      } else {
        _type = 'expense';
      }

      final amountMatch = RegExp(r'(\d{1,3}(,\d{3})*(\.\d{1,2})?)').firstMatch(body);
      if (amountMatch != null) {
        _amountController.text = amountMatch.group(1)?.replaceAll(',', '') ?? '';
      }

      if (widget.provider.senders.isNotEmpty && _selectedSender == null) {
        _selectedSender = widget.provider.senders.firstWhere(
          (s) =>
              s.senderName
                  .toLowerCase()
                  .contains(widget.notification!.sender.toLowerCase()) ||
              widget.notification!.sender
                  .toLowerCase()
                  .contains(s.senderName.toLowerCase()),
          orElse: () => widget.provider.senders.first,
        );
      }
    }

    if (_selectedSender == null && widget.provider.senders.isNotEmpty) {
      _selectedSender = widget.provider.senders.first;
    }

    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _receiverController.dispose();
    super.dispose();
  }

  void _closeSheet() {
    if (widget.onClose != null) {
      widget.onClose!();
    } else {
      Navigator.pop(context);
    }
  }

  void _openReasonSelection() {
    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => ReasonSelectionSheet(
        initialReason: _selectedReason,
        transactionType: _type,
        onReasonSelected: (reason) {
          setState(() {
            _selectedReason = reason;
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_amountController.text.isEmpty) return;
    if (_selectedSender == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    final double currentBankBalance =
        widget.provider.getLatestBalanceForBank(_selectedSender!.senderName);
    final double calculatedPostBalance = _type == 'income'
        ? (currentBankBalance + amount)
        : (currentBankBalance - amount);

    final tx = AppTransaction(
      name: _selectedSender!.senderName,
      amount: amount,
      type: _type,
      date: _fixedDate,
      sender: _receiverController.text.trim().isEmpty
          ? (widget.notification?.sender ?? 'Manual Entry')
          : _receiverController.text.trim(),
      category: _selectedReason?.name ?? 'Uncategorized',
      rawMessage: widget.notification?.body ?? 'Manual entry via UI',
      isAutoDetected: false,
      reasonId: _selectedReason?.id,
      reason: _selectedReason?.name,
      totalBalance: calculatedPostBalance > 0 ? calculatedPostBalance : 0.0,
    );

    await widget.provider.addTransaction(tx);
    if (widget.notification != null) {
      await widget.provider.deleteNotification(widget.notification!.id);
    }

    if (mounted) {
      _closeSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == 'income';
    final Color activeColor = isIncome ? AppColors.telebirrGreen : AppColors.negative;

    return AppDrawer(
      heightFactor: 0.88,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.add_circle_outline_rounded,
        iconColor: AppColors.positive,
        title: 'Insert Transaction',
        subtitle: '${_selectedSender?.senderName ?? "Wallet"} · ${DateFormat("MMM d, HH:mm").format(_fixedDate)}',
      ),
      bottomAction: AppButton.primary(
        text: 'Save Transaction',
        isLoading: _isSaving,
        height: 48,
        onPressed: (_amountController.text.isEmpty || _selectedSender == null)
            ? null
            : _save,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // Income / Expense Capsule Tab Bar
          AppCapsuleTabBar(
            tabs: const ['Expense', 'Income'],
            selectedIndex: _type == 'expense' ? 0 : 1,
            onTabChanged: (index) {
              setState(() {
                _type = index == 0 ? 'expense' : 'income';
              });
            },
          ),
          const SizedBox(height: 16),

          // Amount Field Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isIncome ? '+ ' : '- ',
                      style: TextStyle(
                        color: activeColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    CurrencySymbolWidget(
                      size: 16,
                      color: activeColor,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sender / Receiver Field Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _receiverController,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: isIncome ? 'Sender / Source Name' : 'Recipient / Merchant Name',
                      hintStyle: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category / Reason Select Chip Card
          GestureDetector(
            onTap: _openReasonSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedReason != null
                        ? Icons.category_rounded
                        : Icons.sell_outlined,
                    size: 18,
                    color: _selectedReason != null
                        ? AppColors.gold
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reason / Category',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedReason?.name ?? 'Select Reason / Category...',
                          style: TextStyle(
                            color: _selectedReason != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13.5,
                            fontWeight: _selectedReason != null
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedReason != null)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        setState(() {
                          _selectedReason = null;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 18),
                      ),
                    ),
                  const Icon(Icons.keyboard_arrow_right_rounded,
                      color: AppColors.textSecondary, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
