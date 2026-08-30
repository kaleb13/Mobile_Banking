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
          title: title,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit Amount
            AppDrawerActionTile(
              icon: Icons.edit_rounded,
              title: 'Edit Amount',
              subtitle: 'Change the recorded amount',
              onTap: () {
                Navigator.pop(context);
                _showEditAmountDialog(context, viewModel, id, amount);
              },
            ),

            // Delete Transaction
            AppDrawerActionTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete Transaction',
              subtitle: 'Permanently remove this entry',
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
