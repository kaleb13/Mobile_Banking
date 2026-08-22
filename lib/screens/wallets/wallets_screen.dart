import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/sender.dart';
import '../../presentation/viewmodels/transactions_view_model.dart';
import '../../presentation/viewmodels/cash_wallet_view_model.dart';
import '../../presentation/viewmodels/settings_view_model.dart';
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
    final txVM = Provider.of<TransactionsViewModel>(context);
    final cashVM = Provider.of<CashWalletViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final senders = txVM.senders;

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
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'No wallets connected yet',
                        subtitle: 'Set up senders in Settings to get started',
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 140),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final activeSenders = txVM.activeSenders;
                            final pausedSenders = txVM.pausedSenders;
                            final int activeCount = activeSenders.length;

                            // 1. Active Bank Cards
                            if (index < activeCount) {
                              final sender = activeSenders[index];
                              final double balance =
                                  txVM.balanceForSender(sender.senderName, cashBalance: cashVM.cashBalance);
                              final int txCount =
                                  txVM.txCountForSender(sender.senderName, cashTxCount: cashVM.cashTransactions.length);

                              return _WalletCard(
                                senderName: sender.senderName,
                                balance: balance,
                                txCount: txCount,
                                isBalanceVisible: settingsVM.isBalanceVisible,
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
                              return _buildCashWalletRow(context, txVM, cashVM, settingsVM);
                            }

                            // 3. Paused Tracking Section Card (Fits screen width and contains paused cards inside)
                            if (index == activeCount + 1 &&
                                pausedSenders.isNotEmpty) {
                              return _buildPausedSection(
                                context,
                                txVM,
                                cashVM,
                                pausedSenders,
                              );
                            }

                            return const SizedBox.shrink();
                          },
                          childCount: txVM.activeSenders.length +
                              1 +
                              (txVM.pausedSenders.isNotEmpty ? 1 : 0),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedSection(
    BuildContext context,
    TransactionsViewModel txVM,
    CashWalletViewModel cashVM,
    List<AppSender> pausedSenders,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tappable Header Tile ────────────────────────────────────
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isPausedSectionExpanded = !_isPausedSectionExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  AppBadge.warning(
                    text: 'PAUSED TRACKING (${pausedSenders.length})',
                    icon: Icons.pause_circle_rounded,
                    size: AppBadgeSize.small,
                  ),
                  const Spacer(),
                  Text(
                    _isPausedSectionExpanded ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _isPausedSectionExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.65),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Paused Bank Cards Inside the Section Card ───────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _isPausedSectionExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: pausedSenders.map((sender) {
                        final double balance =
                            txVM.balanceForSender(sender.senderName, cashBalance: cashVM.cashBalance);
                        final int txCount =
                            txVM.txCountForSender(sender.senderName, cashTxCount: cashVM.cashTransactions.length);

                        return _WalletCard(
                          senderName: sender.senderName,
                          balance: balance,
                          txCount: txCount,
                          isBalanceVisible: false,
                          isPaused: true,
                          onTap: () {},
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCashWalletRow(
    BuildContext context,
    TransactionsViewModel txVM,
    CashWalletViewModel cashVM,
    SettingsViewModel settingsVM,
  ) {
    return _WalletCard(
      senderName: 'Cash Wallet',
      balance: txVM.balanceForSender('Cash Wallet', cashBalance: cashVM.cashBalance),
      txCount: txVM.txCountForSender('Cash Wallet', cashTxCount: cashVM.cashTransactions.length),
      isBalanceVisible: settingsVM.isBalanceVisible,
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
    final settingsVM = Provider.of<SettingsViewModel>(context);
    final pageOffset = settingsVM.pageOffset;

    // During any flight/transition between Home and Wallet (pageOffset < 0.98),
    // main_shell's overlay handles 100% of the flying cards with ZERO ghost cards underneath.
    // As soon as user arrives on Wallet Manager (pageOffset >= 0.98),
    // render the 100% real card widget in-tree.
    if (pageOffset < 0.98) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 172,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppRadius.cardRadius,
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
