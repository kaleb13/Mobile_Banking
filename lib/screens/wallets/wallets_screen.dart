import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../dashboard/sender_detail_screen.dart';
import '../dashboard/cash_wallet_detail_screen.dart';

class WalletsScreen extends StatefulWidget {
  const WalletsScreen({super.key});

  @override
  State<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends State<WalletsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;
    final txs = provider.transactions;
    final fmt = NumberFormat('#,##0.00');

    // Compute totals across all wallets
    double grandBalance = provider.cashBalance;
    double grandIncome = 0;
    double grandExpense = 0;
    for (final s in senders) {
      final senderTxs = txs.where((t) => t.name == s.senderName).toList();
      final bal = senderTxs.where((t) => t.totalBalance > 0);
      if (bal.isNotEmpty) grandBalance += bal.first.totalBalance;
      grandIncome += senderTxs
          .where((t) => t.type == 'income')
          .fold<double>(0, (a, t) => a + t.amount);
      grandExpense += senderTxs
          .where((t) => t.type == 'expense')
          .fold<double>(0, (a, t) => a + t.amount);
    }

    // Add cash transactions to grand income/expense
    for (final ctx in provider.cashTransactions) {
      if (ctx.type == 'addition') {
        grandIncome += ctx.amount;
      } else {
        grandExpense += ctx.amount;
      }
    }
    // Add bank transactions labeled "Cash" to grand income since it's an inflow to the wallet but an outflow from the bank. Wait, actually if it's an withdrawal, it's counted as an expense from the bank, which is already in `grandExpense`. So net worth isn't affected. Let's just keep grandIncome/grandExpense as-is for Cash Wallet additions.

