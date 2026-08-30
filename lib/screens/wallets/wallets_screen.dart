import 'dart:math' as math;
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

class _WalletsScreenState extends State<WalletsScreen>
    with SingleTickerProviderStateMixin {
  bool _isPausedSectionExpanded = false;
  bool _isReorderMode = false;
  late AnimationController _jiggleController;

  @override
  void initState() {
    super.initState();
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  void _enterReorderMode() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isReorderMode = true;
    });
    _jiggleController.forward(from: 0.0);
  }

  void _exitReorderMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isReorderMode = false;
    });
    _jiggleController.stop();
    _jiggleController.reset();
  }

  Widget _buildJiggleCard({required Widget child, required int index}) {
    return AnimatedBuilder(
      animation: _jiggleController,
      builder: (context, _) {
        if (_jiggleController.value == 0.0 || _jiggleController.value == 1.0) {
          return child;
        }
        final double phase = (index % 2 == 0) ? 1.0 : -1.0;
        final double rotation =
            math.sin(_jiggleController.value * 2 * math.pi) * 0.015 * phase;

        return Transform.rotate(
          angle: rotation,
          alignment: Alignment.center,
          child: child,
        );
      },
    );
  }

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
              // ── Header Title & Add New / Done Button ───────────────────────
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: AppHeader(
                    title: 'Wallet Manager',
                    showBackButton: false,
                    trailing: _isReorderMode
                        ? AppButton.primary(
                            text: 'Done',
                            icon: Icons.check_rounded,
                            fullWidth: false,
                            height: 28,
                            fontSize: 11.5,
                            iconSize: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            onPressed: _exitReorderMode,
                          )
                        : AppButton.primary(
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
                                subtitle:
                                    'Multi-bank linking feature is coming soon!',
                              );
                            },
                          ),
                  ),
                ),
              ),

              // ── Reorder Mode Instruction Pill ────────────────────────────
              if (_isReorderMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_vert_rounded,
                                size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 6),
                            Text(
                              'Drag cards to change order',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Wallet Cards List ─────────────────────────────────────────
              if (senders.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No wallets connected yet',
                    subtitle: 'Set up senders in Settings to get started',
                  ),
                )
              else ...[
                // 1. Bank Cards List (Draggable with Jiggle in Reorder Mode, Normal Scroll otherwise)
                if (_isReorderMode)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    sliver: SliverReorderableList(
                      itemCount: txVM.activeSenders.length,
                      onReorderStart: (index) {
                        HapticFeedback.heavyImpact();
                      },
                      onReorderEnd: (index) {
                        HapticFeedback.mediumImpact();
                      },
                      onReorder: (oldIndex, newIndex) {
                        HapticFeedback.selectionClick();
                        txVM.reorderActiveSenders(oldIndex, newIndex);
                      },
                      proxyDecorator: (child, index, animation) {
                        return AnimatedBuilder(
                          animation: animation,
                          builder: (context, child) {
                            final double animVal =
                                Curves.easeOutCubic.transform(animation.value);
                            return Material(
                              color: Colors.transparent,
                              elevation: 0,
                              child: Transform.scale(
                                scale: 1.0 + (0.04 * animVal),
                                child: child,
                              ),
                            );
                          },
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final activeSenders = txVM.activeSenders;
                        final sender = activeSenders[index];
                        final double balance = txVM.balanceForSender(
                            sender.senderName,
                            cashBalance: cashVM.cashBalance);
                        final int txCount = txVM.txCountForSender(
                            sender.senderName,
                            cashTxCount: cashVM.cashTransactions.length);
                        final allAccounts =
                            txVM.accountsForBank(sender.senderName);
                        final activeAccounts = allAccounts
                            .where((slot) => !txVM.isAccountPaused(
                                sender.senderName, slot))
                            .toList();
                        final int activeAccountCount = activeAccounts.length;
                        final bool cardBalanceVisible =
                            settingsVM.isBalanceVisible &&
                                !settingsVM
                                    .isBankBalanceHidden(sender.senderName);

                        final int topDeckIndex = activeSenders.isNotEmpty
                            ? (activeSenders.length.clamp(1, 3) - 1)
                            : -1;
                        final bool isTop = (index == topDeckIndex);

                        final bool isDark = BankCardWidget.isDarkTextTheme(
                            sender.senderName,
                            isTopCard: isTop);

                        return KeyedSubtree(
                          key: ValueKey(sender.senderName),
                          child: _buildJiggleCard(
                            index: index,
                            child: _WalletCard(
                              senderName: sender.senderName,
                              balance: balance,
                              txCount: txCount,
                              isBalanceVisible: cardBalanceVisible,
                              isPaused: false,
                              isTopCard: isTop,
                              accountCount: activeAccountCount,
                              dragHandle: ReorderableDragStartListener(
                                index: index,
                                child: BankCardDragHandle(
                                  isDarkTextTheme: isDark,
                                ),
                              ),
                              onTap: null,
                              onEnterReorderMode: _enterReorderMode,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final activeSenders = txVM.activeSenders;
                          final sender = activeSenders[index];
                          final int topDeckIndex = activeSenders.isNotEmpty
                              ? (activeSenders.length.clamp(1, 3) - 1)
                              : -1;
                          final bool isTop = (index == topDeckIndex);
                          final double balance = txVM.balanceForSender(
                              sender.senderName,
                              cashBalance: cashVM.cashBalance);
                          final int txCount = txVM.txCountForSender(
                              sender.senderName,
                              cashTxCount: cashVM.cashTransactions.length);
                          final allAccounts =
                              txVM.accountsForBank(sender.senderName);
                          final activeAccounts = allAccounts
                              .where((slot) => !txVM.isAccountPaused(
                                  sender.senderName, slot))
                              .toList();
                          final int activeAccountCount = activeAccounts.length;
                          final bool cardBalanceVisible =
                              settingsVM.isBalanceVisible &&
                                  !settingsVM
                                      .isBankBalanceHidden(sender.senderName);

                          return _WalletCard(
                            key: ValueKey(sender.senderName),
                            senderName: sender.senderName,
                            balance: balance,
                            txCount: txCount,
                            isBalanceVisible: cardBalanceVisible,
                            isPaused: false,
                            isTopCard: isTop,
                            accountCount: activeAccountCount,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SenderDetailScreen(sender: sender),
                              ),
                            ),
                            onEnterReorderMode: _enterReorderMode,
                          );
                        },
                        childCount: txVM.activeSenders.length,
                      ),
                    ),
                  ),

                // 2. Cash Wallet & Paused Tracking Section
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 140),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCashWalletRow(
                            context, txVM, cashVM, settingsVM),
                        if (txVM.pausedSenders.isNotEmpty)
                          _buildPausedSection(
                            context,
                            txVM,
                            cashVM,
                            txVM.pausedSenders,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paused Tracking (${pausedSenders.length})',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Tap to show or hide paused wallets',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isPausedSectionExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
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
                        final int accountCount =
                            txVM.accountsForBank(sender.senderName).length;

                        return _WalletCard(
                          senderName: sender.senderName,
                          balance: balance,
                          txCount: txCount,
                          isBalanceVisible: false,
                          isPaused: true,
                          accountCount: accountCount,
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
      accountCount: 1,
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
  final int accountCount;
  final VoidCallback? onTap;
  final VoidCallback? onEnterReorderMode;
  final bool isTopCard;
  final Widget? dragHandle;

  const _WalletCard({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    this.accountCount = 1,
    this.onTap,
    this.onEnterReorderMode,
    this.isTopCard = false,
    this.dragHandle,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsViewModel, bool>(
      selector: (_, vm) => vm.pageOffset < 0.98,
      builder: (context, isTransitioning, _) {
        // During any flight/transition between Home and Wallet (pageOffset < 0.98),
        // main_shell's overlay handles 100% of the flying cards with ZERO ghost cards underneath.
        // As soon as user arrives on Wallet Manager (pageOffset >= 0.98),
        // render the 100% real card widget in-tree.
        if (isTransitioning) {
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
          accountCount: accountCount,
          onTap: onTap,
          onEnterReorderMode: onEnterReorderMode,
          isTopCard: isTopCard,
          dragHandle: dragHandle,
          animationFactor: 1.0,
        );
      },
    );
  }
}
