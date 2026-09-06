import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../presentation/viewmodels/settings_view_model.dart';
import '../theme/app_theme.dart';

import 'app_badges.dart';
import 'bank_card_action_modal.dart';

/// Single source-of-truth card widget used in both WalletsScreen list
/// and MainShell's flight overlay animation.
class BankCardWidget extends StatelessWidget {
  final String senderName;
  final double balance;
  final int txCount;
  final bool isBalanceVisible;
  final bool isPaused;
  final VoidCallback? onTap;
  /// Callback to toggle this bank's balance visibility.
  final VoidCallback? onToggleBalance;
  /// Animation factor: 0.0 = Home stack deck state, 1.0 = full Wallet list card state.
  final double animationFactor;
  /// Whether to display the top-right three-dot menu button.
  final bool showMoreButton;
  /// Number of distinct accounts / SIMs attached to this bank.
  final int accountCount;
  /// Callback when user selects Change Order from the 3-dot action modal.
  final VoidCallback? onEnterReorderMode;
  /// Whether this card is rendered at the top of the homepage stack (Dynamic White Version).
  final bool isTopCard;
  /// Optional drag handle action widget (e.g. for reordering list).
  final Widget? dragHandle;

  const BankCardWidget({
    super.key,
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    this.onTap,
    this.onToggleBalance,
    this.animationFactor = 1.0,
    this.showMoreButton = true,
    this.accountCount = 1,
    this.onEnterReorderMode,
    this.isTopCard = false,
    this.dragHandle,
  });

