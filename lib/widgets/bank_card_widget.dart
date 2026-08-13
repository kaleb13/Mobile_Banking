import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../screens/wallets/freeze_account_sheet.dart';

/// Single source-of-truth card widget used in both WalletsScreen list
/// and MainShell's flight overlay animation.
class BankCardWidget extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;
  final VoidCallback? onTap;
  /// Animation factor: 0.0 = Home stack deck state, 1.0 = full Wallet list card state.
  final double animationFactor;

  const BankCardWidget({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    this.onTap,
    this.animationFactor = 1.0,
  });

  static Widget bankLogo(String name, [double size = 34.0]) {
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
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA') {
      imagePath = 'assets/images/BOA_Logo.png';
    }

    if (imagePath.isNotEmpty) {
      return Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    if (nameUp == 'CASH WALLET') {
      return Icon(
        Icons.account_balance_wallet_outlined,
        color: Colors.white,
        size: size,
      );
    }

    return Icon(
      Icons.account_balance,
      color: Colors.white.withValues(alpha: 0.9),
      size: size,
    );
  }

  static String subtitle(String name) {
    final n = name.toUpperCase();
    if (n == 'TELEBIRR') return 'Ethio Telecom , E- money';
    if (n == 'CBE') return 'Commercial Bank of Ethiopia';
    if (n == 'CBE BIRR' || n == 'CBEBIRR') return 'CBE Birr Mobile Wallet';
    if (n.contains('AHADU')) return 'Ahadu Bank S.C.';
    if (n.contains('ABYSSINIA') || n == 'BOA') return 'Bank of Abyssinia S.C.';
    if (n == 'CASH WALLET') return 'Physical Cash Tracking';
    return 'Bank Account';
  }

  static List<Color> getCardGradient(String name) {
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
    } else if (nameUp == 'CASH WALLET') {
      return [
        AppColors.cardGrayDark,
        AppColors.cardGrayMid,
      ];
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA') {
      return [
        AppColors.cardBoaDarkIcon,
        AppColors.cardBoaBg,
      ];
    } else if (nameUp.contains('DASHEN')) {
      return [
        AppColors.cardDashenDarkIcon,
        AppColors.cardDashenBg,
      ];
    } else if (nameUp.contains('COOP')) {
      return [
        AppColors.cardCoopDarkIcon,
        AppColors.cardCoopBg,
      ];
    }
    return [
      AppColors.bgMid,
      AppColors.cardGrayLight,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = animationFactor.clamp(0.0, 1.0);
    final fmt = NumberFormat('#,##0.00');
    final balStr = isBalanceVisible ? fmt.format(balance) : '****,***.**';
    final parts = balStr.split('.');

    // When paused: use defined greyscale palette; otherwise use brand gradient
    final List<Color> cardGradient = isPaused
        ? [AppColors.pausedCardDark, AppColors.pausedCardMid]
        : getCardGradient(senderName);

    final bool isDarkTextTheme = !isPaused &&
        (senderName.toUpperCase().contains('AHADU') ||
            senderName.toUpperCase() == 'CBE BIRR' ||
            senderName.toUpperCase() == 'CBEBIRR');
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.6);

    // Early, smooth gradual fading as card moves between Home (t=0.0) and Wallet (t=1.0)
    final logoOpacity = (t / 0.15).clamp(0.0, 1.0);
    final titleOpacity = (t / 0.20).clamp(0.0, 1.0);
    final descriptionOpacity = ((t - 0.15) / 0.35).clamp(0.0, 1.0);
    final txCountOpacity = ((t - 0.15) / 0.50).clamp(0.0, 1.0);
    
    // Smooth button appearance calculation:
    // Button is hidden on Home deck (t < 0.60) to eliminate bottom overflow,
    // and smoothly expands height & fades in between t = 0.60 and t = 1.0
    final buttonProgress = ((t - 0.60) / 0.40).clamp(0.0, 1.0);
    final buttonOpacity = Curves.easeInOut.transform(buttonProgress);
    final buttonHeightFactor = Curves.easeOutCubic.transform(buttonProgress);

    final double logoSize = lerpDouble(22, 38, t)!;
    final double cardPadding = lerpDouble(10, 16, t)!;
    final double nameFontSize = lerpDouble(15, 17, t)!;
    final double balanceFontSize = lerpDouble(22, 28, t)!;
    final double decimalFontSize = lerpDouble(14, 18, t)!;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: isPaused
                  ? Border.all(
                      color: AppColors.pausedBorder,
                      width: 1.5,
                    )
                  : null,
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: cardGradient,
              ),
              boxShadow: isPaused
                  ? [
                      BoxShadow(
                        color: AppColors.pausedCardGlow.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: cardGradient.first.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.hardEdge,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                    // Top Row: Logo + Bank Title + Sub-description
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: logoOpacity,
                          child: bankLogo(senderName, logoSize),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Opacity(
                            opacity: titleOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  senderName.toUpperCase().contains('AHADU')
                                      ? 'Ahadu Bank'
                                      : senderName,
                                  style: TextStyle(
                                    color: textColorPrimary,
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Opacity(
                                  opacity: descriptionOpacity,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 1),
                                    child: Text(
                                      isPaused
                                          ? 'Tracking paused — tap card to view history'
                                          : subtitle(senderName),
                                      style: TextStyle(
                                        color: textColorSub,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: lerpDouble(2, 8, t)!),

                    // Large Balance Display (Integer + Decimals)
                    Opacity(
                      opacity: titleOpacity,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            parts[0],
                            style: TextStyle(
                              color: textColorPrimary,
                              fontSize: balanceFontSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '.${parts[1]}',
                            style: TextStyle(
                              color: isDarkTextTheme
                                  ? AppColors.darkCharcoal
                                      .withValues(alpha: 0.5)
                                  : Colors.white.withValues(alpha: 0.65),
                              fontSize: decimalFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Subtitle: Transaction Count
                    Opacity(
                      opacity: txCountOpacity,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$txCount total Transactions',
                          style: TextStyle(
                            color: textColorSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),

                    // Pause / Resume Button (Excluding Cash Wallet) — Left Aligned
                    if (senderName.toUpperCase() != 'CASH WALLET')
                      ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          heightFactor: buttonHeightFactor,
                          child: Opacity(
                            opacity: buttonOpacity,
                            child: IgnorePointer(
                              ignoring: buttonProgress < 0.8,
                              child: Padding(
                                padding: EdgeInsets.only(
                                    top: lerpDouble(0, 8, buttonProgress)!),
                                child: FreezeAccountGlassButton(
                                  senderName: senderName,
                                  balance: balance,
                                  txCount: txCount,
                                  isBalanceVisible: isBalanceVisible,
                                  isDarkTextTheme: isDarkTextTheme,
                                  isPaused: isPaused,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),

          // ── PAUSED badge in top-right corner ──────────────────────
          if (isPaused)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.pausedBadge,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pause_rounded,
                        color: AppColors.pausedBadgeText, size: 11),
                    SizedBox(width: 4),
                    Text(
                      'PAUSED',
                      style: TextStyle(
                        color: AppColors.pausedBadgeText,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable Glassmorphic Pause/Resume Tracking Button Component
class FreezeAccountGlassButton extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isDarkTextTheme;
  final bool isPaused;

  const FreezeAccountGlassButton({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isDarkTextTheme,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isPaused
        ? AppColors.pausedBadge.withValues(alpha: 0.25)
        : isDarkTextTheme
            ? AppColors.darkCharcoal.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.12);

    final Color borderColor = isPaused
        ? AppColors.pausedBorder.withValues(alpha: 0.55)
        : isDarkTextTheme
            ? AppColors.darkCharcoal.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.18);

    final Color iconColor = isPaused
        ? AppColors.pausedBorder
        : isDarkTextTheme
            ? AppColors.darkCharcoal
            : Colors.white;

    final Color textColor = isPaused
        ? AppColors.pausedBorder
        : isDarkTextTheme
            ? AppColors.darkCharcoal
            : Colors.white;

    final Color subTextColor = isPaused
        ? AppColors.pausedBorder.withValues(alpha: 0.7)
        : isDarkTextTheme
            ? AppColors.darkCharcoal.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () {
        FreezeAccountBottomSheet.show(
          context,
          senderName: senderName,
          balance: balance,
          txCount: txCount,
          isBalanceVisible: isBalanceVisible,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaused
                  ? Icons.play_circle_outline_rounded
                  : Icons.pause_circle_outline_rounded,
              color: iconColor,
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaused ? 'Resume Tracking' : 'Pause Tracking',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isPaused
                        ? 'TAP TO RESUME SMS TRACKING'
                        : 'PAUSE SMS AUTO-TRACKING',
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 5.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
