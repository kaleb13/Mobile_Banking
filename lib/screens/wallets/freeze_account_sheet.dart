import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_badges.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bank_card_widget.dart';

class FreezeAccountBottomSheet extends StatefulWidget {
  final String initialSenderName;

  const FreezeAccountBottomSheet({
    super.key,
    required this.initialSenderName,
  });

  static void show(
    BuildContext context, {
    required String senderName,
    required double balance,
    required int txCount,
    required bool isBalanceVisible,
  }) {
    AppDrawer.show(
      context: context,
      builder: (_) => FreezeAccountBottomSheet(
        initialSenderName: senderName,
      ),
    );
  }

  @override
  State<FreezeAccountBottomSheet> createState() => _FreezeAccountBottomSheetState();
}

class _FreezeAccountBottomSheetState extends State<FreezeAccountBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    final txs = provider.transactions;

    final String activeSenderName = widget.initialSenderName;
    final senderTxs = txs
        .where((t) => t.name.toUpperCase() == activeSenderName.toUpperCase())
        .toList();

    double balance = 0;
    final withBal = senderTxs.where((t) => t.totalBalance > 0);
    if (withBal.isNotEmpty) {
      balance = withBal.first.totalBalance;
    }

    final bool isPaused = provider.isTrackingPaused(activeSenderName);

    return AppDrawer(
      headerCard: AppDrawerHeaderCard(
        icon: isPaused ? Icons.pause_circle_rounded : Icons.pause_circle_outline_rounded,
        iconColor: isPaused ? AppColors.warning : AppColors.brandGreen,
        title: isPaused
            ? '$activeSenderName Tracking Paused'
            : 'Pause Tracking for $activeSenderName',
        subtitle: isPaused
            ? 'Tracking is currently paused. Tap below to resume.'
            : 'Temporarily pause SMS detection and balance updates.',
      ),
      bottomAction: AppButton.primary(
        text: isPaused
            ? 'Resume Tracking ($activeSenderName)'
            : 'Pause Tracking ($activeSenderName)',
        icon: isPaused
            ? Icons.play_circle_rounded
            : Icons.pause_circle_rounded,
        height: 50,
        onPressed: () async {
          final String name = activeSenderName;
          final bool wasPaused = isPaused;

          Navigator.pop(context);

          if (wasPaused) {
            await provider.resumeTracking(name);
            if (context.mounted) {
              AppToast.success(
                context,
                message: '$name Tracking Resumed',
                subtitle: 'SMS auto-detection & balance updates are active',
                details: 'Automated SMS detection and analytics tracking for $name have been re-enabled in real time.',
                metadata: {
                  'Account': name,
                  'Status': 'Active',
                },
              );
            }
          } else {
            await provider.pauseTracking(name);
            if (context.mounted) {
              AppToast.warning(
                context,
                message: '$name Tracking Paused',
                subtitle: 'SMS auto-detection & notifications are silenced',
                details: 'Tracking and transaction notifications for $name are temporarily paused. Existing history is safely preserved.',
                metadata: {
                  'Account': name,
                  'Status': 'Paused',
                },
              );
            }
          }
        },
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: 3D Bank Card Preview
          _InteractiveFrozenCardPreview(
            senderName: activeSenderName,
            balance: balance,
            txCount: senderTxs.length,
            isBalanceVisible: provider.isBalanceVisible,
            isPaused: isPaused,
          ),
          const SizedBox(height: 14),

          // Section 2: Info Section Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.drawerCard,
              borderRadius: AppRadius.cardRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPaused
                            ? Icons.pause_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        color: AppColors.brandGreen,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isPaused ? 'Currently paused' : 'What happens when paused?',
                      style: TextStyle(
                        color: context.themeTextPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoBullet(
                    context,
                    isPaused
                        ? 'New bank SMS messages from $activeSenderName are currently being ignored.'
                        : 'Incoming bank SMS messages will not be parsed into transactions.'),
                const SizedBox(height: 6),
                _buildInfoBullet(
                    context,
                    isPaused
                        ? '$activeSenderName balance and transactions are excluded from all totals.'
                        : 'Balance updates and spending analytics will temporarily pause.'),
                const SizedBox(height: 6),
                _buildInfoBullet(context, 'All existing transactions and history remain 100% safe & untouched.'),
                const SizedBox(height: 6),
                _buildInfoBullet(
                    context,
                    isPaused
                        ? 'Tap "Resume Tracking" to bring $activeSenderName back into calculations.'
                        : 'You can resume tracking at any time with a single tap.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBullet(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: context.themeTextSecondary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.themeTextSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Tilting Card Preview with Moving Animated Shimmer Gradient & Horizontal Spin
// ─────────────────────────────────────────────────────────────────────────────
class _InteractiveFrozenCardPreview extends StatefulWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;

  const _InteractiveFrozenCardPreview({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
  });

  @override
  State<_InteractiveFrozenCardPreview> createState() =>
      __InteractiveFrozenCardPreviewState();
}

class __InteractiveFrozenCardPreviewState
    extends State<_InteractiveFrozenCardPreview>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double _rotY = 0.0;
  double _startRotY = 0.0;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _resetAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );

    _resetController.addListener(() {
      setState(() {
        _rotY = _resetAnimation.value;
      });
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _resetController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_resetController.isAnimating) {
      _resetController.stop();
    }
    setState(() {
      // Swiping left (negative delta) tilts left side back (shrinks left edge)
      // Swiping right (positive delta) tilts right side back (shrinks right edge)
      _rotY = (_rotY + details.primaryDelta! * 0.0035).clamp(-0.45, 0.45);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _resetSpringBack();
  }

  void _onHorizontalDragCancel() {
    _resetSpringBack();
  }

  void _resetSpringBack() {
    _startRotY = _rotY;
    _resetAnimation = Tween<double>(begin: _startRotY, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final balStr = (widget.isBalanceVisible && !widget.isPaused)
        ? fmt.format(widget.balance)
        : '••••••••';
    final parts = balStr.contains('.') ? balStr.split('.') : [balStr, ''];

    final bool isDarkTextTheme = BankCardWidget.isDarkTextTheme(
        widget.senderName,
        isPaused: widget.isPaused);
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    final List<Color> cardGradient = widget.isPaused
        ? [AppColors.pausedCardDark, AppColors.pausedCardMid]
        : BankCardWidget.getCardGradient(widget.senderName);

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          final t = _shimmerController.value;
          
          // Continuous rightward shimmer motion
          final centerX = -2.5 + (t * 5.0);

          return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018) // 3D Perspective intensity
                ..rotateY(_rotY),
              alignment: Alignment.center,
              child: Stack(
                children: [
                  Container(
                    height: 172,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.cardRadius,
                      gradient: RadialGradient(
                        center: Alignment(centerX, 0.0),
                        radius: 1.8,
                        colors: [
                          cardGradient.first,
                          cardGradient.last,
                          cardGradient.first,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            BankCardWidget.bankLogo(
                              widget.senderName,
                              36,
                              isDarkTextTheme
                                  ? AppColors.darkCharcoal
                                  : Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.senderName.toUpperCase().contains('AHADU')
                                        ? 'Ahadu Bank'
                                        : widget.senderName,
                                    style: TextStyle(
                                      color: textColorPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    widget.isPaused
                                        ? 'Tracking paused — tap card to view history'
                                        : BankCardWidget.subtitle(widget.senderName),
                                    style: TextStyle(
                                      color: textColorSub,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              parts[0],
                              style: TextStyle(
                                color: textColorPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: widget.isBalanceVisible ? -0.6 : 1.5,
                              ),
                            ),
                            if (parts[1].isNotEmpty)
                              Text(
                                '.${parts[1]}',
                                style: TextStyle(
                                  color: textColorSub,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.txCount} total Transactions',
                          style: TextStyle(
                            color: textColorSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // PAUSED badge overlay
                  if (widget.isPaused)
                    const Positioned(
                      top: 12,
                      right: 14,
                      child: AppBadge.warning(
                        text: 'PAUSED',
                        icon: Icons.pause_rounded,
                        size: AppBadgeSize.small,
                      ),
                    ),
                ],
              ),
            );
        },
      ),
    );
  }
}