  static Widget bankLogo(String name, [double size = 34.0, Color? iconColor, bool onLightSurface = false]) {
    final nameUp = name.toUpperCase();

    // 1. CBE: ALWAYS the original full-color CBE logo SVG regardless of background
    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL BANK') || nameUp.contains('COMMERCIAL')) {
      return SvgPicture.asset(
        'assets/images/CBE logo.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }

    // 2. Telebirr: White version on gradient background, original green SVG on white background
    if (nameUp == 'TELEBIRR') {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Telebirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Telebirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Telebirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
      }
    }

    // 3. CBE Birr: White version on gradient background, original SVG on white background
    if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/CBEBirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/CBEBirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/CBEBirr_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        );
      }
    }

    // 4. Ahadu Bank: White version on gradient background, original crimson brand fill on white
    if (nameUp.contains('AHADU')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Ahadu_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Ahadu_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Ahadu_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 5. Bank of Abyssinia (BOA): White version on gradient background, original amber gold brand fill on white
    if (nameUp.contains('ABYSSINIA') || nameUp == 'BOA' || nameUp.contains('BOA')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Bank_of_Abyssinia_Icon.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Bank_of_Abyssinia_Icon.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Bank_of_Abyssinia_Icon.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 6. Dashen Bank: White version on gradient background, original navy brand fill on white
    if (nameUp.contains('DASHEN')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Dashen_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Dashen_Bank_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Dashen_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 7. Awash Bank: White version on gradient background, original brand fill on white
    if (nameUp.contains('AWASH')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Awash_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Awash_Bank_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Awash_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 8. Zemen Bank: White version on gradient background, original crimson brand fill on white
    if (nameUp.contains('ZEMEN')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/ZemenBank_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/ZemenBank_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/ZemenBank_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 9. Nib Bank: White version on gradient background, original brand fill on white
    if (nameUp.contains('NIB')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/NIB_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/NIB_Bank_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/NIB_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 10. Bunna Bank / Buna Bank: White version on gradient background, original brand fill on white
    if (nameUp.contains('BUNNA') || nameUp.contains('BUNA')) {
      if (iconColor != null) {
        return SvgPicture.asset(
          'assets/images/Buna_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
      if (onLightSurface) {
        return SvgPicture.asset(
          'assets/images/Buna_Bank_Logo.svg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      } else {
        return SvgPicture.asset(
          'assets/images/Buna_Bank_Logo.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          fit: BoxFit.contain,
        );
      }
    }

    // 11. Cash Wallet
    if (nameUp == 'CASH WALLET' || nameUp == 'CASH') {
      return AppSvgIcon(
        'assets/images/Wallet Icon.svg',
        size: size,
        color: iconColor ?? (onLightSurface ? AppColors.iconDark : Colors.white),
      );
    }

    // 12. Loan Tracker
    if (nameUp == 'LOAN TRACKER' || nameUp == 'LOANS' || nameUp == 'LOAN') {
      return Icon(
        Icons.handshake_rounded,
        color: iconColor ?? (onLightSurface ? AppColors.iconDark : Colors.white),
        size: size,
      );
    }

    return Icon(
      Icons.account_balance,
      color: iconColor ?? (onLightSurface ? AppColors.iconDark : Colors.white),
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
    if (n.contains('AWASH')) return 'Awash Bank S.C.';
    if (n.contains('ZEMEN')) return 'Zemen Bank S.C.';
    if (n.contains('NIB')) return 'Nib International Bank S.C.';
    if (n.contains('BUNNA') || n.contains('BUNA')) return 'Bunna Bank S.C.';
    if (n == 'CASH WALLET') return 'Physical Cash Tracking';
    if (n == 'LOAN TRACKER' || n == 'LOANS' || n == 'LOAN') return 'Personal Debt & Loan Ledger';
    return 'Bank Account';
  }

  static List<Color> getCardGradient(String name, {bool isTopCard = false}) {
    if (isTopCard) {
      return const [
        AppColors.cardCbeBirrSilver,
        AppColors.cardCbeBirrWhite,
      ];
    }
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
        AppColors.cardCbeBirrDark,
        AppColors.cardCbeBirrLight,
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
    } else if (nameUp.contains('AWASH')) {
      return [
        AppColors.cardAwashLight,
        AppColors.cardAwashDark,
      ];
    } else if (nameUp.contains('ZEMEN')) {
      return [
        AppColors.cardZemenLight,
        AppColors.cardZemenDark,
      ];
    } else if (nameUp.contains('NIB')) {
      return [
        AppColors.cardNibLight,
        AppColors.cardNibDark,
      ];
    } else if (nameUp.contains('BUNNA') || nameUp.contains('BUNA')) {
      return [
        AppColors.cardBunaLight,
        AppColors.cardBunaDark,
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

  static bool isDarkTextTheme(String name, {bool isPaused = false, bool isTopCard = false}) {
    if (isPaused) return false;
    return isTopCard;
  }

  @override
  Widget build(BuildContext context) {
    final t = animationFactor.clamp(0.0, 1.0);
    final fmt = NumberFormat('#,##0.00');
    final balStr = (isBalanceVisible && !isPaused) ? fmt.format(balance) : '••••••••';
    final parts = balStr.contains('.') ? balStr.split('.') : [balStr, ''];

    // When paused: use defined greyscale palette; otherwise use brand/dynamic gradient
    final List<Color> cardGradient = isPaused
        ? [AppColors.pausedCardDark, AppColors.pausedCardMid]
        : getCardGradient(senderName, isTopCard: isTopCard);

    final bool isDarkTextTheme =
        BankCardWidget.isDarkTextTheme(senderName, isPaused: isPaused, isTopCard: isTopCard);
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
                  color: isTopCard
                      ? Colors.black.withValues(alpha: 0.22)
                      : cardGradient.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ])
        : const [];

    final double cardRadiusVal = AppRadius.card;
    final BorderRadius dynamicBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(cardRadiusVal),
      bottomLeft: Radius.circular(cardRadiusVal),
      topRight: Radius.circular(lerpDouble(0, cardRadiusVal, t)!),
      bottomRight: Radius.circular(lerpDouble(0, cardRadiusVal, t)!),
    );

    return GestureDetector(
      onTap: (isPaused || onTap == null) ? null : onTap,
      behavior: (onTap == null) ? HitTestBehavior.deferToChild : HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: EdgeInsets.all(cardPadding),
            decoration: BoxDecoration(
              borderRadius: dynamicBorderRadius,
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
                      child: bankLogo(senderName, logoSize, null, isDarkTextTheme),
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
                                ] else if (accountCount > 1) ...[
                                  const SizedBox(width: 8),
                                  AppBadge(
                                    text: '$accountCount Accounts',
                                    icon: Icons.sim_card_outlined,
                                    customBgColor: isDarkTextTheme
                                        ? AppColors.darkCharcoal.withValues(alpha: 0.14)
                                        : Colors.white.withValues(alpha: 0.22),
                                    customTextColor: textColorPrimary,
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (onToggleBalance != null) {
                          onToggleBalance!();
                        } else {
                          Provider.of<SettingsViewModel>(context, listen: false)
                              .toggleBankBalanceVisibility(senderName);
                        }
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: (!isPaused && isBalanceVisible && txCount == 0 && balance == 0.0 && senderName.toUpperCase() != 'CASH WALLET')
                                      ? 'Unknown Balance'
                                      : parts[0],
                                  style: TextStyle(
                                    color: textColorPrimary,
                                    fontSize: (!isPaused && isBalanceVisible && txCount == 0 && balance == 0.0 && senderName.toUpperCase() != 'CASH WALLET')
                                        ? lerpDouble(17, 21, t)!
                                        : balanceFontSize,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: isBalanceVisible ? -0.6 : 1.5,
                                    height: 1.0,
                                  ),
                                ),
                                if (parts[1].isNotEmpty && (txCount > 0 || balance > 0.0 || senderName.toUpperCase() == 'CASH WALLET'))
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
                          if (!isPaused && (txCount > 0 || balance > 0.0 || senderName.toUpperCase() == 'CASH WALLET')) ...[
                            const SizedBox(width: 6),
                            Icon(
                              isBalanceVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: textColorPrimary.withValues(alpha: 0.75),
                              size: decimalFontSize + 1,
                            ),
                          ],
                        ],
                      ),
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
                          : (txCount == 0
                              ? 'No transactions yet'
                              : '$txCount total Transactions'),
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

          // ── Actions in top-right corner (Drag Handle & Three-Dot Menu) ────────────
          if (showMoreButton && senderName.toUpperCase() != 'CASH WALLET')
            Positioned(
              top: 10,
              right: 10,
              child: Opacity(
                opacity: buttonOpacity,
                child: IgnorePointer(
                  ignoring: buttonProgress < 0.8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (dragHandle != null) ...[
                        dragHandle!,
                        const SizedBox(width: 8),
                      ],
                      _CardMoreActionButton(
                        senderName: senderName,
                        balance: balance,
                        txCount: txCount,
                        isBalanceVisible: isBalanceVisible,
                        isPaused: isPaused,
                        isDarkTextTheme: isDarkTextTheme,
                        onEnterReorderMode: onEnterReorderMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Standalone Glass Drag Handle Icon for list reordering
class BankCardDragHandle extends StatelessWidget {
  final bool isDarkTextTheme;

  const BankCardDragHandle({
    super.key,
    required this.isDarkTextTheme,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.09)
        : Colors.white.withValues(alpha: 0.18);

    final Color iconColor = isDarkTextTheme
        ? AppColors.darkCharcoal
        : Colors.white;

    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.drag_indicator_rounded,
        color: iconColor,
        size: 20,
      ),
    );
  }
}

/// Standardized Glass Corner Action Button for bank cards (3-dot menu and modal close 'x')
class BankCardGlassActionButton extends StatefulWidget {
  final IconData icon;
  final bool isDarkTextTheme;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  const BankCardGlassActionButton({
    super.key,
    required this.icon,
    required this.isDarkTextTheme,
    required this.onTap,
    this.size = 32.0,
    this.iconSize = 18.0,
  });

  @override
  State<BankCardGlassActionButton> createState() => _BankCardGlassActionButtonState();
}

class _BankCardGlassActionButtonState extends State<BankCardGlassActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color baseBgColor = widget.isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.16);

    final Color pressedBgColor = widget.isDarkTextTheme
        ? AppColors.darkCharcoal.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.28);

    final Color iconColor = widget.isDarkTextTheme
        ? AppColors.darkCharcoal
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _isPressed ? pressedBgColor : baseBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.icon,
            color: iconColor,
            size: widget.iconSize,
          ),
        ),
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
  final VoidCallback? onEnterReorderMode;

  const _CardMoreActionButton({
    required this.senderName,
    required this.balance,
    required this.txCount,
    required this.isBalanceVisible,
    required this.isPaused,
    required this.isDarkTextTheme,
    this.onEnterReorderMode,
  });

  @override
  Widget build(BuildContext context) {
    return BankCardGlassActionButton(
      icon: Icons.more_horiz_rounded,
      isDarkTextTheme: isDarkTextTheme,
      onTap: () async {
        final result = await BankCardActionModal.show(
          context,
          senderName: senderName,
          balance: balance,
          txCount: txCount,
          isBalanceVisible: isBalanceVisible,
          isPaused: isPaused,
        );
        if (result == 'changeOrder') {
          onEnterReorderMode?.call();
        }
      },
    );
  }
}

