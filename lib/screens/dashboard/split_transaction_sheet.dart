import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../models/transaction.dart';
import '../../models/transaction_split.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_confirm_dialog.dart';
import '../../widgets/custom_progress_bar.dart';
import 'reason_selection_sheet.dart';

class _SplitItemData {
  final TextEditingController amountController;
  final TextEditingController noteController;
  AppReason? selectedReason;
  int? categoryId;
  int? subcategoryId;
  String? reasonName;

  _SplitItemData({
    double? initialAmount,
    String? initialNote,
    this.selectedReason,
    this.categoryId,
    this.subcategoryId,
    this.reasonName,
  })  : amountController = TextEditingController(
          text: initialAmount != null && initialAmount > 0
              ? (initialAmount % 1 == 0
                  ? initialAmount.toInt().toString()
                  : initialAmount.toStringAsFixed(2))
              : '',
        ),
        noteController = TextEditingController(text: initialNote ?? '');

  void dispose() {
    amountController.dispose();
    noteController.dispose();
  }
}

/// Premium modal drawer to split a single transaction amount into multiple category allocations.
class SplitTransactionSheet extends StatefulWidget {
  final AppTransaction transaction;
  final List<TransactionSplit>? initialSplits;
  final void Function(List<TransactionSplit>)? onSplitsSaved;

  const SplitTransactionSheet({
    super.key,
    required this.transaction,
    this.initialSplits,
    this.onSplitsSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required AppTransaction transaction,
    List<TransactionSplit>? initialSplits,
    void Function(List<TransactionSplit>)? onSplitsSaved,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (ctx) => SplitTransactionSheet(
        transaction: transaction,
        initialSplits: initialSplits,
        onSplitsSaved: onSplitsSaved,
      ),
    );
  }

  @override
  State<SplitTransactionSheet> createState() => _SplitTransactionSheetState();
}

