import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sender.dart';
import '../presentation/viewmodels/transactions_view_model.dart';
import '../presentation/viewmodels/cash_wallet_view_model.dart';
import '../presentation/viewmodels/settings_view_model.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badges.dart';
import '../widgets/bank_card_widget.dart';
import '../screens/dashboard/sender_detail_screen.dart';
import '../screens/dashboard/analysis_screen.dart';
import 'app_button.dart';
import 'app_toast.dart';

/// Modal dialog inspired by iOS Focus Mode UI, presenting a heroic
/// bank card at the top followed by rounded pill secondary action buttons.
class BankCardActionModal extends StatefulWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;

  const BankCardActionModal({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
  });

  /// Displays the focus-mode style action modal.
  static Future<T?> show<T>(
    BuildContext context, {
    required String senderName,
    required double balance,
    required int txCount,
    required bool isBalanceVisible,
    required bool isPaused,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BankCardActionModal',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 380),
      pageBuilder: (context, anim1, anim2) => BankCardActionModal(
        senderName: senderName,
        balance: balance,
        txCount: txCount,
        isBalanceVisible: isBalanceVisible,
        isPaused: isPaused,
      ),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 20 * curved.value,
            sigmaY: 20 * curved.value,
          ),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<BankCardActionModal> createState() => _BankCardActionModalState();
}

