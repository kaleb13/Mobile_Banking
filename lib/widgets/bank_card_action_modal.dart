import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sender.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_badges.dart';
import '../widgets/bank_card_widget.dart';
import '../screens/dashboard/manage_bank_screen.dart';
import '../screens/dashboard/sender_detail_screen.dart';
import '../screens/dashboard/analysis_screen.dart';
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

  AppSender? _findSender(FinanceProvider provider) {
    try {
      return provider.senders.firstWhere(
        (s) => s.senderName.toUpperCase() == widget.senderName.toUpperCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final bool currentPaused = provider.isTrackingPaused(widget.senderName);
    final double liveBalance = provider.balanceForSender(widget.senderName);
    final int liveTxCount = provider.txCountForSender(widget.senderName);
    final sender = _findSender(provider);

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
                          borderRadius: BorderRadius.circular(22),
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
                              isBalanceVisible: widget.isBalanceVisible,
                              isPaused: currentPaused,
                              animationFactor: 1.0,
                              showMoreButton: false, // Don't show nested 3-dot inside modal
                            ),
                            Positioned(
                              top: 10,
                              right: 10,
                              child: _CloseModalButton(
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
                        // 1. Pause / Resume Tracking Action Pill (Fires first)
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
                                await provider.resumeTracking(name);
                                if (context.mounted) {
                                  AppToast.success(
                                    context,
                                    message: '$name Tracking Resumed',
                                    subtitle: 'SMS auto-detection & balance updates are active',
                                  );
                                }
                              } else {
                                await provider.pauseTracking(name);
                                if (context.mounted) {
                                  AppToast.warning(
                                    context,
                                    message: '$name Tracking Paused',
                                    subtitle: 'SMS auto-detection & notifications are silenced',
                                  );
                                }
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 2. Bank Credentials & Setup Action Pill (Fires second)
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.26,
                          endInterval: 0.68,
                          child: _FocusActionPill(
                            icon: Icons.account_balance_rounded,
                            title: 'Bank Details & Credentials',
                            subtitle: 'Account number & SIM card linkage',
                            trailing: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: AppColors.textDisabled,
                            ),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final nav = Navigator.of(context);
                              nav.pop();
                              if (sender != null) {
                                nav.push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ManageBankScreen(sender: sender),
                                  ),
                                );
                              } else {
                                if (context.mounted) {
                                  AppToast.error(
                                    context,
                                    message: 'Bank Settings Unavailable',
                                    subtitle: 'Could not load credentials for this wallet',
                                  );
                                }
                              }
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 3. Transaction History Action Pill (Fires third)
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.40,
                          endInterval: 0.82,
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

                        // 4. Spending Analytics & Insights Action Pill (Fires fourth)
                        _StaggeredRevealPill(
                          controller: _animController,
                          startInterval: 0.54,
                          endInterval: 0.96,
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
                                  builder: (_) => const AnalysisScreen(),
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
}

/// Frosted Close Button inside top-right of Card
class _CloseModalButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseModalButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close_rounded,
          color: Colors.white,
          size: 16,
        ),
      ),
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
