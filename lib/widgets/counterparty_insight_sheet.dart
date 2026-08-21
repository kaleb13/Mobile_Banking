import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/finance_provider.dart';
import '../screens/dashboard/all_transactions_screen.dart';
import '../screens/dashboard/transaction_detail_screen.dart';
import '../theme/app_theme.dart';
import 'app_badges.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'bank_card_widget.dart';
import 'currency_symbol_widget.dart';
import 'custom_progress_bar.dart';

/// Modal bottom sheet displaying detailed person-to-person cashflow metrics,
/// historical velocity, net standing, and direct transaction drilldown.
class CounterpartyInsightSheet extends StatelessWidget {
  final String personName;

  const CounterpartyInsightSheet({
    super.key,
    required this.personName,
  });

  /// Standard static launcher to show the counterparty insight sheet.
  static Future<void> show(
    BuildContext context, {
    required String personName,
  }) {
    HapticFeedback.lightImpact();
    return AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (_) => CounterpartyInsightSheet(personName: personName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final isBalanceVisible = provider.isBalanceVisible;
    final fmt = NumberFormat('#,##0.00');

    // Filter transactions exclusively for this counterparty/person
    final personTxs = provider.transactions.where((tx) {
      final s = tx.sender.trim().toLowerCase();
      final target = personName.trim().toLowerCase();
      return s == target || (target.isNotEmpty && s.contains(target));
    }).toList();

    // Sort newest first
    personTxs.sort((a, b) => b.date.compareTo(a.date));

    final incomeTxs = personTxs.where((t) => t.type == 'income').toList();
    final expenseTxs = personTxs.where((t) => t.type == 'expense').toList();

    final double totalSent =
        expenseTxs.fold(0.0, (sum, t) => sum + t.amount);
    final double totalReceived =
        incomeTxs.fold(0.0, (sum, t) => sum + t.amount);
    final double netStanding = totalReceived - totalSent;
    final double totalTurnover = totalSent + totalReceived;

    final double sentRatio = totalTurnover > 0
        ? (totalSent / totalTurnover).clamp(0.0, 1.0)
        : 0.5;

    final Set<String> banksUsed = {};
    for (final tx in personTxs) {
      if (tx.name.isNotEmpty) banksUsed.add(tx.name);
    }

    final DateTime? lastTxDate =
        personTxs.isNotEmpty ? personTxs.first.date : null;

    return AppBottomSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar, Name & Overall Counts ──────────────────────────
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    personName.isNotEmpty
                        ? personName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.buttonPrimaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      personName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${personTxs.length} total interactions',
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge.neutral(
                text: '${personTxs.length} txs',
                size: AppBadgeSize.small,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Net Standing Banner Card ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Net Standing',
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (netStanding > 0)
                      const AppBadge.success(
                        text: 'Net Received',
                        size: AppBadgeSize.small,
                      )
                    else if (netStanding < 0)
                      const AppBadge.destructive(
                        text: 'Net Sent',
                        size: AppBadgeSize.small,
                      )
                    else
                      const AppBadge.neutral(
                        text: 'Even',
                        size: AppBadgeSize.small,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                isBalanceVisible
                    ? CurrencyTextWidget(
                        amount: netStanding,
                        showSign: true,
                        style: TextStyle(
                          color: netStanding >= 0
                              ? AppColors.positive
                              : AppColors.negative,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        customFormattedStr: fmt.format(netStanding.abs()),
                      )
                    : const Text(
                        'ETB ••••••••',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                const SizedBox(height: 10),

                // Distribution Bar between Inflow and Outflow
                CustomProgressBar(
                  progress: sentRatio,
                  height: 8,
                  backgroundColor: AppColors.positive.withValues(alpha: 0.3),
                  progressColor: AppColors.negative,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sent: ${(sentRatio * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.negative,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Received: ${((1.0 - sentRatio) * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: AppColors.positive,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── 2x2 Metric Grid: Sent & Received ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildTile(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: AppColors.negative,
                  title: 'Total Sent',
                  amount: totalSent,
                  subtitle: '${expenseTxs.length} outgoing payments',
                  isBalanceVisible: isBalanceVisible,
                  fmt: fmt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTile(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: AppColors.positive,
                  title: 'Total Received',
                  amount: totalReceived,
                  subtitle: '${incomeTxs.length} incoming deposits',
                  isBalanceVisible: isBalanceVisible,
                  fmt: fmt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Touchpoints & Last Activity Row ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sync_alt_rounded,
                  size: 16,
                  color: AppColors.textSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banksUsed.isNotEmpty
                            ? 'Channels: ${banksUsed.join(', ')}'
                            : 'No channel data',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lastTxDate != null
                            ? 'Last activity ${DateFormat('MMM d, yyyy').format(lastTxDate)}'
                            : 'No recent activity',
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Recent Activity Mini List (Up to 3 Items) ───────────────────────
          if (personTxs.isNotEmpty) ...[
            const Text(
              'Recent Interactions',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.drawerCard,
                borderRadius: AppRadius.cardRadius,
              ),
              child: Column(
                children: [
                  for (int i = 0; i < personTxs.take(3).length; i++) ...[
                    if (i > 0)
                      Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    _buildTransactionRow(
                      context,
                      personTxs[i],
                      isBalanceVisible,
                      fmt,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ── Bottom Full-Width Action Button ─────────────────────────────────
          AppButton.primary(
            text: 'View All ${personTxs.length} Transactions',
            icon: Icons.receipt_long_rounded,
            height: 48,
            onPressed: () {
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(
                MaterialPageRoute(
                  builder: (_) => AllTransactionsScreen(
                    initialSenderFilter: personName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double amount,
    required String subtitle,
    required bool isBalanceVisible,
    required NumberFormat fmt,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.drawerCard,
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isBalanceVisible ? 'ETB ${fmt.format(amount)}' : 'ETB ••••••••',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textDisabled,
              fontSize: 10.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionRow(
    BuildContext context,
    AppTransaction tx,
    bool isBalanceVisible,
    NumberFormat fmt,
  ) {
    final isIncome = tx.type == 'income';
    final dateStr = DateFormat('MMM d, h:mm a').format(tx.date);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(transaction: tx),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            BankCardWidget.bankLogo(tx.name, 18, Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: AppColors.textSoft,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isBalanceVisible
                  ? '${isIncome ? '+' : '-'} ETB ${fmt.format(tx.amount)}'
                  : 'ETB ••••••••',
              style: TextStyle(
                color: isIncome ? AppColors.positive : AppColors.negative,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
