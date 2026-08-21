import 'package:flutter/material.dart';
import '../../../models/cash_transaction.dart';
import '../../../providers/finance_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_drawer.dart';
import '../../../widgets/app_text_field.dart';

/// Shows the manual cash addition drawer.
void showAddCashModal(BuildContext context, FinanceProvider provider) {
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
              provider.addCashTransaction(
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
            }
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              variant: AppTextFieldVariant.modal,
              backgroundColor: Colors.transparent,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              hint: '0.00',
              hintColor: Colors.white.withValues(alpha: 0.1),
              prefixText: 'ETB ',
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: noteController,
              label: 'Source / Note (Optional)',
              prefixIcon: Icons.notes,
              backgroundColor: AppColors.drawerCard,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
      );
    },
  );
}
