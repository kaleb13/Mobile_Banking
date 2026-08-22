import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../presentation/viewmodels/settings_view_model.dart';
import '../theme/app_theme.dart';

/// Universal, clean component for rendering monetary values across the application.
/// Automatically subscribes to [SettingsViewModel.isBalanceVisible] and synchronously
/// masks or reveals values with no boilerplate throughout the entire app.
class AppMoneyText extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final String? prefix;
  final String? suffix;
  final bool showCurrency;
  final int decimalDigits;
  final String maskString;
  final bool isPositiveColor;
  final bool isNegativeColor;
  final String? customFormatPattern;

  const AppMoneyText({
    super.key,
    required this.amount,
    this.style,
    this.prefix,
    this.suffix,
    this.showCurrency = false,
    this.decimalDigits = 2,
    this.maskString = '••••••',
    this.isPositiveColor = false,
    this.isNegativeColor = false,
    this.customFormatPattern,
  });

  const AppMoneyText.whole({
    super.key,
    required this.amount,
    this.style,
    this.prefix,
    this.suffix,
    this.showCurrency = false,
    this.decimalDigits = 0,
    this.maskString = '••••••',
    this.isPositiveColor = false,
    this.isNegativeColor = false,
    this.customFormatPattern = '#,##0',
  });

  const AppMoneyText.pnl({
    super.key,
    required this.amount,
    this.style,
    this.prefix,
    this.suffix,
    this.showCurrency = false,
    this.decimalDigits = 0,
    this.maskString = '••••••',
    this.customFormatPattern = '#,##0',
  })  : isPositiveColor = amount >= 0,
        isNegativeColor = amount < 0;

  @override
  Widget build(BuildContext context) {
    final settingsVM = context.watch<SettingsViewModel>();
    final isVisible = settingsVM.isBalanceVisible;

    Color? textColor = style?.color;
    if (isPositiveColor) {
      textColor = AppColors.positive;
    } else if (isNegativeColor) {
      textColor = AppColors.negative;
    }

    final effectiveStyle = (style ?? const TextStyle()).copyWith(color: textColor);

    if (!isVisible) {
      return Text(
        '${prefix ?? ''}$maskString${suffix ?? ''}',
        style: effectiveStyle,
      );
    }

    final NumberFormat fmt = customFormatPattern != null
        ? NumberFormat(customFormatPattern)
        : (decimalDigits == 0
            ? NumberFormat('#,##0')
            : NumberFormat('#,##0.${'0' * decimalDigits}'));

    final formatted = fmt.format(amount.abs());
    final currencyPrefix = showCurrency ? '${settingsVM.currentCurrency.shortLabel} ' : '';
    final sign = amount < 0 && (prefix == null || !prefix!.contains('-')) ? '-' : '';

    return Text(
      '$sign${prefix ?? ''}$currencyPrefix$formatted${suffix ?? ''}',
      style: effectiveStyle,
    );
  }
}
