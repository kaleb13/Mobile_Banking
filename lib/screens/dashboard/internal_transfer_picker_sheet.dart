import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';

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

    // Find candidates
    // It should be within a couple of days and roughly the same amount
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

    return Container(
      margin: const EdgeInsets.only(top: 60),
      height:
          MediaQuery.of(context).size.height * 0.85, // Provide bounded height
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textGray.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.sync_alt, color: AppColors.primaryBlue),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Linked Transaction',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textGray),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Select the matching $targetType for this internal transfer. Only unlinked transactions within 3 days are shown.',
              style: const TextStyle(color: AppColors.labelGray, fontSize: 13),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: candidates.isEmpty
                ? const Center(
                    child: Text(
                      'No matching transactions found.',
                      style: TextStyle(color: AppColors.textGray),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: candidates.length,
                    itemBuilder: (ctx, i) {
                      final tx = candidates[i];
                      final isExactMatch =
                          tx.amount == sourceTransaction.amount;

                      return ListTile(
                        onTap: () async {
                          await provider.linkAsInternalTransfer(
                              sourceTransaction.id!, tx.id!);
                          if (context.mounted) {
                            Navigator.pop(context); // close sheet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Internal transfer linked!'),
                                backgroundColor: AppColors.primaryBlue,
                              ),
                            );
                            Navigator.pop(context); // close detail screen
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: tx.type == 'income'
                              ? AppColors.mintGreen.withValues(alpha: 0.1)
                              : AppColors.alertRed.withValues(alpha: 0.1),
                          child: Icon(
                            tx.type == 'income'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: tx.type == 'income'
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          tx.sender,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          DateFormat('MMM dd, HH:mm').format(tx.date),
                          style: const TextStyle(
                              color: AppColors.labelGray, fontSize: 12),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${NumberFormat('#,##0.00').format(tx.amount)} ETB',
                              style: TextStyle(
                                color: tx.type == 'income'
                                    ? AppColors.mintGreen
                                    : AppColors.alertRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isExactMatch)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EXACT AMOUNT',
                                  style: TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
