import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../screens/wallets/freeze_account_sheet.dart';
import 'app_badges.dart';
import 'bank_card_action_modal.dart';
import 'currency_symbol_widget.dart';

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
  /// Whether to display the top-right three-dot menu button.
  final bool showMoreButton;

  const BankCardWidget({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    this.onTap,
    this.animationFactor = 1.0,
    this.showMoreButton = true,
  });

  static Widget bankLogo(String name, [double size = 34.0, Color? iconColor]) {
    final nameUp = name.toUpperCase();
    String imagePath = '';

    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL BANK') || nameUp.contains('COMMERCIAL')) {
      return SvgPicture.asset(
        'assets/images/CBE logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else if (nameUp == 'TELEBIRR') {
      imagePath = 'assets/images/Telebirr Logo.png';
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      imagePath = 'assets/images/CBEBirr Logo.png';
    } else if (nameUp.contains('AHADU')) {
      return SvgPicture.asset(
        'assets/images/Ahadu_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          iconColor ?? Colors.white,
          BlendMode.srcIn,
        ),
      );
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      return SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          iconColor ?? Colors.white,
          BlendMode.srcIn,
        ),
      );
    } else if (nameUp.contains('DASHEN')) {
      return SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          iconColor ?? Colors.white,
          BlendMode.srcIn,
        ),
      );
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
      return SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          iconColor ?? Colors.white,
          BlendMode.srcIn,
        ),
      );
    } else if (nameUp == 'LOAN TRACKER' || nameUp == 'LOANS' || nameUp == 'LOAN') {
      return Icon(
        Icons.handshake_rounded,
        color: iconColor ?? Colors.white,
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
    if (n.contains('DASHEN')) return 'Dashen Bank S.C.';
    if (n == 'CASH WALLET') return 'Physical Cash Tracking';
    if (n == 'LOAN TRACKER' || n == 'LOANS' || n == 'LOAN') return 'Personal Debt & Loan Ledger';
    return 'Bank Account';
  }

  static List<Color> getCardGradient(String name) {
    final nameUp = name.toUpperCase();
    if (nameUp == 'TELEBIRR') {
      return [
        AppColors.success,
        AppColors.cardLime,
      ];
    } else if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL')) {
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
        AppColors.cardAhaduRedDark,
        AppColors.cardAhaduRedLight,
      ];
    } else if (nameUp == 'CASH WALLET' || nameUp == 'CASH') {
      return [
        AppColors.cardGrayDark,
        AppColors.cardGrayMid,
      ];
    } else if (nameUp == 'LOAN TRACKER' || nameUp == 'LOANS' || nameUp == 'LOAN') {
      return [
        AppColors.surfaceElevated,
        AppColors.tealDark,
      ];
    } else if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA') {
      return [
        AppColors.cardBoaDarkIcon,
        AppColors.cardBoaBg,
      ];
    } else if (nameUp.contains('DASHEN')) {
      return [
        AppColors.cardDashenLight,
        AppColors.cardDashenDark,
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

  static bool isDarkTextTheme(String name, {bool isPaused = false}) {
    if (isPaused) return false;
    final nameUp = name.toUpperCase();
    return nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR';
  }

  @override
  Widget build(BuildContext context) {
    final t = animationFactor.clamp(0.0, 1.0);
    final fmt = NumberFormat('#,##0.00');
    final balStr = (isBalanceVisible && !isPaused) ? fmt.format(balance) : '••••••••';
    final parts = balStr.contains('.') ? balStr.split('.') : [balStr, ''];

    // When paused: use defined greyscale palette; otherwise use brand gradient
    final List<Color> cardGradient = isPaused
        ? [AppColors.pausedCardDark, AppColors.pausedCardMid]
        : getCardGradient(senderName);

    final bool isDarkTextTheme =
        BankCardWidget.isDarkTextTheme(senderName, isPaused: isPaused);
    final Color textColorPrimary =
        isDarkTextTheme ? AppColors.darkCharcoal : Colors.white;
    final Color textColorSub = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

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

    final double logoSize = lerpDouble(24, 40, t)!;
    final double cardPadding = lerpDouble(12, 18, t)!;
    final double nameFontSize = lerpDouble(15, 17.5, t)!;
    final double balanceFontSize = lerpDouble(22, 29, t)!;
    final double decimalFontSize = lerpDouble(14, 18.5, t)!;

    // Drop shadow is strictly ONLY present when stacked on the Home deck (t <= 0.01).
    // In the wallet manager (t = 1.0) or during flight (on the way), cards have zero shadow.
    final bool hasHomeShadow = t <= 0.01;
    final List<BoxShadow> cardShadows = hasHomeShadow
        ? (isPaused
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
              ])
        : const [];

    return GestureDetector(
      onTap: isPaused ? null : onTap,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: cardGradient,
              ),
              boxShadow: cardShadows,
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
                      child: bankLogo(senderName, logoSize, isDarkTextTheme ? AppColors.darkCharcoal : Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: titleOpacity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
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
                                ),
                                if (isPaused) ...[
                                  const SizedBox(width: 8),
                                  const AppBadge.warning(
                                    text: 'PAUSED',
                                    icon: Icons.pause_rounded,
                                    size: AppBadgeSize.small,
                                  ),
                                ],
                              ],
                            ),
                            Opacity(
                              opacity: descriptionOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Text(
                                  isPaused
                                      ? 'Tracking paused'
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

                // Large Balance Display (Integer + Decimals - Auto-scales down for high amounts)
                Opacity(
                  opacity: titleOpacity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: parts[0],
                                style: TextStyle(
                                  color: textColorPrimary,
                                  fontSize: balanceFontSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: isBalanceVisible ? -0.6 : 1.5,
                                  height: 1.0,
                                ),
                              ),
                              if (parts[1].isNotEmpty)
                                TextSpan(
                                  text: '.${parts[1]}',
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
                          maxLines: 1,
                        ),
                        if (isBalanceVisible && !isPaused) ...[
                          const SizedBox(width: 5),
                          CurrencySymbolWidget(
                            color: textColorPrimary,
                            size: decimalFontSize + 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Subtitle: Transaction Count
                Opacity(
                  opacity: txCountOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isPaused
                          ? '$txCount saved Transactions'
                          : '$txCount total Transactions',
                      style: TextStyle(
                        color: textColorSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Three-Dot Action Menu in top-right corner ────────────
          if (showMoreButton && senderName.toUpperCase() != 'CASH WALLET')
            Positioned(
              top: 10,
              right: 10,
              child: Opacity(
                opacity: buttonOpacity,
                child: IgnorePointer(
                  ignoring: buttonProgress < 0.8,
                  child: _CardMoreActionButton(
                    senderName: senderName,
                    balance: balance,
                    txCount: txCount,
                    isBalanceVisible: isBalanceVisible,
                    isPaused: isPaused,
                    isDarkTextTheme: isDarkTextTheme,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three-dot glass button in top-right corner of BankCardWidget
class _CardMoreActionButton extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;
  final bool isDarkTextTheme;

  const _CardMoreActionButton({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    required this.isDarkTextTheme,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.16);

    final Color iconColor = isDarkTextTheme
        ? AppColors.darkCharcoal
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        BankCardActionModal.show(
          context,
          senderName: senderName,
          balance: balance,
          txCount: txCount,
          isBalanceVisible: isBalanceVisible,
          isPaused: isPaused,
        );
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          color: iconColor,
          size: 18,
        ),
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
          borderRadius: BorderRadius.circular(100),
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
