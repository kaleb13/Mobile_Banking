import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/transaction.dart';
import '../../models/cash_transaction.dart';
import '../../models/reason.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../../widgets/app_badges.dart';
import 'reason_transactions_screen.dart';

/// Data class representing a subcategory breakdown item
class SubcategoryAnalysisItem {
  final String name;
  final AppReason? reason;
  final double totalAmount;
  final List<AppTransaction> bankTransactions;
  final List<CashTransaction> cashTransactions;

  const SubcategoryAnalysisItem({
    required this.name,
    this.reason,
    required this.totalAmount,
    required this.bankTransactions,
    required this.cashTransactions,
  });

  int get totalCount => bankTransactions.length + cashTransactions.length;
}

/// Category Drill-Down Screen displaying subcategories and direct transactions
class CategoryDetailScreen extends StatelessWidget {
  final String categoryName;
  final AppReason? categoryReason;
  final Color categoryColor;
  final double totalAmount;
  final String? periodLabel;
  final List<AppTransaction> directBankTransactions;
  final List<CashTransaction> directCashTransactions;
  final List<AppTransaction> allBankTransactions;
  final List<CashTransaction> allCashTransactions;
  final List<SubcategoryAnalysisItem> subcategories;

  const CategoryDetailScreen({
    super.key,
    required this.categoryName,
    this.categoryReason,
    required this.categoryColor,
    required this.totalAmount,
    this.periodLabel,
    required this.directBankTransactions,
    required this.directCashTransactions,
    required this.allBankTransactions,
    required this.allCashTransactions,
    required this.subcategories,
  });

  int get directCount =>
      directBankTransactions.length + directCashTransactions.length;

  double get directAmount {
    double sum = 0.0;
    for (final tx in directBankTransactions) {
      sum += tx.amount;
    }
    for (final ctx in directCashTransactions) {
      sum += ctx.amount;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final isBalanceVisible =
        Provider.of<FinanceProvider>(context).isBalanceVisible;

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
            categoryName,
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
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Summary Banner Card ───────────────────────────────
              Container(
                width: double.infinity,
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
                        color: categoryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.category_rounded,
                        color: categoryColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total in $categoryName',
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
                                isBalanceVisible
                                    ? fmt.format(totalAmount)
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
                    if (periodLabel != null)
                      AppBadge.neutral(
                        text: periodLabel!,
                        size: AppBadgeSize.small,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── 2. Top Card: Direct Transactions Without Subcategory ────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReasonTransactionsScreen(
                            title: 'Direct $categoryName',
                            periodSubtitle: periodLabel,
                            transactions: directBankTransactions.isNotEmpty
                                ? directBankTransactions
                                : allBankTransactions,
                            cashTransactions: directCashTransactions.isNotEmpty
                                ? directCashTransactions
                                : allCashTransactions,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.buttonSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Direct $categoryName Transactions',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  directCount > 0
                                      ? '$directCount transactions without subcategory'
                                      : 'All transactions under $categoryName',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isBalanceVisible
                                    ? '${fmt.format(directAmount > 0 ? directAmount : totalAmount)} ETB'
                                    : '****',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
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
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── 3. Subcategories Section Header ──────────────────────────
              if (subcategories.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SUBCATEGORIES',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '${subcategories.length} ${subcategories.length == 1 ? 'Subcategory' : 'Subcategories'}',
                      style: const TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── 4. Subcategories List ────────────────────────────────────
                ...subcategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final sub = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReasonTransactionsScreen(
                                title: sub.name,
                                reason: sub.reason,
                                periodSubtitle: periodLabel,
                                transactions: sub.bankTransactions,
                                cashTransactions: sub.cashTransactions,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: categoryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sub.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${sub.totalCount} ${sub.totalCount == 1 ? 'transaction' : 'transactions'}',
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
                                    isBalanceVisible
                                        ? '${fmt.format(sub.totalAmount)} ETB'
                                        : '****',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
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
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
