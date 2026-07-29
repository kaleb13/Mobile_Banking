import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_currency.dart';
import '../providers/finance_provider.dart';

class CurrencySymbolWidget extends StatelessWidget {
  final AppCurrency? currency;
  final Color? color;
  final double size;
  final FontWeight? fontWeight;

  const CurrencySymbolWidget({
    super.key,
    this.currency,
    this.color,
    this.size = 16.0,
    this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    final activeCurrency = currency ??
        Provider.of<FinanceProvider>(context, listen: true).currentCurrency;
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;

    if (activeCurrency.isSvg) {
      return SvgPicture.asset(
        activeCurrency.svgAsset!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    }

    return Text(
      activeCurrency.symbol,
      style: TextStyle(
        color: iconColor,
        fontSize: size,
        fontWeight: fontWeight ?? FontWeight.bold,
      ),
    );
  }
}

class CurrencyTextWidget extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final Color? color;
  final double? iconSize;
  final AppCurrency? currency;
  final bool showSign;
  final String? customFormattedStr;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;

  const CurrencyTextWidget({
    super.key,
    required this.amount,
    this.style,
    this.color,
    this.iconSize,
    this.currency,
    this.showSign = false,
    this.customFormattedStr,
    this.mainAxisSize = MainAxisSize.min,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final activeCurrency = currency ??
        Provider.of<FinanceProvider>(context, listen: true).currentCurrency;
    final textStyle = style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final effectiveColor = color ?? textStyle.color ?? Colors.white;
    final effectiveStyle = textStyle.copyWith(color: effectiveColor);
    final size = iconSize ?? (textStyle.fontSize ?? 14.0);

    final formatter = NumberFormat('#,##0.00');
    final formattedAmount = customFormattedStr ?? formatter.format(amount.abs());
    final signStr = showSign ? (amount > 0 ? '+' : amount < 0 ? '-' : '') : (amount < 0 ? '-' : '');

    final symbolWidget = CurrencySymbolWidget(
      currency: activeCurrency,
      color: effectiveColor,
      size: size,
      fontWeight: effectiveStyle.fontWeight,
    );

    if (activeCurrency.isPrefix) {
      return Row(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (signStr.isNotEmpty)
            Text(signStr, style: effectiveStyle),
          symbolWidget,
          const SizedBox(width: 2),
          Text(formattedAmount, style: effectiveStyle),
        ],
      );
    } else {
      return Row(
        mainAxisSize: mainAxisSize,
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (signStr.isNotEmpty)
            Text(signStr, style: effectiveStyle),
          Text(formattedAmount, style: effectiveStyle),
          const SizedBox(width: 4),
          symbolWidget,
        ],
      );
    }
  }
}
