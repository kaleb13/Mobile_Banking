import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bank_avatar.dart';

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
                final diff = (tx.amount - sourceTransaction.amount).abs();
                final isExactMatch = diff < 0.01;
                final isCloseMatch = !isExactMatch &&
                    (diff <= 50.0 ||
                        (sourceTransaction.amount > 0 &&
                            (diff / sourceTransaction.amount) <= 0.05));

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: AppRadius.cardRadius,
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.cardRadius),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    onTap: () async {
                      await effectiveVM.linkAsInternalTransfer(
                          sourceTransaction.id!, tx.id!);
                      if (context.mounted) {
                        Navigator.pop(context); // close sheet
                        AppToast.success(context,
                            message: 'Internal transfer linked');
                      }
                    },
                    leading: BankAvatar(
                      bankName: tx.name,
                      size: 38,
                      iconSize: 20,
                    ),
                    title: Text(
                      tx.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (tx.sender.trim().isNotEmpty &&
                            tx.sender.trim().toLowerCase() !=
                                tx.name.trim().toLowerCase()) ...[
                          const SizedBox(height: 2),
                          Text(
                            tx.sender,
                            style: const TextStyle(
                              color: AppColors.textSoft,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('MMM dd, yyyy • HH:mm').format(tx.date),
                          style: TextStyle(
                            color: AppColors.textSoft.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ],
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
                          const AppBadge.success(
                            text: 'EXACT MATCH',
                            size: AppBadgeSize.micro,
                          ),
                        ] else if (isCloseMatch) ...[
                          const SizedBox(height: 4),
                          const AppBadge.warning(
                            text: 'CLOSE MATCH',
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
