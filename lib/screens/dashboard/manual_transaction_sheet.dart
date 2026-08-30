import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/sender.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/notifications_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_capsule_tab_bar.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/currency_symbol_widget.dart';
import 'reason_selection_sheet.dart';

class ManualTransactionSheet extends StatefulWidget {
  final AppNotification? notification;
  final TransactionsViewModel? txVM;
  final NotificationsViewModel? notifVM;
  final AppSender? initialSender;
  final VoidCallback? onClose;

  const ManualTransactionSheet({
    super.key,
    this.notification,
    this.txVM,
    this.notifVM,
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
    }

    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedSender == null) {
      final txVM = widget.txVM ?? Provider.of<TransactionsViewModel>(context, listen: false);
      if (widget.notification != null && txVM.senders.isNotEmpty) {
        _selectedSender = txVM.senders.firstWhere(
          (s) =>
              s.senderName
                  .toLowerCase()
                  .contains(widget.notification!.sender.toLowerCase()) ||
              widget.notification!.sender
                  .toLowerCase()
                  .contains(s.senderName.toLowerCase()),
          orElse: () => txVM.senders.first,
        );
      } else if (txVM.senders.isNotEmpty) {
        _selectedSender = txVM.senders.first;
      }
    }
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

    final txVM = widget.txVM ?? Provider.of<TransactionsViewModel>(context, listen: false);
    final notifVM = widget.notifVM ?? Provider.of<NotificationsViewModel>(context, listen: false);

    final double currentBankBalance =
        txVM.getLatestBalanceForBank(_selectedSender!.senderName);

    if (_type == 'expense' && (currentBankBalance <= 0 || amount > currentBankBalance)) {
      return;
    }

    setState(() => _isSaving = true);

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

    await txVM.addTransaction(tx);
    if (widget.notification != null) {
      await notifVM.deleteNotification(widget.notification!.id);
    }

    if (mounted) {
      _closeSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _type == 'income';
    final Color activeColor = isIncome ? AppColors.telebirrGreen : AppColors.negative;
    final txVM = widget.txVM ?? Provider.of<TransactionsViewModel>(context);
    final double currentBankBalance = _selectedSender != null
        ? txVM.getLatestBalanceForBank(_selectedSender!.senderName)
        : 0.0;
    final fmtShort = NumberFormat('#,##0.00');

    final enteredAmt = double.tryParse(_amountController.text.trim());
    String? limitError;
    if (!isIncome && _selectedSender != null) {
      if (currentBankBalance <= 0) {
        limitError =
            'No available balance in ${_selectedSender!.senderName} (0.00 ETB)';
      } else if (enteredAmt != null && enteredAmt > currentBankBalance) {
        limitError =
            'Exceeds available balance of ${fmtShort.format(currentBankBalance)} ETB';
      }
    }

    final bool isExceeded = limitError != null;
    final bool isAmtValid = enteredAmt != null && enteredAmt > 0;
    final bool canSave = isAmtValid && _selectedSender != null && !isExceeded;

    final String buttonText = (!isIncome && _selectedSender != null && currentBankBalance <= 0)
        ? 'Insufficient Balance'
        : (isExceeded
            ? 'Exceeds Available Balance'
            : 'Save Transaction');

    return AppDrawer(
      heightFactor: 0.88,
      headerCard: const AppDrawerHeaderCard(
        icon: Icons.add_circle_outline_rounded,
        title: 'Add Transaction',
      ),
      bottomAction: AppButton.primary(
        text: buttonText,
        isLoading: _isSaving,
        height: 48,
        onPressed: !canSave ? null : _save,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          // Income / Expense Primary Tab Bar
          AppPrimaryTabBar(
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
          AppTextField(
            controller: _amountController,
            maxLength: 14,
            label:
                'AMOUNT (${Provider.of<SettingsViewModel>(context, listen: false).currentCurrency.shortLabel})',
            hint: '0.00',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
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
            ),
            style: TextStyle(
              color: isExceeded ? AppColors.negative : AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (_) => setState(() {}),
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
          const SizedBox(height: 12),

          // Sender / Receiver Field Card
          AppTextField(
            controller: _receiverController,
            maxLength: 70,
            label: isIncome
                ? 'SENDER / SOURCE NAME'
                : 'RECIPIENT / MERCHANT NAME',
            prefixIcon: Icons.person_outline_rounded,
            hint: isIncome
                ? 'Sender / Source Name'
                : 'Recipient / Merchant Name',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Category / Reason Select Chip Card
          GestureDetector(
            onTap: _openReasonSelection,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.drawerCard,
                borderRadius: AppRadius.cardRadius,
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
