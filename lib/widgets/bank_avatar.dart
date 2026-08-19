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
      img = Image.asset(
        'assets/images/CBE logo 1.webp',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
      bgColor = isLight
          ? AppColors.slackPurple.withValues(alpha: 0.12)
          : const Color(0xFF6B4C9A).withValues(alpha: 0.20);
    } else if (nameUp == 'TELEBIRR') {
      img = Image.asset(
        'assets/images/Telebirr Logo.png',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        color: isLight ? AppColors.telebirrGreen : null,
        colorBlendMode: isLight ? BlendMode.srcIn : null,
      );
      bgColor = isLight
          ? AppColors.telebirrGreenSoft
          : AppColors.telebirrGreen.withValues(alpha: 0.20);
    } else if (nameUp == 'CBE BIRR' || nameUp == 'CBEBIRR') {
      img = Image.asset(
        'assets/images/CBEBirr Logo.png',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
      bgColor = isLight
          ? AppColors.cbeBirrPink.withValues(alpha: 0.10)
          : const Color(0xFFE91E63).withValues(alpha: 0.20);
    } else if (nameUp.contains('AHADU')) {
      img = SvgPicture.asset(
        'assets/images/Ahadu_Logo.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
      bgColor = isLight
          ? AppColors.cardAhaduRed.withValues(alpha: 0.10)
          : AppColors.cardAhaduRed.withValues(alpha: 0.20);
    } else if (nameUp.contains('ABYSSINIA') ||
        nameUp == 'BOA' ||
        nameUp.contains('BOA')) {
      img = SvgPicture.asset(
        'assets/images/Bank_of_Abyssinia_Icon.svg',
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
      );
      bgColor = AppColors.cardBoaBg.withValues(alpha: 0.18);
    } else if (nameUp.contains('DASHEN') || nameUp.contains('AMOLE')) {
      img = SvgPicture.asset(
        'assets/images/Dashen_Bank_Logo.svg',
        width: iconSize * 1.15,
        height: iconSize * 1.15,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          isLight ? AppColors.cardDashenDark : Colors.white,
          BlendMode.srcIn,
        ),
      );
      bgColor = isLight
          ? AppColors.cardDashenLight.withValues(alpha: 0.15)
          : AppColors.cardDashenDark.withValues(alpha: 0.35);
    } else if (nameUp.contains('CASH') || nameUp.contains('WALLET')) {
      img = SvgPicture.asset(
        'assets/images/Wallet Icon.svg',
        width: iconSize * 0.9,
        height: iconSize * 0.9,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          AppColors.positive,
          BlendMode.srcIn,
        ),
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
