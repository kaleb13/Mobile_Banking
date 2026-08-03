import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_capsule_tab_bar.dart';

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
  bool _isSelectingReason = false;

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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isIncome = _type == 'income';
    final Color activeColor = isIncome ? AppColors.telebirrGreen : AppColors.negative;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.tabBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Title & Close Row
                Row(
                  children: [
                    const Text(
                      'Insert Transaction',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _closeSheet,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary, size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Auto-Selected Bank & Fixed Date Badges
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.telebirrGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.telebirrGreen.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              size: 13, color: AppColors.telebirrGreen),
                          const SizedBox(width: 5),
                          Text(
                            _selectedSender?.senderName ?? 'Auto-Selected',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('MMM d · HH:mm').format(_fixedDate),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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

                // Amount Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        isIncome ? '+ ETB' : '- ETB',
                        style: TextStyle(
                          color: activeColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

                // Sender / Receiver Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
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

                // Category / Reason Select Chip
                GestureDetector(
                  onTap: () => setState(() => _isSelectingReason = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
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
                        const Icon(Icons.keyboard_arrow_right_rounded,
                            color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Action Button (Unclipped, clean padding & FittedBox)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_isSaving ||
                            _amountController.text.isEmpty ||
                            _selectedSender == null)
                        ? null
                        : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      disabledBackgroundColor: activeColor.withValues(alpha: 0.3),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.textPrimary, strokeWidth: 2),
                          )
                        : const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Save Transaction',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Inline Reason Selector Overlay View
          if (_isSelectingReason)
            Positioned.fill(
              child: Container(
                color: AppColors.tabBackground,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _isSelectingReason = false),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.textPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Category / Reason',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedReason != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedReason = null;
                              _isSelectingReason = false;
                            }),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: AppColors.negative,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: widget.provider.reasons.isEmpty
                          ? const Center(
                              child: Text(
                                'No categories defined yet',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: widget.provider.reasons.length,
                              separatorBuilder: (context, index) => const Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                              itemBuilder: (context, index) {
                                final reason = widget.provider.reasons[index];
                                final isSelected = _selectedReason?.id == reason.id;

                                return ListTile(
                                  onTap: () {
                                    setState(() {
                                      _selectedReason = reason;
                                      _isSelectingReason = false;
                                    });
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  title: Text(
                                    reason.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.gold
                                          : AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check_circle_rounded,
                                          color: AppColors.gold, size: 20)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
