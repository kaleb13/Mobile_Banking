import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

/// Standardized Bank Avatar displaying the bank's brand logo or icon.
///
/// Strictly follows design system guidelines:
/// - Zero borders or strokes
/// - Circular surface background
/// - Supports dark and light surface variants
class BankAvatar extends StatelessWidget {
  final String bankName;
  final double size;
  final double iconSize;
  final bool isLight;

  const BankAvatar({
    super.key,
    required this.bankName,
    this.size = 38,
    this.iconSize = 20,
    this.isLight = false,
  });

  @override
  Widget build(BuildContext context) {
    final nameUp = bankName.toUpperCase().trim();
    Widget img;
    Color bgColor;

    if (nameUp == 'CBE' || nameUp.contains('COMMERCIAL')) {
      img = SvgPicture.asset(
        'assets/images/CBE logo.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
      bgColor = isLight
          ? AppColors.slackPurple.withValues(alpha: 0.12)
          : AppColors.cbePurple.withValues(alpha: 0.20);
    } else if (nameUp == 'TELEBIRR') {
      img = SvgPicture.asset(
        'assets/images/Telebirr_Logo.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: isLight
            ? const ColorFilter.mode(AppColors.telebirrGreen, BlendMode.srcIn)
            : null,
      );
      bgColor = isLight
          ? AppColors.telebirrGreenSoft
          : AppColors.telebirrGreen.withValues(alpha: 0.20);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = SvgPicture.asset(
        'assets/images/CBEBirr_Logo.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        colorFilter: isLight ? null : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      bgColor = isLight
          ? AppColors.cbeBirrPink.withValues(alpha: 0.10)
          : AppColors.cbeBirrMagenta.withValues(alpha: 0.20);
    } else if (nameUp.contains('AHADU')) {
      img = AppSvgIcon(
        'assets/images/Ahadu_Logo.svg',
        size: iconSize,
        onLightSurface: isLight,
      );
      bgColor = isLight
          ? AppColors.cardAhaduRed.withValues(alpha: 0.10)
          : AppColors.cardAhaduRed.withValues(alpha: 0.20);
    } else if (nameUp.contains('ABYSSINIA') ||
        nameUp == 'BOA' ||
        nameUp.contains('BOA')) {
      img = AppSvgIcon(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        size: iconSize,
        onLightSurface: isLight,
      );
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      img = AppSvgIcon(
        'assets/images/Dashen_Bank_Logo.svg',
        size: iconSize * 1.15,
        color: isLight ? AppColors.cardDashenDark : AppColors.iconLight,
        onLightSurface: isLight,
      );
      bgColor = isLight
          ? AppColors.cardDashenLight.withValues(alpha: 0.15)
          : AppColors.cardDashenDark.withValues(alpha: 0.35);
    } else if (nameUp.contains('AWASH')) {
      img = SvgPicture.asset(
        'assets/images/Awash_Bank_Logo.svg',
        width: iconSize * 1.15,
        height: iconSize * 1.15,
        fit: BoxFit.contain,
        colorFilter: isLight ? null : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      bgColor = isLight
          ? AppColors.cardAwashDark.withValues(alpha: 0.12)
          : AppColors.cardAwashDark.withValues(alpha: 0.35);
    } else if (nameUp.contains('ZEMEN')) {
      img = SvgPicture.asset(
        'assets/images/ZemenBank_Logo.svg',
        width: iconSize * 1.15,
        height: iconSize * 1.15,
        fit: BoxFit.contain,
        colorFilter: isLight ? null : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      );
      bgColor = isLight
          ? AppColors.cardZemenDark.withValues(alpha: 0.12)
          : AppColors.cardZemenDark.withValues(alpha: 0.35);
    } else if (nameUp.contains('CASH') || nameUp.contains('WALLET')) {
      img = AppSvgIcon(
        'assets/images/Wallet Icon.svg',
        size: iconSize * 0.9,
        color: AppColors.positive,
      );
      bgColor = isLight
          ? AppColors.positive.withValues(alpha: 0.12)
          : AppColors.positive.withValues(alpha: 0.15);
    } else {
      final initial = bankName.isNotEmpty
          ? bankName.substring(0, min(1, bankName.length)).toUpperCase()
          : '?';
      img = Text(
        initial,
        style: TextStyle(
          color: isLight ? AppColors.darkCharcoal : AppColors.textPrimary,
          fontSize: iconSize * 0.55,
          fontWeight: FontWeight.bold,
        ),
      );
      bgColor = isLight ? AppColors.lightGreyBackground : AppColors.buttonSecondary;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: img),
    );
  }
}
