import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/currency_symbol_widget.dart';
import '../settings/expense_definitions_screen.dart';
import 'cash_wallet/cash_action_sheet.dart';
import 'cash_wallet/cash_add_sheet.dart';
import 'cash_wallet/cash_deduct_sheet.dart';
import 'cash_wallet/cash_wallet_header.dart';
import 'transaction_detail_screen.dart';

class CashWalletDetailScreen extends StatefulWidget {
  const CashWalletDetailScreen({super.key});

  @override
  State<CashWalletDetailScreen> createState() => _CashWalletDetailScreenState();
}

class _CashWalletDetailScreenState extends State<CashWalletDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                AppColors.background,
                AppColors.bgMid,
              ],
            ),
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Dynamic Shrinking/Collapsing Top Header ──
              SliverPersistentHeader(
                pinned: true,
                delegate: CashWalletHeaderDelegate(
                  provider: provider,
                  topSafeArea: topSafeArea,
                  onAddCash: () => showAddCashModal(context, provider),
                  onDeduct: () => showCashDeductModal(context, provider),
                  onTemplates: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExpenseDefinitionsScreen(),
                      ),
                    );
                  },
                ),
              ),

              // ── Activity History List ──
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
                sliver: _buildTransactionSliver(context, provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSliver(
      BuildContext context, FinanceProvider provider) {
    // Create a unified list of dynamic transaction maps
    final List<Map<String, dynamic>> allTxs = [];
    final fmtShort = NumberFormat('#,##0');

    for (var tx in provider.transactions) {
      final isCash = (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash');
      if (isCash) {
        final isWithdrawal = tx.type == 'expense'; // Bank withdrawal = physical cash IN into wallet (+)
        allTxs.add({
          'appTransaction': tx,
          'date': tx.date,
          'title': isWithdrawal ? 'Bank Cash Withdrawal' : 'Bank Cash Deposit',
          'subtitle': tx.name, // Bank name
          'amount': tx.amount,
          'isPositive': isWithdrawal,
          'isCashTx': false,
        });
      }
    }

    for (var ctx in provider.cashTransactions) {
      String sub = ctx.description ?? '';
      if (ctx.reasonName != null && ctx.reasonName!.isNotEmpty) {
        sub = ctx.reasonName!;
        if (ctx.description != null && ctx.description!.isNotEmpty) {
          sub += ' (${ctx.description})';
        }
      }

      allTxs.add({
        'id': ctx.id,
        'date': ctx.date,
        'title': ctx.type == 'addition'
            ? 'Manual Addition'
            : (ctx.reasonName ?? 'Cash Expense'),
        'subtitle': sub,
        'amount': ctx.amount,
        'isPositive': ctx.type == 'addition',
        'isCashTx': true,
      });
    }

    allTxs.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    if (allTxs.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: Text('No cash transactions yet.',
                style: TextStyle(color: AppColors.textSoft)),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            );
          }

          final tx = allTxs[index - 1];
          final date = tx['date'] as DateTime;
          final isPositive = tx['isPositive'] as bool;

          return InkWell(
            onTap: tx['isCashTx'] == false && tx['appTransaction'] != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(
                            transaction: tx['appTransaction']),
                      ),
                    );
                  }
                : null,
            onLongPress: tx['isCashTx'] == true
                ? () {
                    showCashTransactionActions(
                      context,
                      provider,
                      tx['id'],
                      tx['amount'],
                      tx['title'] as String,
                    );
                  }
                : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isPositive
                          ? AppColors.positive.withValues(alpha: 0.1)
                          : AppColors.negative.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isPositive
                          ? AppColors.positive
                          : AppColors.negative,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx['title'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((tx['subtitle'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              tx['subtitle'] as String,
                              style: const TextStyle(
                                color: AppColors.textSoft,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, yyyy · hm a').format(date),
                          style: const TextStyle(
                            color: AppColors.textSoft,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: provider.isBalanceVisible
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${isPositive ? '+' : '-'}${fmtShort.format(tx['amount'])}',
                                style: TextStyle(
                                  color: isPositive
                                      ? AppColors.positive
                                      : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              CurrencySymbolWidget(
                                color: isPositive
                                    ? AppColors.positive
                                    : Colors.white,
                                size: 12,
                              ),
                            ],
                          )
                        : const Text(
                            '••••••••',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        childCount: allTxs.length + 1,
      ),
    );
  }
}
