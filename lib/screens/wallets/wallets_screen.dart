import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness:
            context.isLightMode ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: context.isLightMode
                ? const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      AppColors.backgroundLight,
                      AppColors.bgMidLight,
                    ],
                  )
                : AppColors.screenBackgroundGradient,
          ),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Header Title & Add New Button ─────────────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: AppHeader(
                    title: 'Wallet Manager',
                    showBackButton: false,
                    trailing: AppButton.primary(
                      text: 'Add New',
                      icon: Icons.add,
                      fullWidth: false,
                      height: 28,
                      fontSize: 11.5,
                      iconSize: 13,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add New Wallet feature coming soon!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // ── Wallet Cards List ─────────────────────────────────────────
              senders.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No wallets connected yet',
                        subtitle: 'Set up senders in Settings to get started',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == senders.length) {
                              return _buildCashWalletRow(context, provider);
                            }

                            final sender = senders[index];
                            final sNameUp = sender.senderName.toUpperCase();
                            final senderTxs = txs.where((t) {
                              final tNameUp = t.name.toUpperCase();
                              final tSenderUp = t.sender.toUpperCase();
                              if (sNameUp == 'BOA' || sNameUp.contains('ABYSSINIA')) {
                                return tNameUp == 'BOA' ||
                                    tSenderUp == 'BOA' ||
                                    tNameUp.contains('ABYSSINIA') ||
                                    tSenderUp.contains('ABYSSINIA');
                              }
                              return tNameUp == sNameUp || tSenderUp == sNameUp;
                            }).toList();

                            double balance = 0;
                            final withBal =
                                senderTxs.where((t) => t.totalBalance > 0);
                            if (withBal.isNotEmpty) {
                              balance = withBal.first.totalBalance;
                            }

                            final isPaused =
                                provider.isTrackingPaused(sender.senderName);

                            return _WalletCard(
                              senderName: sender.senderName,
                              balance: balance,
                              txCount: senderTxs.length,
                              isBalanceVisible: provider.isBalanceVisible,
                              isPaused: isPaused,
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
    int txCount = 0;

    for (var tx in provider.transactions) {
      if (tx.reason?.toLowerCase() == 'cash' ||
          tx.customReasonText?.toLowerCase() == 'cash' ||
          tx.resolvedReason?.toLowerCase() == 'cash') {
        txCount++;
      }
    }
    txCount += provider.cashTransactions.length;

    return _WalletCard(
      senderName: 'Cash Wallet',
      balance: provider.cashBalance,
      txCount: txCount,
      isBalanceVisible: provider.isBalanceVisible,
      isPaused: false, // Cash Wallet is never paused
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CashWalletDetailScreen(),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet Card – renders as a placeholder during page transition, since
// main_shell's flying overlay handles 100% of the flight visuals for ALL cards.
// ─────────────────────────────────────────────────────────────────────────────
class _WalletCard extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;
  final VoidCallback onTap;

  const _WalletCard({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final pageOffset = provider.pageOffset;
    final isWalletActive = provider.currentScreenIndex == 1;

    // During mid-flight transition from Home (when offset is between 0.05 and 0.95 and not yet on wallet screen),
    // placeholders hold height while main_shell's overlay animates.
    // As soon as user reaches Wallet Manager screen (index == 1 or pageOffset >= 0.95),
    // render the 100% fully expanded real card widget in-tree!
    if (!isWalletActive && pageOffset < 0.95) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 160,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
      );
    }

    // Fully expanded real card widget
    return BankCardWidget(
      senderName: senderName,
      balance: balance,
      txCount: txCount,
      isBalanceVisible: isBalanceVisible,
      isPaused: isPaused,
      onTap: onTap,
      animationFactor: 1.0,
    );
  }
}
