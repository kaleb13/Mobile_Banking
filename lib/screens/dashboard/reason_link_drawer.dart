import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/app_confirm_dialog.dart';

/// Standard drawer to link a Category/Reason to a contact/counterparty.
/// Offers 2 scopes:
/// 1. All Transactions (Past & Future)
/// 2. From Now On (Future only)
class LinkReasonDrawer extends StatelessWidget {
  final int reasonId;
  final String reasonName;
  final String contactName;
  final String linkType;
  final String? currentTransactionId;

  const LinkReasonDrawer({
    super.key,
    required this.reasonId,
    required this.reasonName,
    required this.contactName,
    required this.linkType,
    this.currentTransactionId,
  });

  static Future<void> show({
    required BuildContext context,
    required int reasonId,
    required String reasonName,
    required String contactName,
    required String linkType,
    String? currentTransactionId,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (_) => LinkReasonDrawer(
        reasonId: reasonId,
        reasonName: reasonName,
        contactName: contactName,
        linkType: linkType,
        currentTransactionId: currentTransactionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
    final lowerName = contactName.toLowerCase().trim();
    final expectedType = linkType == 'sender' ? 'income' : 'expense';

    final matchingCount = txVM.transactions.where((t) {
      final matchesName = t.sender.toLowerCase().trim() == lowerName;
      final matchesType = t.type.toLowerCase() == expectedType;
      return matchesName && matchesType;
    }).length;

    return AppDrawer(
      heightFactor: null,
      maxHeightFactor: 0.85,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.add_link_rounded,
        iconColor: AppColors.positive,
        title: 'Link "$reasonName"',
        subtitle: 'Auto-categorize transactions for "$contactName"',
        trailing: AppBadge.neutral(
          text: '$matchingCount ${matchingCount == 1 ? 'tx' : 'txs'}',
          size: AppBadgeSize.small,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECT LINKING SCOPE',
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // ── Option 1: All Transactions (Past & Future) ────────────────────
          _buildOptionCard(
            context: context,
            icon: Icons.all_inclusive_rounded,
            iconColor: AppColors.positive,
            title: 'All Transactions (Past & Future)',
            subtitle: matchingCount > 0
                ? 'Update all $matchingCount past transactions and automatically categorize all future ${linkType == 'sender' ? 'income transactions from' : 'expense transactions to'} "$contactName".'
                : 'Automatically categorize all future ${linkType == 'sender' ? 'income transactions from' : 'expense transactions to'} and apply to any past records.',
            badgeText: 'Recommended',
            badgeVariant: AppBadgeVariant.success,
            onTap: () async {
              Navigator.pop(context);
              await txVM.addReasonLinkScoped(
                reasonId: reasonId,
                linkedName: contactName,
                linkType: linkType,
                scope: LinkScope.allTransactions,
                currentTransactionId: currentTransactionId,
              );
              if (context.mounted) {
                AppToast.success(
                  context,
                  message: 'Linked "$reasonName" to all transactions ${linkType == 'sender' ? 'from' : 'to'} "$contactName"',
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // ── Option 2: From Now On (Future only) ───────────────────────────
          _buildOptionCard(
            context: context,
            icon: Icons.update_rounded,
            iconColor: AppColors.info,
            title: 'From Now On (Future Only)',
            subtitle:
                'Keep past transactions unchanged, but automatically categorize all upcoming ${linkType == 'sender' ? 'income transactions from' : 'expense transactions to'} "$contactName".',
            badgeText: 'Future',
            badgeVariant: AppBadgeVariant.info,
            onTap: () async {
              Navigator.pop(context);
              await txVM.addReasonLinkScoped(
                reasonId: reasonId,
                linkedName: contactName,
                linkType: linkType,
                scope: LinkScope.futureTransactionsOnly,
                currentTransactionId: currentTransactionId,
              );
              if (context.mounted) {
                AppToast.success(
                  context,
                  message: 'Saved auto-link rule for future transactions',
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required AppBadgeVariant badgeVariant,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AppBadge(
                            text: badgeText,
                            variant: badgeVariant,
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard drawer to remove/unlink a Category/Reason from a contact/counterparty.
/// Offers the 3 requested unlinking features:
/// 1. Unlink all transactions that occurred at all times (Past + Future / Wipe)
/// 2. Unlink this transaction only (Single Tx Exception)
/// 3. Unlink transactions from now on (Future only / Stop rule)
class UnlinkReasonDrawer extends StatelessWidget {
  final AppReasonLink link;
  final String reasonName;
  final String contactName;
  final String? currentTransactionId;

  const UnlinkReasonDrawer({
    super.key,
    required this.link,
    required this.reasonName,
    required this.contactName,
    this.currentTransactionId,
  });

  static Future<void> show({
    required BuildContext context,
    required AppReasonLink link,
    required String reasonName,
    required String contactName,
    String? currentTransactionId,
  }) {
    return AppDrawer.show(
      context: context,
      builder: (_) => UnlinkReasonDrawer(
        link: link,
        reasonName: reasonName,
        contactName: contactName,
        currentTransactionId: currentTransactionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context, listen: false);
    final lowerName = contactName.toLowerCase().trim();

    final matchingCount = txVM.transactions.where((t) {
      final matchesName = t.sender.toLowerCase().trim() == lowerName;
      final matchesReason = t.reasonId == link.reasonId ||
          (t.resolvedReason?.toLowerCase() == reasonName.toLowerCase());
      return matchesName && matchesReason;
    }).length;

    return AppDrawer(
      heightFactor: null,
      maxHeightFactor: 0.90,
      headerCard: AppDrawerHeaderCard(
        icon: Icons.link_off_rounded,
        iconColor: AppColors.negative,
        title: 'Unlink "$reasonName"',
        subtitle: 'Manage rule for "$contactName"',
        trailing: AppBadge.neutral(
          text: '$matchingCount ${matchingCount == 1 ? 'tx linked' : 'txs linked'}',
          size: AppBadgeSize.small,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHOOSE UNLINKING OPTION',
            style: TextStyle(
              color: AppColors.textSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // ── Option 1: Unlink all transactions at all times ────────────────
          _buildOptionCard(
            context: context,
            icon: Icons.delete_sweep_rounded,
            iconColor: AppColors.negative,
            title: 'All Transactions (Past & Future)',
            subtitle: matchingCount > 0
                ? 'Delete this rule and reset all $matchingCount past transactions from "$contactName" back to Uncategorized.'
                : 'Delete this rule and ensure all past and future transactions are Uncategorized.',
            badgeText: 'Full Wipe',
            badgeVariant: AppBadgeVariant.destructive,
            isDestructive: true,
            onTap: () async {
              final confirm = await AppConfirmDialog.show(
                context: context,
                title: 'Unlink All Transactions?',
                icon: Icons.delete_sweep_rounded,
                iconColor: AppColors.negative,
                message:
                    'This will remove the link rule and reset all $matchingCount transactions from "$contactName" to Uncategorized.\n\nAre you sure you want to proceed?',
                confirmText: 'Unlink All',
                cancelText: 'Cancel',
                isDestructive: true,
                onConfirm: () {},
              );

              if (confirm == true && context.mounted) {
                Navigator.pop(context);
                await txVM.unlinkReason(
                  linkId: link.id!,
                  linkedName: contactName,
                  linkType: link.linkType,
                  scope: UnlinkScope.allTransactions,
                  reasonId: link.reasonId,
                  currentTransactionId: currentTransactionId,
                );
                if (context.mounted) {
                  AppToast.info(
                    context,
                    message: 'Unlinked all transactions for "$contactName"',
                  );
                }
              }
            },
          ),
          const SizedBox(height: 10),

          // ── Option 2: Unlink this transaction only ────────────────────────
          if (currentTransactionId != null) ...[
            _buildOptionCard(
              context: context,
              icon: Icons.remove_circle_outline_rounded,
              iconColor: AppColors.warning,
              title: 'This Transaction Only',
              subtitle:
                  'Remove "$reasonName" from only this individual transaction. Future and other past transactions remain linked.',
              badgeText: 'Single Tx',
              badgeVariant: AppBadgeVariant.warning,
              onTap: () async {
                Navigator.pop(context);
                await txVM.unlinkReason(
                  linkId: link.id!,
                  linkedName: contactName,
                  linkType: link.linkType,
                  scope: UnlinkScope.thisTransactionOnly,
                  currentTransactionId: currentTransactionId,
                  reasonId: link.reasonId,
                );
                if (context.mounted) {
                  AppToast.info(
                    context,
                    message: 'Category removed from this transaction',
                  );
                }
              },
            ),
            const SizedBox(height: 10),
          ],

          // ── Option 3: Unlink from now on (Future only) ────────────────────
          _buildOptionCard(
            context: context,
            icon: Icons.history_toggle_off_rounded,
            iconColor: Colors.white70,
            title: 'From Now On (Future Only)',
            subtitle:
                'Stop auto-categorizing upcoming transactions from "$contactName", but keep all $matchingCount past transactions categorized.',
            badgeText: 'Stop Rule',
            badgeVariant: AppBadgeVariant.neutral,
            onTap: () async {
              Navigator.pop(context);
              await txVM.unlinkReason(
                linkId: link.id!,
                linkedName: contactName,
                linkType: link.linkType,
                scope: UnlinkScope.futureTransactionsOnly,
                currentTransactionId: currentTransactionId,
                reasonId: link.reasonId,
              );
              if (context.mounted) {
                AppToast.info(
                  context,
                  message: 'Auto-link rule removed for future transactions',
                );
              }
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required AppBadgeVariant badgeVariant,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDestructive
            ? AppColors.negative.withValues(alpha: 0.08)
            : AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.cardRadius,
        child: InkWell(
          borderRadius: AppRadius.cardRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? AppColors.negative.withValues(alpha: 0.15)
                        : iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: isDestructive
                                    ? AppColors.negative
                                    : Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AppBadge(
                            text: badgeText,
                            variant: badgeVariant,
                            size: AppBadgeSize.micro,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
