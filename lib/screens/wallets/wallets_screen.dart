import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../dashboard/sender_detail_screen.dart';

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
    double grandBalance = 0;
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
    final grandNet = grandIncome - grandExpense;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0B0D),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── App bar ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.0, -0.9),
                    radius: 1.0,
                    colors: [
                      Color(0xFF0F3A4F),
                      Color(0xFF091E2A),
                      Color(0xFF0A0B0D),
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.accentBlue,
                                  size: 20),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'My Wallets',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  'Connected bank accounts',
                                  style: TextStyle(
                                      color: Color(0xFF6B8FA6), fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ── Grand summary banner ────────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2133),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryBlue
                                    .withValues(alpha: 0.12),
                                blurRadius: 30,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Net Worth',
                                style: TextStyle(
                                    color: Color(0xFF6B8FA6), fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              _splitBalance(fmt.format(grandBalance), 36, 22),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _miniStatChip(
                                      'Income',
                                      fmt.format(grandIncome),
                                      AppColors.mintGreen,
                                      Icons.arrow_downward_rounded),
                                  const SizedBox(width: 10),
                                  _miniStatChip(
                                      'Expense',
                                      fmt.format(grandExpense),
                                      AppColors.alertRed,
                                      Icons.arrow_upward_rounded),
                                  const SizedBox(width: 10),
                                  _miniStatChip(
                                    'Net',
                                    '${grandNet >= 0 ? '+' : ''}${fmt.format(grandNet)}',
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

                        const SizedBox(height: 24),

                        const Text(
                          'ACCOUNTS',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Wallet cards list ─────────────────────────────────────────
            senders.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet_outlined,
                              color: AppColors.textGray.withValues(alpha: 0.4),
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
                                color: Color(0xFF4A6572), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
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
                            sender: sender,
                            balance: balance,
                            totalIncome: income,
                            totalExpense: expense,
                            net: net,
                            monthIncome: monthIncome,
                            monthExpense: monthExpense,
                            txCount: senderTxs.length,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SenderDetailScreen(sender: sender),
                              ),
                            ),
                          );
                        },
                        childCount: senders.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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
  final dynamic sender;
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final double net;
  final double monthIncome;
  final double monthExpense;
  final int txCount;
  final VoidCallback onTap;

  const _WalletCard({
    required this.sender,
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.monthIncome,
    required this.monthExpense,
    required this.txCount,
    required this.onTap,
  });

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    if (nameUp == 'CBE') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/CBE.png',
            width: 48, height: 48, fit: BoxFit.cover),
      );
    } else if (nameUp == 'TELEBIRR') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/Telebirr.png',
            width: 48, height: 48, fit: BoxFit.cover),
      );
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset('assets/images/CBEBirr.png',
            width: 48, height: 48, fit: BoxFit.cover),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          name.substring(0, min(3, name.length)).toUpperCase(),
          style: const TextStyle(
              color: AppColors.accentBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _subtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'TELEBIRR') return 'Ethio Telecom · E-money';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr · Mobile Wallet';
    return 'Bank Account';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final fmtShort = NumberFormat('#,##0');
    final isPositiveNet = net >= 0;
    final balStr = fmt.format(balance);
    final parts = balStr.split('.');

    // Income/expense ratio for progress bar
    final totalVol = monthIncome + monthExpense;
    final incomeRatio = totalVol > 0 ? monthIncome / totalVol : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1417),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: [
            // Top section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bankLogo(sender.senderName),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender.senderName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(sender.senderName),
                          style: const TextStyle(
                              color: Color(0xFF4A6572), fontSize: 11),
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
                                  color: Color(0xFF4A6572),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                          fmtShort.format(net.abs()),
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(
                children: [
                  // This month section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This month',
                        style: const TextStyle(
                            color: Color(0xFF4A6572), fontSize: 11),
                      ),
                      Text(
                        '$txCount transactions total',
                        style: const TextStyle(
                            color: Color(0xFF4A6572), fontSize: 11),
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
                      _statPill('In', fmtShort.format(monthIncome),
                          AppColors.mintGreen),
                      const SizedBox(width: 8),
                      _statPill('Out', fmtShort.format(monthExpense),
                          AppColors.alertRed),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Color(0xFF3D5566), size: 13),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
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
