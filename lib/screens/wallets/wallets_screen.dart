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
  bool _isPausedSectionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final senders = provider.senders;

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
                        AppToast.info(
                          context,
                          message: 'Add New Wallet',
                          subtitle: 'Multi-bank linking feature is coming soon!',
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
                            final activeSenders = provider.activeSenders;
                            final pausedSenders = provider.pausedSenders;
                            final int activeCount = activeSenders.length;

                            // 1. Active Bank Cards
                            if (index < activeCount) {
                              final sender = activeSenders[index];
                              final double balance =
                                  provider.balanceForSender(sender.senderName);
                              final int txCount =
                                  provider.txCountForSender(sender.senderName);

                              return _WalletCard(
                                senderName: sender.senderName,
                                balance: balance,
                                txCount: txCount,
                                isBalanceVisible: provider.isBalanceVisible,
                                isPaused: false,
                                onTap: () => Navigator.push(
                                   context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SenderDetailScreen(sender: sender),
                                  ),
                                ),
                              );
                            }

                            // 2. Cash Wallet (Directly below active bank cards)
                            if (index == activeCount) {
                              return _buildCashWalletRow(context, provider);
                            }

                            // 3. Paused Section Collapsible Header Card
                            if (index == activeCount + 1 &&
                                pausedSenders.isNotEmpty) {
                              return _buildPausedSectionHeader(
                                context,
                                pausedSenders.length,
                                isExpanded: _isPausedSectionExpanded,
                                onToggle: () {
                                  setState(() {
                                    _isPausedSectionExpanded =
                                        !_isPausedSectionExpanded;
                                  });
                                },
                              );
                            }

                            // 4. Paused Bank Cards (Shown only when expanded)
                            if (_isPausedSectionExpanded) {
                              final int pausedIndex =
                                  index - (activeCount + 2);
                              if (pausedIndex >= 0 &&
                                  pausedIndex < pausedSenders.length) {
                                final sender = pausedSenders[pausedIndex];
                                final double balance =
                                    provider.balanceForSender(sender.senderName);
                                final int txCount =
                                    provider.txCountForSender(sender.senderName);

                                return _WalletCard(
                                  senderName: sender.senderName,
                                  balance: balance,
                                  txCount: txCount,
                                  isBalanceVisible: false,
                                  isPaused: true,
                                  onTap: () {},
                                );
                              }
                            }

                            return const SizedBox.shrink();
                          },
                          childCount: provider.activeSenders.length +
                              1 +
                              (provider.pausedSenders.isNotEmpty
                                  ? (1 +
                                      (_isPausedSectionExpanded
                                          ? provider.pausedSenders.length
                                          : 0))
                                  : 0),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedSectionHeader(
    BuildContext context,
    int count, {
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            AppBadge.warning(
              text: 'PAUSED TRACKING ($count)',
              icon: Icons.pause_circle_rounded,
              size: AppBadgeSize.small,
            ),
            const Spacer(),
            Text(
              isExpanded ? 'Hide' : 'Show',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.65),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashWalletRow(BuildContext context, FinanceProvider provider) {
    return _WalletCard(
      senderName: 'Cash Wallet',
      balance: provider.balanceForSender('Cash Wallet'),
      txCount: provider.txCountForSender('Cash Wallet'),
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

    // During any flight/transition between Home and Wallet (pageOffset < 0.98),
    // main_shell's overlay handles 100% of the flying cards with ZERO ghost cards underneath.
    // As soon as user arrives on Wallet Manager (pageOffset >= 0.98),
    // render the 100% real card widget in-tree.
    if (pageOffset < 0.98) {
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
