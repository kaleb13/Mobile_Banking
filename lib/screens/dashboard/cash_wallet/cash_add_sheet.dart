import 'package:flutter/material.dart';
import '../../../models/cash_transaction.dart';
import '../../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/app_toast.dart';

/// Shows the manual cash addition drawer.
void showAddCashModal(BuildContext context, CashWalletViewModel viewModel) {
  final amountController = TextEditingController();
  final noteController = TextEditingController();

  AppDrawer.show(
    context: context,
    builder: (context) {
      return AppDrawer(
        heightFactor: null,
        isBodyScrollable: false,
        headerCard: const AppDrawerHeaderCard(
          icon: Icons.add_circle_outline_rounded,
          iconColor: AppColors.positive,
          title: 'Add Cash',
          subtitle: 'Manually add funds to your cash wallet',
        ),
        bottomAction: AppButton.primary(
          text: 'Add to Balance',
          height: 48,
          onPressed: () {
            final amtStr = amountController.text.trim();
            final amt = double.tryParse(amtStr);
            if (amt != null && amt > 0) {
              viewModel.addCashTransaction(
                CashTransaction(
                  type: 'addition',
                  amount: amt,
                  date: DateTime.now(),
                  description: noteController.text.trim().isEmpty
                      ? 'Manual Add'
                      : noteController.text.trim(),
                ),
              );
              Navigator.pop(context);
              AppToast.success(
                context,
                message: 'Cash Added: ${amt.toStringAsFixed(2)} ETB',
                subtitle: 'Funds added to Cash Wallet',
                details: 'Added ${amt.toStringAsFixed(2)} ETB to your physical cash wallet. Your total cash balance has been updated.',
                metadata: {
                  'Wallet': 'Cash Wallet',
                  'Amount': '${amt.toStringAsFixed(2)} ETB',
                },
              );
            }
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: amountController,
              maxLength: 14,
              label: 'AMOUNT (ETB)',
              hint: '0.00',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: Icons.account_balance_wallet_outlined,
              backgroundColor: AppColors.previewCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: noteController,
              maxLength: 150,
              showCounter: true,
              label: 'SOURCE / NOTE (OPTIONAL)',
              prefixIcon: Icons.notes,
              hint: 'e.g. ATM withdrawal, Pocket cash',
              backgroundColor: AppColors.previewCardBg,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      );
    },
  );
}