class _BankCardActionModalState extends State<BankCardActionModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _cardScaleAnim;
  late Animation<double> _cardOpacityAnim;
  bool _isAccountsExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );

    _cardScaleAnim = Tween<double>(begin: 0.93, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _cardOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  AppSender? _findSender(TransactionsViewModel txVM) {
    try {
      return txVM.senders.firstWhere(
        (s) => s.senderName.toUpperCase() == widget.senderName.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final txVM = Provider.of<TransactionsViewModel>(context);
    final cashVM = Provider.of<CashWalletViewModel>(context);
    final settingsVM = Provider.of<SettingsViewModel>(context);

    final bool isBankHidden = settingsVM.isBankBalanceHidden(widget.senderName);
    final bool effectiveBalanceVisible = !isBankHidden;
    final bool currentPaused = txVM.isTrackingPaused(widget.senderName);
    final double liveBalance = txVM.balanceForSender(widget.senderName, cashBalance: cashVM.cashBalance);
    final int liveTxCount = txVM.txCountForSender(widget.senderName, cashTxCount: cashVM.cashTransactions.length);
    final sender = _findSender(txVM);

    final accounts = txVM.accountsForBank(widget.senderName);
    final bool hasMultipleAccounts = accounts.length > 1;
    final int activeAccountCount =
        accounts.where((slot) => !txVM.isAccountPaused(widget.senderName, slot)).length;

    final activeSenders = txVM.activeSenders;
    final int topDeckIndex = activeSenders.isNotEmpty
        ? (activeSenders.length.clamp(1, 3) - 1)
        : -1;
    final int senderIndex = activeSenders.indexWhere(
        (s) => s.senderName.toUpperCase() == widget.senderName.toUpperCase());
    final bool isTopCard =
        (senderIndex >= 0 && senderIndex == topDeckIndex);
    final bool isDarkTextTheme =
        BankCardWidget.isDarkTextTheme(widget.senderName, isTopCard: isTopCard, isPaused: currentPaused);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Tap outside to dismiss
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox.expand(),
              ),
            ),

            // Modal Content Center/Bottom
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Section 1: Hero Bank Card with Close 'x' button inside top-right
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _cardOpacityAnim.value,
                          child: Transform.scale(
                            scale: _cardScaleAnim.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.cardRadius,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            BankCardWidget(
                              senderName: widget.senderName,
                              balance: liveBalance,
                              txCount: liveTxCount,
                              isBalanceVisible: effectiveBalanceVisible,
                              isPaused: currentPaused,
                              isTopCard: isTopCard,
                              accountCount: activeAccountCount,
                              animationFactor: 1.0,
                              showMoreButton: false, // Don't show nested 3-dot inside modal
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: _CloseModalButton(
                                isDarkTextTheme: isDarkTextTheme,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Action Pills List (Staggered Waterfall Reveal Animation)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Pause / Resume Tracking Action(s)
                        if (!hasMultipleAccounts)
                          _StaggeredRevealPill(
                            controller: _animController,
                            startInterval: 0.12,
                            endInterval: 0.54,
                            child: _FocusActionPill(
                              icon: currentPaused
                                  ? Icons.play_circle_rounded
                                  : Icons.pause_circle_rounded,
                              title: currentPaused
                                  ? 'Resume Tracking'
                                  : 'Pause Tracking',
                              subtitle: currentPaused
                                  ? 'Resume automated SMS sync & alerts'
                                  : 'Silence SMS detection & updates',
                              trailing: currentPaused
                                  ? const AppBadge.warning(
                                      text: 'PAUSED',
                                      icon: Icons.pause_rounded,
                                      size: AppBadgeSize.small,
                                    )
                                  : const AppBadge.success(
                                      text: 'ACTIVE',
                                      icon: Icons.check_circle_rounded,
                                      size: AppBadgeSize.small,
                                    ),
                              onTap: () async {
                                HapticFeedback.lightImpact();
                                final nav = Navigator.of(context);
                                final name = widget.senderName;
                                final wasPaused = currentPaused;

                                nav.pop();

                                if (wasPaused) {
                                  await txVM.resumeTracking(name);
                                  if (context.mounted) {
                                    AppToast.success(
                                      context,
                                      message: '$name Tracking Resumed',
                                      subtitle: 'SMS auto-detection & balance updates are active',
                                      details: 'Automated SMS parsing and balance sync for $name have been re-enabled in real time.',
                                      metadata: {
                                        'Account': name,
                                        'Status': 'Active',
                                      },
                                    );
                                  }
                                } else {
                                  await txVM.pauseTracking(name);
                                  if (context.mounted) {
                                    AppToast.warning(
                                      context,
                                      message: '$name Tracking Paused',
                                      subtitle: 'SMS auto-detection & notifications are silenced',
                                      details: 'Tracking and transaction alerts for $name are temporarily paused. Existing transactions remain untouched.',
                                      metadata: {
                                        'Account': name,
                                        'Status': 'Paused',
                                      },
                                    );
                                  }
                                }
                              },
                            ),
                          )
                        else
                          _StaggeredRevealPill(
                            controller: _animController,
                            startInterval: 0.12,
                            endInterval: 0.54,
                            child: _buildMultiAccountPauseSection(
                              context,
                              txVM,
                              accounts,
                            ),
                          ),

                        const SizedBox(height: 10),

                        // 2. Change Order Action Pill
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.36,
                          endInterval: 0.78,
                          child: _FocusActionPill(
                            icon: Icons.swap_vert_rounded,
                            title: 'Change Order',
                            subtitle: 'Rearrange position of wallet cards',
                            trailing: const AppBadge.neutral(
                              text: 'REORDER',
                              size: AppBadgeSize.small,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop('changeOrder');
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 4. Transaction History Action Pill
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.46,
                          endInterval: 0.88,
                          child: _FocusActionPill(
                            icon: Icons.receipt_long_rounded,
                            title: 'Transaction History',
                            subtitle: 'View statement & $liveTxCount transactions',
                            trailing: AppBadge.neutral(
                              text: '$liveTxCount tx',
                              size: AppBadgeSize.small,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final nav = Navigator.of(context);
                              nav.pop();
                              if (sender != null) {
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SenderDetailScreen(sender: sender),
                                  ),
                                );
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 5. Spending Analytics & Insights Action Pill
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.56,
                          endInterval: 0.98,
                          child: _FocusActionPill(
                            icon: Icons.insights_rounded,
                            title: 'Spending Analytics & Insights',
                            subtitle: 'Category breakdown, cashflow & net trends',
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: AppColors.textDisabled,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final nav = Navigator.of(context);
                              nav.pop();
                              nav.push(
                                MaterialPageRoute(
                                  builder: (_) => AnalysisScreen(
                                    initialBankFilter: widget.senderName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiAccountPauseSection(
    BuildContext context,
    TransactionsViewModel txVM,
    List<int> accounts,
  ) {
    final bool allPaused =
        accounts.every((slot) => txVM.isAccountPaused(widget.senderName, slot));
    final bool anyPaused =
        accounts.any((slot) => txVM.isAccountPaused(widget.senderName, slot));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: !_isAccountsExpanded
          ? _FocusActionPill(
              key: const ValueKey('collapsed_pause_pill'),
              icon: allPaused
                  ? Icons.play_circle_rounded
                  : Icons.pause_circle_rounded,
              title: allPaused ? 'Resume Tracking' : 'Pause Tracking',
              subtitle: 'SIM 1 & SIM 2 separate controls',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allPaused)
                    const AppBadge.warning(
                      text: 'PAUSED',
                      icon: Icons.pause_rounded,
                      size: AppBadgeSize.small,
                    )
                  else if (anyPaused)
                    const AppBadge.warning(
                      text: '1 PAUSED',
                      size: AppBadgeSize.small,
                    )
                  else
                    const AppBadge.success(
                      text: 'ACTIVE',
                      icon: Icons.check_circle_rounded,
                      size: AppBadgeSize.small,
                    ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isAccountsExpanded = true;
                });
              },
            )
          : SizedBox(
              key: const ValueKey('expanded_pause_pill'),
              height: 48,
              child: Row(
                children: [
                  for (int i = 0; i < accounts.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AppButton.secondary(
                        fullWidth: false,
                        text: txVM.isAccountPaused(widget.senderName, accounts[i])
                            ? 'Resume SIM ${accounts[i] + 1}'
                            : 'Pause SIM ${accounts[i] + 1}',
                        icon: txVM.isAccountPaused(widget.senderName, accounts[i])
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        height: 48,
                        fontSize: 11.5,
                        iconSize: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        onPressed: () =>
                            _handleAccountToggle(context, txVM, accounts[i]),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isAccountsExpanded = false;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.buttonSecondary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_left_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _handleAccountToggle(
    BuildContext context,
    TransactionsViewModel txVM,
    int slot,
  ) async {
    HapticFeedback.lightImpact();
    final nav = Navigator.of(context);
    final name = widget.senderName;
    final bool wasPaused = txVM.isAccountPaused(name, slot);
    final String simTitle = 'SIM ${slot + 1}';

    nav.pop();
    await txVM.toggleAccountPause(name, slot);

    if (context.mounted) {
      if (wasPaused) {
        AppToast.success(
          context,
          message: '$name $simTitle Resumed',
          subtitle: 'SMS auto-detection is active for $simTitle',
        );
      } else {
        AppToast.warning(
          context,
          message: '$name $simTitle Paused',
          subtitle: 'SMS auto-detection silenced for $simTitle',
        );
      }
    }
  }
}

/// Frosted Close Button inside top-right of Card (shares BankCardGlassActionButton style)
class _CloseModalButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDarkTextTheme;

  const _CloseModalButton({
    required this.onTap,
    this.isDarkTextTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    return BankCardGlassActionButton(
      icon: Icons.close_rounded,
      isDarkTextTheme: isDarkTextTheme,
      onTap: onTap,
    );
  }
}

/// 100% Fully Rounded Pill Action Button (iOS Focus Mode style)
class _FocusActionPill extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _FocusActionPill({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  State<_FocusActionPill> createState() => _FocusActionPillState();
}

class _FocusActionPillState extends State<_FocusActionPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.22)
                : AppColors.buttonSecondary,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            children: [
              // Clean, Filled Pure White Icon without background box
              Icon(
                widget.icon,
                color: Colors.white,
                size: 24,
              ),

              const SizedBox(width: 14),

              // Title and Subtitle Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Trailing Widget
              widget.trailing,
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper wrapper that reveals each action pill in sequence from the top,
/// stretching downward into place with spring-like cubic easing.
class _StaggeredRevealPill extends StatelessWidget {
  final Animation<double> controller;
  final double startInterval;
  final double endInterval;
  final Widget child;

  const _StaggeredRevealPill({
    required this.controller,
    required this.startInterval,
    required this.endInterval,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(startInterval, endInterval, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final val = animation.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            // Emerges smoothly from directly underneath the top card
            offset: Offset(0, (1.0 - val) * -26),
            child: Transform.scale(
              // Stretches downward vertically as it settles into place
              scaleY: 0.68 + (0.32 * val),
              scaleX: 0.93 + (0.07 * val),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
