import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/app_notification.dart';
import '../../models/transaction.dart';
import '../../models/reason.dart';
import '../../models/sender.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

class ManualTransactionSheet extends StatefulWidget {
  final AppNotification? notification;
  final FinanceProvider provider;
  final AppSender? initialSender;

  const ManualTransactionSheet({
    super.key,
    this.notification,
    required this.provider,
    this.initialSender,
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
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.notification?.date ?? DateTime.now();
    _selectedSender = widget.initialSender;

    if (widget.notification != null) {
      // Try to extract amount from notification body
      final amountMatch = RegExp(r'(\d{1,3}(,\d{3})*(\.\d{1,2})?)')
          .firstMatch(widget.notification!.body);
      if (amountMatch != null) {
        _amountController.text =
            amountMatch.group(1)?.replaceAll(',', '') ?? '';
      }

      // Try to find matching sender
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

  Future<void> _save() async {
    if (_amountController.text.isEmpty) return;
    if (_selectedSender == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSaving = true);

    final tx = AppTransaction(
      name: _selectedSender!.senderName,
      amount: amount,
      type: _type,
      date: _selectedDate,
      sender: _receiverController.text.isEmpty
          ? 'Manual Entry'
          : _receiverController.text,
      category: _selectedReason?.name ?? 'Uncategorized',
      rawMessage: widget.notification?.body ?? 'Manual entry via UI',
      isAutoDetected: false,
      reasonId: _selectedReason?.id,
      reason: _selectedReason?.name,
    );

    await widget.provider.addTransaction(tx);
    if (widget.notification != null) {
      await widget.provider.deleteNotification(widget.notification!.id);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.labelGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Insert Transaction Manually',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.notification != null) ...[
              const SizedBox(height: 8),
              Text(
                'From: ${widget.notification!.sender}',
                style:
                    const TextStyle(color: AppColors.labelGray, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),

            // Type Selector
            Row(
              children: [
                _buildTypeButton('Expense', 'expense', AppColors.alertRed),
                const SizedBox(width: 12),
                _buildTypeButton('Income', 'income', const Color(0xFF3EB489)),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Field
            _buildField(
              label: 'Amount (ETB)',
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Enter amount…'),
              ),
            ),
            const SizedBox(height: 16),

            // Bank / Sender Field
            _buildField(
              label: 'Bank / System',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AppSender>(
                    value: _selectedSender,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceDark,
                    items: widget.provider.senders
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.senderName,
                                  style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedSender = val),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reason / Category Field
            _buildField(
              label: 'Reason / Category',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<AppReason>(
                    value: _selectedReason,
                    isExpanded: true,
                    dropdownColor: AppColors.surfaceDark,
                    hint: const Text('Select a reason…',
                        style: TextStyle(color: AppColors.labelGray)),
                    items: widget.provider.reasons
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.name,
                                  style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedReason = val),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Receiver / Reference Field
            _buildField(
              label: 'Sender / Receiver Name',
              child: TextField(
                controller: _receiverController,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Who sent/received this money?'),
              ),
            ),
            const SizedBox(height: 24),

            // Date Picker
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, yyyy').format(_selectedDate),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Spacer(),
                    const Text('Change',
                        style: TextStyle(
                            color: AppColors.primaryBlue, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isSaving ||
                        _amountController.text.isEmpty ||
                        _selectedSender == null)
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  disabledBackgroundColor:
                      AppColors.primaryBlue.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Save Transaction',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.labelGray,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.labelGray.withValues(alpha: 0.5)),
      filled: true,
      fillColor: AppColors.surfaceLight.withValues(alpha: 0.1),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildTypeButton(String label, String value, Color activeColor) {
    final isActive = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : AppColors.surfaceLight.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isActive
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.05)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : AppColors.labelGray,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primaryBlue,
            surface: AppColors.surfaceDark,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }
}
