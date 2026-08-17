import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_toast.dart';

class InternalTransferPickerSheet extends StatelessWidget {
  final AppTransaction sourceTransaction;
  final FinanceProvider provider;

  const InternalTransferPickerSheet({
    super.key,
    required this.sourceTransaction,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the opposite type
    final targetType =
        sourceTransaction.type == 'income' ? 'expense' : 'income';

    // Find candidates within 3 days and unlinked
    final cutoffDate = sourceTransaction.date.subtract(const Duration(days: 3));
    final futureDate = sourceTransaction.date.add(const Duration(days: 3));

    final candidates = provider.transactions.where((tx) {
      if (tx.id == sourceTransaction.id) return false;
      if (tx.type != targetType) return false;
      if (tx.linkedTransactionId != null) return false;
      if (tx.date.isBefore(cutoffDate) || tx.date.isAfter(futureDate)) {
        return false;
      }
      return true;
    }).toList();

    return AppDrawer(
      heightFactor: 0.85,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.sync_alt_rounded,
        iconColor: AppColors.gold,
        title: 'Select Linked Transaction',
        subtitle:
            'Match with $targetType within 3 days to link this transfer.',
      ),
      child: candidates.isEmpty
          ? const Center(
              child: Text(
                'No matching transactions found within 3 days.',
                style: TextStyle(color: AppColors.textSoft, fontSize: 13),
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: candidates.length,
              itemBuilder: (ctx, i) {
                final tx = candidates[i];
                final isExactMatch = tx.amount == sourceTransaction.amount;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    onTap: () async {
                      await provider.linkAsInternalTransfer(
                          sourceTransaction.id!, tx.id!);
                      if (context.mounted) {
                        Navigator.pop(context); // close sheet
                        AppToast.success(context, message: 'Internal transfer linked');
                      }
                    },
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: (tx.type == 'income'
                                ? AppColors.positive
                                : AppColors.warning)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        tx.type == 'income'
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: tx.type == 'income'
                            ? AppColors.positive
                            : AppColors.warning,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      tx.sender,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, HH:mm').format(tx.date),
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,##0.00').format(tx.amount)} ETB',
                          style: TextStyle(
                            color: tx.type == 'income'
                                ? AppColors.positive
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (isExactMatch) ...[
                          const SizedBox(height: 4),
                          const AppBadge.warning(
                            text: 'EXACT AMOUNT',
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
