import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/finance_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/interactive_drag_handle.dart';
import '../../widgets/app_capsule_tab_bar.dart';

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
  int _selectedTab = 0; // 0: All SMS, 1: Deposit SMS Only, 2: Transfer SMS only

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
      initialChildSize: 0.74,
      minChildSize: 0.40,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.74, 0.94],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              // Top Drag Handle (matching Home Page Draggable Sheet)
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
                    MediaQuery.of(context).padding.bottom + 10,
                  ),
                  children: [
                    // Title
                    const Center(
                      child: Text(
                        'Freeze Account',
                        style: TextStyle(
                          color: AppColors.darkCharcoal,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Subtitle description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Manage how Shibre interacts with this bank account. You can completely freeze the account, stop reading all bank messages, or choose to read only specific message types, such as Deposit SMS Only or Transfer SMS only.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Tab Selector Row (All SMS, Deposit SMS Only, Transfer SMS only)
                    AppCapsuleTabBar(
                      tabs: const [
                        'All SMS',
                        'Deposit SMS Only',
                        'Transfer SMS only'
                      ],
                      selectedIndex: _selectedTab,
                      onTabChanged: (index) {
                        setState(() {
                          _selectedTab = index;
                        });
                      },
                      height: 40,
                      fontSize: 10,
                      borderRadius: 24,
                      indicatorRadius: 20,
                    ),
                    const SizedBox(height: 12),

                    // Single Bank Card Preview with 3D Swipe Tilt Reaction
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      child: _InteractiveFrozenCardPreview(
                        senderName: activeSenderName,
                        balance: balance,
                        txCount: senderTxs.length,
                        isBalanceVisible: provider.isBalanceVisible,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 3 Checked Information Rules based on selected tab
                    _buildCheckRulesList(),
                    const SizedBox(height: 18),

                    // Action Button: [ ❄ Freeze selected ones ]
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Freeze rules applied for $activeSenderName!',
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
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.ac_unit,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Freeze selected ones',
                              style: TextStyle(
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

  Widget _buildCheckRulesList() {
    // Determine check states based on _selectedTab
    // Tab 0 (All SMS): All 3 checked
    // Tab 1 (Deposit SMS Only): Only 'Don't read Deposit' checked
    // Tab 2 (Transfer SMS Only): Only 'Don't read Transfer' checked
    final bool checkDeposit = _selectedTab == 0 || _selectedTab == 1;
    final bool checkTransfer = _selectedTab == 0 || _selectedTab == 2;
    final bool checkAllNoMsg = _selectedTab == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildCheckRow("Don't read Deposit", checkDeposit),
          const SizedBox(height: 10),
          _buildCheckRow("Don't read Transfer", checkTransfer),
          const SizedBox(height: 10),
          _buildCheckRow("No Message what so ever", checkAllNoMsg),
        ],
      ),
    );
  }

  Widget _buildCheckRow(String text, bool isChecked) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: isChecked
              ? const Icon(
                  Icons.check_rounded,
                  color: AppColors.darkCharcoal,
                  size: 18,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: isChecked
                ? AppColors.darkCharcoal
                : Colors.grey.shade400,
            fontSize: 13,
            fontWeight: isChecked ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Tilting Card Preview with Moving Animated Shimmer Gradient
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  double _rotX = 0.0;
  double _rotY = 0.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
      onPanUpdate: (details) {
        setState(() {
          // Interactive 3D tilt reaction on swiping across the card
          _rotY = (_rotY + details.delta.dx * 0.005).clamp(-0.35, 0.35);
          _rotX = (_rotX - details.delta.dy * 0.005).clamp(-0.35, 0.35);
        });
      },
      onPanEnd: (_) {
        // Smooth spring back to resting flat state when swipe released
        setState(() {
          _rotX = 0.0;
          _rotY = 0.0;
        });
      },
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final t = _animController.value;
          
          // Infinite continuous rightward motion shift (-2.5 to +2.5)
          final centerX = -2.5 + (t * 5.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D Perspective
              ..rotateX(_rotX)
              ..rotateY(_rotY),
            transformAlignment: Alignment.center,
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
                    offset: Offset(_rotY * 20, _rotX * 20 + 6),
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