class _SplitTransactionSheetState extends State<SplitTransactionSheet> {
  final List<_SplitItemData> _items = [];
  bool _isSaving = false;
  final NumberFormat _fmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _initializeSplits();
  }

  void _initializeSplits() {
    final existing = widget.initialSplits;
    if (existing != null && existing.isNotEmpty) {
      for (final s in existing) {
        _items.add(_SplitItemData(
          initialAmount: s.amount,
          initialNote: s.note,
          reasonName: s.reasonName ?? s.customReasonText,
          categoryId: s.categoryId,
          subcategoryId: s.subcategoryId,
          selectedReason: s.reasonId != null
              ? AppReason(
                  id: s.reasonId,
                  name: s.reasonName ?? 'Category',
                  parentId: s.categoryId,
                )
              : null,
        ));
      }
    } else {
      // Default: Pre-populate Card 1 with the full transaction allocation & existing category/reason
      final currentReasonName = widget.transaction.resolvedReason ??
          widget.transaction.reason ??
          widget.transaction.customReasonText;
      _items.add(_SplitItemData(
        initialAmount: widget.transaction.amount,
        initialNote: widget.transaction.note,
        reasonName: currentReasonName,
        categoryId: widget.transaction.categoryId,
        subcategoryId: widget.transaction.subcategoryId,
        selectedReason: widget.transaction.reasonId != null
            ? AppReason(
                id: widget.transaction.reasonId,
                name: currentReasonName ?? 'Category',
                parentId: widget.transaction.categoryId,
              )
            : null,
      ));
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _totalTarget => widget.transaction.amount;

  double get _totalAllocated {
    double sum = 0.0;
    for (final item in _items) {
      final amt = double.tryParse(item.amountController.text.trim()) ?? 0.0;
      sum += amt;
    }
    return sum;
  }

  double get _remaining => _totalTarget - _totalAllocated;

  bool get _isBalanced => _remaining.abs() < 0.01;
  bool get _isOverAllocated => _remaining < -0.01;

  bool get _canSave {
    if (_items.isEmpty) return false;
    if (!_isBalanced) return false;
    for (final item in _items) {
      final amt = double.tryParse(item.amountController.text.trim());
      if (amt == null || amt <= 0) return false;
      if (item.selectedReason == null &&
          (item.reasonName == null || item.reasonName!.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  void _addNewSplitItem() {
    final remaining = _remaining;
    setState(() {
      _items.add(_SplitItemData(
        initialAmount: remaining > 0 ? remaining : null,
      ));
    });
  }

  void _removeSplitItem(int index) {
    if (_items.length <= 1) return;
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _selectCategoryForItem(_SplitItemData item) {
    ReasonSelectionSheet.show(
      context,
      initialReason: item.selectedReason,
      transactionType: widget.transaction.type,
      isSplitSelection: true,
      onReasonSelected: (reason) {
        setState(() {
          item.selectedReason = reason;
          item.reasonName = reason.name;
          if (reason.isSubcategory) {
            item.categoryId = reason.parentId;
            item.subcategoryId = reason.id;
          } else {
            item.categoryId = reason.id;
            item.subcategoryId = null;
          }
        });
      },
    );
  }

  Future<void> _saveSplits() async {
    if (!_canSave || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
      final List<TransactionSplit> splits = [];

      for (final item in _items) {
        final amt = double.tryParse(item.amountController.text.trim()) ?? 0.0;
        final rName = item.selectedReason?.name ?? item.reasonName;
        splits.add(TransactionSplit(
          transactionId: widget.transaction.id ?? '',
          amount: amt,
          reasonId: item.selectedReason?.id,
          reasonName: rName,
          categoryId: item.categoryId ?? item.selectedReason?.parentId,
          subcategoryId: item.subcategoryId,
          note: item.noteController.text.trim().isNotEmpty
              ? item.noteController.text.trim()
              : null,
        ));
      }

      if (widget.transaction.id != null && widget.transaction.id!.isNotEmpty) {
        await txVM.saveTransactionSplits(widget.transaction.id!, splits);
      }

      widget.onSplitsSaved?.call(splits);

      if (mounted) {
        AppToast.success(
          context,
          message: 'Transaction split into ${splits.length} categories',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving splits: $e');
      if (mounted) {
        AppToast.error(
          context,
          message: 'Failed to save splits: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSplits() async {
    final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
    await AppConfirmDialog.show(
      context: context,
      title: 'Remove Splits?',
      message: 'This will revert this transaction back to a single category.',
      confirmText: 'Remove',
      isDestructive: true,
      onConfirm: () async {
        if (widget.transaction.id != null && widget.transaction.id!.isNotEmpty) {
          await txVM.deleteTransactionSplits(widget.transaction.id!);
        }
        if (mounted) {
          AppToast.info(context, message: 'Transaction splits removed');
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final currency = settingsVM.currentCurrency.shortLabel;
    final allocated = _totalAllocated;
    final remaining = _remaining;
    final progress = (_totalTarget > 0 ? (allocated / _totalTarget) : 0.0).clamp(0.0, 1.0);

    String buttonLabel;
    if (_isOverAllocated) {
      buttonLabel = 'Exceeds by ${_fmt.format(-remaining)} $currency';
    } else if (!_isBalanced) {
      buttonLabel = 'Allocate Remaining ${_fmt.format(remaining)} $currency';
    } else {
      bool missingCat = _items.any((i) =>
          i.selectedReason == null &&
          (i.reasonName == null || i.reasonName!.isEmpty));
      bool missingAmt = _items.any((i) {
        final a = double.tryParse(i.amountController.text.trim());
        return a == null || a <= 0;
      });

      if (missingAmt) {
        buttonLabel = 'Enter Amount for All Items';
      } else if (missingCat) {
        buttonLabel = 'Select Category for All Items';
      } else {
        buttonLabel = 'Save Splits (${_items.length} Items)';
      }
    }

    return AppDrawer(
      heightFactor: 0.90,
      maxHeightFactor: 0.94,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.call_split_rounded,
        title: 'Split Transaction',
        subtitle: '${_fmt.format(_totalTarget)} $currency • ${widget.transaction.name}',
        trailing: widget.initialSplits != null && widget.initialSplits!.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.negative, size: 20),
                tooltip: 'Remove Splits',
                onPressed: _deleteSplits,
              )
            : null,
      ),
      bottomAction: AppButton.primary(
        text: buttonLabel,
        height: 50,
        isLoading: _isSaving,
        onPressed: _canSave && !_isSaving ? _saveSplits : null,
      ),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // ── Allocation Summary Progress Card ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total: ${_fmt.format(_totalTarget)} $currency',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_isBalanced)
                      const AppBadge.success(
                        text: '100% Balanced',
                        icon: Icons.check_circle_rounded,
                        size: AppBadgeSize.small,
                      )
                    else if (_isOverAllocated)
                      AppBadge.destructive(
                        text: 'Over by ${_fmt.format(-remaining)} $currency',
                        icon: Icons.warning_amber_rounded,
                        size: AppBadgeSize.small,
                      )
                    else
                      AppBadge.warning(
                        text: 'Remaining: ${_fmt.format(remaining)} $currency',
                        icon: Icons.pending_outlined,
                        size: AppBadgeSize.small,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomProgressBar(
                  progress: progress,
                  height: 8,
                  progressColor: _isBalanced
                      ? AppColors.positive
                      : (_isOverAllocated ? AppColors.negative : AppColors.brandGreen),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Allocated: ${_fmt.format(allocated)} $currency',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSoft,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Split Items List ─────────────────────────────────────────────
          ...List.generate(_items.length, (idx) {
            final item = _items[idx];
            final rName = item.selectedReason?.name ?? item.reasonName;
            final isCategorySelected = rName != null && rName.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: AppColors.tabBackground,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${idx + 1}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Split #${idx + 1}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (_items.length > 2)
                        GestureDetector(
                          onTap: () => _removeSplitItem(idx),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.textSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Amount TextField
                  AppTextField(
                    controller: item.amountController,
                    label: 'AMOUNT ($currency)',
                    hint: '0.00',
                    maxLength: 12,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    prefixIcon: Icons.account_balance_wallet_outlined,
                    backgroundColor: AppColors.tabBackground,
                    borderRadius: BorderRadius.circular(14),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 10),

                  // Category Selector Button (Pill)
                  GestureDetector(
                    onTap: () => _selectCategoryForItem(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.tabBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCategorySelected
                                ? Icons.label_rounded
                                : Icons.add_circle_outline_rounded,
                            size: 18,
                            color: isCategorySelected
                                ? AppColors.brandGreen
                                : AppColors.textSoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isCategorySelected ? rName : 'Select Category',
                              style: AppTypography.bodyMedium.copyWith(
                                color: isCategorySelected
                                    ? AppColors.textPrimary
                                    : AppColors.textSoft,
                                fontWeight: isCategorySelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AppColors.textSoft,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Note TextField
                  AppTextField(
                    controller: item.noteController,
                    label: 'NOTE (OPTIONAL)',
                    hint: 'e.g. Food, Airtime, Transport',
                    maxLength: 60,
                    prefixIcon: Icons.edit_note_rounded,
                    backgroundColor: AppColors.tabBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ],
              ),
            );
          }),

          // ── Add Item Pill Button ─────────────────────────────────────────
          const SizedBox(height: 4),
          Center(
            child: AppButton.secondary(
              text: '+ Add Another Split',
              icon: Icons.add_rounded,
              height: 44,
              onPressed: _addNewSplitItem,
            ),
          ),
        ],
      ),
    );
  }
}
