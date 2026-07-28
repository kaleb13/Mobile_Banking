import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';

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

    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.38,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.62, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Top Drag Handle
              Center(
                child: InteractiveDragHandle(
                  color: Colors.grey.shade300,
                  onTap: () => Navigator.pop(context),
                  onVerticalDragUpdate: (details) {
                    if ((details.primaryDelta ?? 0) > 3) {
                      Navigator.pop(context);
                    }
                  },
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  children: [
                    // Dynamic Title listing Account / Sender Name
                    Center(
                      child: Text(
                        'Freeze $activeSenderName',
                        style: const TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Clear Subtitle description for complete account freezing
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Freezing $activeSenderName will completely stop Shibre from reading and processing bank messages for this account. You can unfreeze it at any time.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Single Bank Card Preview with 3D Horizontal Swipe Tilt Reaction
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: _InteractiveFrozenCardPreview(
                        senderName: activeSenderName,
                        balance: balance,
                        txCount: senderTxs.length,
                        isBalanceVisible: provider.isBalanceVisible,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Action Button: [ ❄ Freeze <Account Name> ]
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$activeSenderName account frozen!',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.bottomNavBg,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.ac_unit,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Freeze $activeSenderName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  const _InteractiveFrozenCardPreview({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
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
      imagePath = 'assets/images/CBE logo 1.png';
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('AHADU')) {
      imagePath = 'assets/images/Ahadu_Logo.png';
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
            child: Container(
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
                    color: baseGradient.first.withValues(alpha: 0.4),
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
          );
        },
      ),
    );
  }
}
