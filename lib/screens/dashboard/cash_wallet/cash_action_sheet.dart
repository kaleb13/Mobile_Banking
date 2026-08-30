import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/cash_transaction.dart';
import '../../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_confirm_dialog.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_modal_dialog.dart';
import '../../../widgets/app_text_field.dart';

/// Shows the long-press actions drawer for an existing cash transaction
/// (Edit Amount and Delete Transaction).
void showCashTransactionActions(
  BuildContext context,
  CashWalletViewModel viewModel,
  int id,
  double amount,
  String title,
) {
  AppDrawer.show(
    context: context,
    builder: (_) {
      return AppDrawer(
        heightFactor: null,
        isBodyScrollable: false,
        headerCard: AppDrawerHeaderCard(
          icon: Icons.receipt_long_rounded,
          iconColor: AppColors.gold,
          title: title,
          subtitle: 'ETB ${NumberFormat("#,##0.00").format(amount)}',
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit Amount
            _actionTile(
              icon: Icons.edit_rounded,
              iconColor: AppColors.gold,
              label: 'Edit Amount',
              sublabel: 'Change the recorded amount',
              onTap: () {
                Navigator.pop(context);
                _showEditAmountDialog(context, viewModel, id, amount);
              },
            ),
            const SizedBox(height: 10),

            // Delete Transaction
            _actionTile(
              icon: Icons.delete_rounded,
              iconColor: AppColors.negative,
              label: 'Delete Transaction',
              sublabel: 'Permanently remove this entry',
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, viewModel, id, title);
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _actionTile({
  required IconData icon,
  required Color iconColor,
  required String label,
  required String sublabel,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: AppRadius.cardRadiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadius.cardRadiusSm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
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
  );
}

void _showEditAmountDialog(
  BuildContext context,
  CashWalletViewModel viewModel,
  int id,
  double oldAmount,
) {
  final controller =
      TextEditingController(text: oldAmount.toStringAsFixed(0));
  final tx = viewModel.cashTransactions.cast<CashTransaction?>().firstWhere(
        (t) => t?.id == id,
        orElse: () => null,
      );

  AppModalDialog.show(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setDialogState) {
        final amt = double.tryParse(controller.text.trim());
        String? error;
        if (tx != null && tx.type == 'expense') {
          final maxAllowed = viewModel.cashBalance + oldAmount;
          if (amt != null && amt > maxAllowed) {
            error = 'Exceeds available balance (${NumberFormat("#,##0.00").format(maxAllowed)} ETB)';
          }
        }

        return AppModalDialog(
          title: 'Edit Amount',
          subtitle: 'Enter the updated cash amount in ETB',
          confirmText: 'Save',
          cancelText: 'Cancel',
          onConfirm: () {
            if (amt != null && amt > 0 && error == null) {
              viewModel.updateCashTransactionAmount(id, amt);
              Navigator.pop(c);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField.modal(
                controller: controller,
                maxLength: 14,
                label: 'AMOUNT (ETB)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                hint: '0.00',
                prefixIcon: Icons.account_balance_wallet_outlined,
                onChanged: (_) => setDialogState(() {}),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                Text(
                  error,
                  style: const TextStyle(color: AppColors.negative, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

void _confirmDelete(
  BuildContext context,
  CashWalletViewModel viewModel,
  int id,
  String title,
) {
  AppConfirmDialog.show(
    context: context,
    title: 'Delete Transaction',
    icon: Icons.delete_outline_rounded,
    iconColor: AppColors.negative,
    message: 'Remove "$title" permanently? This cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
    isDestructive: true,
    onConfirm: () {
      viewModel.deleteCashTransaction(id);
    },
  );
}
