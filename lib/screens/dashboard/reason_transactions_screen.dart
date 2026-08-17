import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/reason.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_badges.dart';
import 'transaction_detail_screen.dart';

/// Screen displaying all transactions associated with a specific reason or subcategory.
class ReasonTransactionsScreen extends StatelessWidget {
  final AppReason? reason;
  final String? title;
  final String? periodSubtitle;
  final List<AppTransaction>? transactions;
  final List<CashTransaction>? cashTransactions;

  const ReasonTransactionsScreen({
    super.key,
    this.reason,
    this.title,
    this.periodSubtitle,
    this.transactions,
    this.cashTransactions,
  });

  String _limitWords(String text, {int maxWords = 2}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    final words =
        trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length <= maxWords) return trimmed;
    return words.take(maxWords).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final displayTitle = title ?? reason?.name ?? 'Transactions';

    // Collect transactions
    List<AppTransaction> matchingTransactions;
    List<CashTransaction> matchingCashTransactions;

    if (transactions != null) {
      matchingTransactions = List.from(transactions!);
      matchingCashTransactions = cashTransactions != null
          ? List.from(cashTransactions!)
          : [];
    } else if (reason != null) {
      final Set<String> targetReasonNames = {
        reason!.name.toLowerCase().trim()
      };
      if (reason!.id != null) {
        final subs = provider.subcategoriesFor(reason!.id!);
        for (final sub in subs) {
          targetReasonNames.add(sub.name.toLowerCase().trim());
        }
      }

      matchingTransactions = provider.transactions.where((tx) {
        final rName =
            (tx.resolvedReason ?? tx.reason ?? '').toLowerCase().trim();
        if (rName.isEmpty) return false;
        return targetReasonNames.contains(rName);
      }).toList();

      matchingCashTransactions = provider.cashTransactions.where((ctx) {
        final rName =
            (ctx.reasonName ?? ctx.description ?? '').toLowerCase().trim();
        if (rName.isEmpty) return false;
        return targetReasonNames.contains(rName);
      }).toList();
    } else {
      matchingTransactions = [];
      matchingCashTransactions = [];
    }

    matchingTransactions.sort((a, b) => b.date.compareTo(a.date));
    matchingCashTransactions.sort((a, b) => b.date.compareTo(a.date));

    double totalSpent = 0.0;
    for (final tx in matchingTransactions) {
      if (tx.type == 'expense') {
        totalSpent += tx.amount;
      }
    }
    for (final ctx in matchingCashTransactions) {
      if (ctx.type == 'expense') {
        totalSpent += ctx.amount;
      }
    }

    final totalCount =
        matchingTransactions.length + matchingCashTransactions.length;
    final fmt = NumberFormat('#,##0.00');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 0,
          title: Text(
            displayTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppColors.background.withValues(alpha: 0.85),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: const AppBackButton(),
        ),
        body: Column(
          children: [
            // ── Summary Header Banner ──────────────────────────────────
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.positive.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.positive,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total in $displayTitle',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              provider.isBalanceVisible
                                  ? fmt.format(totalSpent)
                                  : '****',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const CurrencySymbolWidget(
                              size: 14,
                              color: AppColors.textSoft,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (periodSubtitle != null) ...[
                        AppBadge.neutral(
                          text: periodSubtitle!,
                          size: AppBadgeSize.small,
                        ),
                        const SizedBox(width: 6),
                      ],
                      AppBadge.neutral(
                        text: '$totalCount items',
                        size: AppBadgeSize.small,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Filtered Transactions List ─────────────────────────────
            Expanded(
              child: totalCount == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            size: 48,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No transactions in "$displayTitle" for this period',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: matchingTransactions.length +
                          matchingCashTransactions.length,
                      itemBuilder: (context, index) {
                        if (index < matchingTransactions.length) {
                          final tx = matchingTransactions[index];
                          final isIncome = tx.type == 'income';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransactionDetailScreen(transaction: tx),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: (isIncome
                                              ? AppColors.positive
                                              : AppColors.negative)
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isIncome
                                          ? Icons.arrow_downward_rounded
                                          : Icons.arrow_upward_rounded,
                                      color: isIncome
                                          ? AppColors.positive
                                          : AppColors.negative,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                _limitWords(
                                                    tx.sender.isNotEmpty
                                                        ? tx.sender
                                                        : tx.name,
                                                    maxWords: 2),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (tx.isBookmarked) ...[
                                              const SizedBox(width: 4),
                                              const BookmarkBadge(),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('MMM dd, yyyy • HH:mm')
                                              .format(tx.date),
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        provider.isBalanceVisible
                                            ? '${isIncome ? '+' : '-'}${fmt.format(tx.amount)} ETB'
                                            : '****',
                                        style: TextStyle(
                                          color: isIncome
                                              ? AppColors.positive
                                              : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          final cIdx = index - matchingTransactions.length;
                          final ctx = matchingCashTransactions[cIdx];
                          final isIncome = ctx.type == 'addition' ||
                              ctx.type == 'income';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: (isIncome
                                            ? AppColors.positive
                                            : AppColors.negative)
                                        .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIncome
                                        ? AppColors.positive
                                        : AppColors.negative,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ctx.description ?? 'Cash Spending',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('MMM dd, yyyy • HH:mm')
                                            .format(ctx.date),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      provider.isBalanceVisible
                                          ? '${isIncome ? '+' : '-'}${fmt.format(ctx.amount)} ETB'
                                          : '****',
                                      style: TextStyle(
                                        color: isIncome
                                            ? AppColors.positive
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cash Wallet',
                                      style: TextStyle(
                                        color: AppColors.textSoft,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
