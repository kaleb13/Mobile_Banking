import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/app_button.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: FreezeAccountBottomSheet(
          initialSenderName: senderName,
        ),
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

    return Container(
      decoration: BoxDecoration(
        color: context.themeBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Drag Handle
          Center(
            child: InteractiveDragHandle(
              color: context.themeBorder,
              onTap: () => Navigator.pop(context),
              padding: const EdgeInsets.only(bottom: 12),
            ),
          ),

          // Section 1: Title
          Center(
            child: Text(
              isPaused
                  ? '$activeSenderName Tracking Paused'
                  : 'Pause Tracking for $activeSenderName',
              style: TextStyle(
                color: context.themeTextPrimary,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),

          // Section 2: Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              isPaused
                  ? 'Tracking is currently paused for this bank. Tap "Resume Tracking" to re-enable SMS detection and recalculate balances.'
                  : 'Temporarily pause SMS transaction detection and automatic balance updates for this bank account.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.themeTextSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Section 3: 3D Bank Card Preview
          _InteractiveFrozenCardPreview(
            senderName: activeSenderName,
            balance: balance,
            txCount: senderTxs.length,
            isBalanceVisible: provider.isBalanceVisible,
            isPaused: isPaused,
          ),
          const SizedBox(height: 14),

          // Section 4: Info Section Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.themeSurface,
              borderRadius: BorderRadius.circular(20),
                          ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isPaused ? AppColors.brandGreen : AppColors.brandGreen)
                            .withValues(alpha: 0.15),
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
          const SizedBox(height: 18),

          // Section 5: Primary Action Button (Standardized Fully Rounded AppButton)
          AppButton.primary(
            text: isPaused
                ? 'Resume Tracking ($activeSenderName)'
                : 'Pause Tracking ($activeSenderName)',
            icon: isPaused
                ? Icons.play_circle_rounded
                : Icons.pause_circle_rounded,
            height: 52,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final String name = activeSenderName;
              final bool wasPaused = isPaused;

              // Pop the bottom sheet first so notifyListeners doesn't rebuild a deactivated context
              Navigator.pop(context);

              if (wasPaused) {
                await provider.resumeTracking(name);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$name tracking resumed'),
                    backgroundColor: AppColors.brandGreen,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                await provider.pauseTracking(name);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$name tracking paused'),
                    backgroundColor: AppColors.pausedBadge,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
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

  Widget _bankLogo(String name) {
    final nameUp = name.toUpperCase();
    String imagePath = '';

    if (nameUp == 'CBE') {
      imagePath = 'assets/images/CBE logo 1.webp';
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('AHADU')) {
      imagePath = 'assets/images/Ahadu_Logo.png';
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: 36,
        height: 36,
        fit: BoxFit.contain,
      );
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        width: 36,
        height: 36,
        fit: BoxFit.contain,
      );
    }

    return Icon(
      Icons.account_balance,
      color: Colors.white.withValues(alpha: 0.9),
      size: 34,
    );
  }

  String _subtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'TELEBIRR') return 'Ethio Telecom , E- money';
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr Mobile Wallet';
    if (n.contains('AHADU')) return 'Ahadu Bank S.C.';
    return 'Bank Account';
  }

  List<Color> _getCardGradient(String name) {
    final nameUp = name.toUpperCase();
    if (nameUp == 'TELEBIRR') {
      return [
        AppColors.success,
        AppColors.cardLime,
      ];
    } else if (nameUp == 'CBE') {
      return [
        AppColors.cardBrownDark,
        AppColors.cardBrownMid,
      ];
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      return [
        AppColors.cardCbeBirrSilver,
        AppColors.cardCbeBirrWhite,
      ];
    } else if (nameUp.contains('AHADU')) {
      return [
        AppColors.cardAhaduPink,
        AppColors.cardAhaduWhite,
      ];
    }
    return [
      AppColors.bgMid,
      AppColors.cardGrayLight,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final balStr =
        widget.isBalanceVisible ? fmt.format(widget.balance) : '****,***.**';
    final parts = balStr.split('.');

    final bool isDarkTextTheme = widget.senderName.toUpperCase().contains('AHADU') ||
        widget.senderName.toUpperCase() == 'CBE BIRR' ||
        widget.senderName.toUpperCase() == 'CBEBIRR';
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.65);

    final baseGradient = _getCardGradient(widget.senderName);

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
                    height: 165,
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: RadialGradient(
                        center: Alignment(centerX, 0.0),
                        radius: 1.8,
                        colors: [
                          baseGradient.first,
                          baseGradient.last,
                          baseGradient.first,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isPaused
                                  ? Colors.amber
                                  : baseGradient.first)
                              .withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: Offset(_rotY * 25, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _bankLogo(widget.senderName),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.senderName,
                                  style: TextStyle(
                                    color: textColorPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _subtitle(widget.senderName),
                                  style: TextStyle(
                                    color: textColorSub,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
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
                              ),
                            ),
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
                    Positioned(
                      top: 12,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pause_rounded,
                                color: Colors.white, size: 11),
                            SizedBox(width: 3),
                            Text(
                              'PAUSED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
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