    final grandNet = grandIncome - grandExpense;

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
                Color(0xFF1F1F25),
                Color(0xFF1B1B21),
              ],
            ),
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── App bar ──────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Section
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Wallets',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Connected bank accounts',
                              style: TextStyle(
                                  color: AppColors.textGray, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Grand summary banner ────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Net Worth',
                          style: TextStyle(
                              color: AppColors.labelGray, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(height: 6),
                        _splitBalance(
                            provider.isBalanceVisible
                                ? fmt.format(grandBalance)
                                : '****.**',
                            36,
                            22),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _miniStatChip(
                                'Income',
                                provider.isBalanceVisible
                                    ? fmt.format(grandIncome)
                                    : '****',
                                AppColors.mintGreen,
                                Icons.arrow_downward_rounded),
                            const SizedBox(width: 10),
                            _miniStatChip(
                                'Expense',
                                provider.isBalanceVisible
                                    ? fmt.format(grandExpense)
                                    : '****',
                                AppColors.alertRed,
                                Icons.arrow_upward_rounded),
                            const SizedBox(width: 10),
                            _miniStatChip(
                              'Net',
                              provider.isBalanceVisible
                                  ? '${grandNet >= 0 ? '+' : ''}${fmt.format(grandNet)}'
                                  : '****',
                              grandNet >= 0
                                  ? AppColors.mintGreen
                                  : AppColors.alertRed,
                              grandNet >= 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: const Text(
                    'ACCOUNTS',
                    style: TextStyle(
                      color: AppColors.textGray,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                    ),
                  ),
                ),
              ),

              // ── Wallet cards list ─────────────────────────────────────────
              senders.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                color:
                                    AppColors.textGray.withValues(alpha: 0.4),
                                size: 56),
                            const SizedBox(height: 16),
                            const Text(
                              'No wallets connected yet',
                              style: TextStyle(
                                color: AppColors.textGray,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Set up senders in Settings to get started',
                              style: TextStyle(
                                  color: AppColors.labelGray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == senders.length) {
                              return _buildCashWalletRow(context, provider);
                            }

                            final sender = senders[index];
                            final senderTxs = txs
                                .where((t) => t.name == sender.senderName)
                                .toList();

                            double balance = 0;
                            final withBal =
                                senderTxs.where((t) => t.totalBalance > 0);
                            if (withBal.isNotEmpty) {
                              balance = withBal.first.totalBalance;
                            }

                            double income = senderTxs
                                .where((t) => t.type == 'income')
                                .fold<double>(0, (a, t) => a + t.amount);
                            double expense = senderTxs
                                .where((t) => t.type == 'expense')
                                .fold<double>(0, (a, t) => a + t.amount);
                            final net = income - expense;

                            // This month's stats
                            final now = DateTime.now();
                            final monthTxs = senderTxs
                                .where((t) =>
                                    t.date.year == now.year &&
                                    t.date.month == now.month)
                                .toList();
                            final monthIncome = monthTxs
                                .where((t) => t.type == 'income')
                                .fold<double>(0, (a, t) => a + t.amount);
                            final monthExpense = monthTxs
                                .where((t) => t.type == 'expense')
                                .fold<double>(0, (a, t) => a + t.amount);

                            return _WalletCard(
                              senderName: sender.senderName,
                              balance: balance,
                              totalIncome: income,
                              totalExpense: expense,
                              net: net,
                              monthIncome: monthIncome,
                              monthExpense: monthExpense,
                              txCount: senderTxs.length,
                              isBalanceVisible: provider.isBalanceVisible,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SenderDetailScreen(sender: sender),
                                ),
                              ),
                            );
                          },
                          childCount: senders.length + 1,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashWalletRow(BuildContext context, FinanceProvider provider) {
    double income = 0;
    double expense = 0;
    int txCount = 0;
    double monthIncome = 0;
    double monthExpense = 0;
    final now = DateTime.now();

    // Combine SMS "Cash" withdrawals and manual additions
    for (var tx in provider.transactions) {
      if (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash') {
        income += tx.amount.abs();
        txCount++;
        if (tx.date.year == now.year && tx.date.month == now.month) {
          monthIncome += tx.amount.abs();
        }
      }
    }

    for (var ctx in provider.cashTransactions) {
      txCount++;
      if (ctx.type == 'addition') {
        income += ctx.amount;
        if (ctx.date.year == now.year && ctx.date.month == now.month) {
          monthIncome += ctx.amount;
        }
      } else {
        expense += ctx.amount;
        if (ctx.date.year == now.year && ctx.date.month == now.month) {
          monthExpense += ctx.amount;
        }
      }
    }

    return _WalletCard(
      senderName: 'Cash Wallet',
      balance: provider.cashBalance,
      totalIncome: income,
      totalExpense: expense,
      net: income - expense,
      monthIncome: monthIncome,
      monthExpense: monthExpense,
      txCount: txCount,
      isBalanceVisible: provider.isBalanceVisible,
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CashWalletDetailScreen()));
      },
    );
  }

  Widget _splitBalance(String fmtStr, double mainSize, double decimalSize) {
    final parts = fmtStr.split('.');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          parts[0],
          style: TextStyle(
            color: Colors.white,
            fontSize: mainSize,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
        Text(
          '.${parts[1]}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: decimalSize,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _miniStatChip(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 10),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Wallet Card
// ─────────────────────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final String senderName;
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final double monthIncome;
  final double monthExpense;
  final int txCount;
  final bool isBalanceVisible;
  final VoidCallback onTap;

  const _WalletCard({
    required this.senderName,
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.monthIncome,
    required this.monthExpense,
    required this.txCount,
    required this.isBalanceVisible,
    required this.onTap,
  });

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    String imagePath = '';
    List<Color> cardGradient;

    if (nameUp == 'CBE') {
      cardGradient = [
        const Color(0xFF3D1B0F),
        const Color(0xFF6E482F),
        const Color(0xFF3D1B0F)
      ];
      imagePath = 'assets/images/CBE logo 1.png';
    } else if (nameUp == 'TELEBIRR') {
      cardGradient = [
        const Color(0xFF0BA751),
        const Color(0xFF88BF47),
        const Color(0xFF0BA751)
      ];
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      cardGradient = [
        const Color(0xFFAFAFB3),
        const Color(0xFFFFFFFF),
        const Color(0xFFAFAFB3)
      ];
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp == 'CASH WALLET') {
      cardGradient = [
        const Color(0xFF2F2F39),
        const Color(0xFF4F4F59),
        const Color(0xFF2F2F39)
      ];
    } else {
      cardGradient = [
        const Color(0xFF1E1E26),
        const Color(0xFF3E3E4A),
        const Color(0xFF1E1E26)
      ];
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: cardGradient.first.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          gradient: SweepGradient(
            center: Alignment.center,
            transform: const GradientRotation(pi / 4),
            colors: cardGradient,
          ),
        ),
        child: Center(
          child: imagePath.isNotEmpty
              ? Image.asset(
                  imagePath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                )
              : (nameUp == 'CASH WALLET'
                  ? const Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.white, size: 24)
                  : Text(
                      name.isNotEmpty
                          ? name.substring(0, min(3, name.length)).toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    )),
        ),
      ),
    );
  }

  String _subtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'TELEBIRR') return 'Ethio Telecom · E-money';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr · Mobile Wallet';
    if (n == 'CASH WALLET') return 'Physical Cash Tracking';
    return 'Bank Account';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');
    final isPositiveNet = net >= 0;
    final balStr = isBalanceVisible ? fmt.format(balance) : '****.**';
    final parts = balStr.split('.');

    // Income/expense ratio for progress bar
    final totalVol = monthIncome + monthExpense;
    final incomeRatio = totalVol > 0 ? monthIncome / totalVol : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            // Top section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bankLogo(senderName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(senderName),
                          style: const TextStyle(
                              color: AppColors.labelGray, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        // Balance
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              parts[0],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w300,
                                height: 1.0,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              '.${parts[1]}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ETB',
                              style: TextStyle(
                                  color: AppColors.labelGray,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Net badge
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isPositiveNet
                              ? AppColors.mintGreen
                              : AppColors.alertRed)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: (isPositiveNet
                                  ? AppColors.mintGreen
                                  : AppColors.alertRed)
                              .withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositiveNet
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: isPositiveNet
                              ? AppColors.mintGreen
                              : AppColors.alertRed,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isBalanceVisible
                              ? fmtShort.format(net.abs())
                              : '****',
                          style: TextStyle(
                            color: isPositiveNet
                                ? AppColors.mintGreen
                                : AppColors.alertRed,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.05), height: 1),
            ),

            // Bottom stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                children: [
                  // This month section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This month',
                        style: const TextStyle(
                            color: AppColors.labelGray, fontSize: 11),
                      ),
                      Text(
                        '$txCount transactions total',
                        style: const TextStyle(
                            color: AppColors.labelGray, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Income/Expense bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (incomeRatio * 100).round(),
                            child: Container(color: AppColors.mintGreen),
                          ),
                          Expanded(
                            flex:
                                ((1 - incomeRatio) * 100).round().clamp(0, 100),
                            child: Container(
                                color:
                                    AppColors.alertRed.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statPill(
                          'In',
                          isBalanceVisible
                              ? fmtShort.format(monthIncome)
                              : '****',
                          AppColors.mintGreen),
                      const SizedBox(width: 8),
                      _statPill(
                          'Out',
                          isBalanceVisible
                              ? fmtShort.format(monthExpense)
                              : '****',
                          AppColors.alertRed),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppColors.labelGray, size: 13),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A34).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
