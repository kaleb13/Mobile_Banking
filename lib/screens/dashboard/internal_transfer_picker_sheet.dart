import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_toast.dart';

class InternalTransferPickerSheet extends StatelessWidget {
  final AppTransaction sourceTransaction;
  final TransactionsViewModel? txVM;
  final int daysRange;

  const InternalTransferPickerSheet({
    super.key,
    required this.sourceTransaction,
    this.txVM,
    this.daysRange = 7,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveVM = txVM ?? Provider.of<TransactionsViewModel>(context);
    final candidates = effectiveVM.getInternalTransferCandidates(
      sourceTransaction,
      daysRange: daysRange,
    );

    return AppDrawer(
      heightFactor: 0.85,
      headerCard: const AppDrawerHeaderCard(
        icon: Icons.sync_alt_rounded,
        title: 'Link Transfer',
      ),
      child: candidates.isEmpty
          ? Center(
              child: Text(
                'No matching transactions found within $daysRange days.',
                style: const TextStyle(color: AppColors.textSoft, fontSize: 13),
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
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    onTap: () async {
                      await effectiveVM.linkAsInternalTransfer(
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
