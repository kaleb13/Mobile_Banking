import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/app_currency.dart';
import '../presentation/viewmodels/settings_view_model.dart';
import '../theme/app_theme.dart';

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
        Provider.of<SettingsViewModel>(context, listen: true).currentCurrency;
    final iconColor = color ?? IconTheme.of(context).color ?? context.themeIconPrimary;

    if (activeCurrency.isSvg) {
      return AppSvgIcon(
        activeCurrency.svgAsset!,
        size: size,
        color: iconColor,
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
  final bool autoFit;

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
    this.autoFit = true,
  });

  @override
  Widget build(BuildContext context) {
    final activeCurrency = currency ??
        Provider.of<SettingsViewModel>(context, listen: true).currentCurrency;
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

    final Widget content = activeCurrency.isPrefix
        ? Row(
            mainAxisSize: mainAxisSize,
            crossAxisAlignment: crossAxisAlignment,
            children: [
              if (signStr.isNotEmpty)
                Text(signStr, style: effectiveStyle),
              symbolWidget,
              const SizedBox(width: 2),
              Text(formattedAmount, style: effectiveStyle),
            ],
          )
        : Row(
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

    if (autoFit) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: content,
      );
    }
    return content;
  }
}
