import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../providers/finance_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_confirm_dialog.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_modal_dialog.dart';
import '../../../widgets/app_text_field.dart';

/// Shows the long-press actions drawer for an existing cash transaction
/// (Edit Amount and Delete Transaction).
void showCashTransactionActions(
  BuildContext context,
  FinanceProvider provider,
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
                _showEditAmountDialog(context, provider, id, amount);
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
                _confirmDelete(context, provider, id, title);
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
  return InkWell(
    onTap: onTap,
    borderRadius: AppRadius.cardRadius,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textSoft,
            size: 18,
          ),
        ],
      ),
    ),
  );
}

void _showEditAmountDialog(
  BuildContext context,
  FinanceProvider provider,
  int id,
  double oldAmount,
) {
  final controller =
      TextEditingController(text: oldAmount.toStringAsFixed(0));
  AppModalDialog.show(
    context: context,
    builder: (c) => AppModalDialog(
      title: 'Edit Amount',
      subtitle: 'Enter the updated cash amount in ETB',
      confirmText: 'Save',
      cancelText: 'Cancel',
      onConfirm: () {
        final amt = double.tryParse(controller.text.trim());
        if (amt != null && amt > 0) {
          provider.updateCashTransactionAmount(id, amt);
          Navigator.pop(c);
        }
      },
      child: AppTextField.modal(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        autofocus: true,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        hint: '0.00',
        prefixText: 'ETB ',
        borderRadius: AppRadius.cardRadiusSm,
      ),
    ),
  );
}

void _confirmDelete(
  BuildContext context,
  FinanceProvider provider,
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
      provider.deleteCashTransaction(id);
    },
  );
}
