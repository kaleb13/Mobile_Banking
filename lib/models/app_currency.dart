class AppCurrency {
  final String code;
  final String name;
  final String symbol;
  final String shortLabel;
  final String? svgAsset;
  final bool isPrefix;

  const AppCurrency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.shortLabel,
    this.svgAsset,
    this.isPrefix = false,
  });

  bool get isSvg => svgAsset != null && svgAsset!.isNotEmpty;

  static const AppCurrency defaultCurrency = AppCurrency(
    code: 'birr',
    name: 'Ethiopian Birr (Birr)',
    symbol: 'Br',
    shortLabel: 'Birr',
    svgAsset: 'assets/images/Birr_Icon.svg',
    isPrefix: false,
  );

  static const List<AppCurrency> supportedCurrencies = [
    AppCurrency(
      code: 'birr',
      name: 'Ethiopian Birr (Birr)',
      symbol: 'Br',
      shortLabel: 'Birr',
      svgAsset: 'assets/images/Birr_Icon.svg',
      isPrefix: false,
    ),
    AppCurrency(
      code: 'usd',
      name: 'US Dollar (\$)',
      symbol: r'$',
      shortLabel: 'USD',
      isPrefix: true,
    ),
    AppCurrency(
      code: 'eur',
      name: 'Euro (€)',
      symbol: '€',
      shortLabel: 'EUR',
      isPrefix: true,
    ),
    AppCurrency(
      code: 'gbp',
      name: 'British Pound (£)',
      symbol: '£',
      shortLabel: 'GBP',
      isPrefix: true,
    ),
    AppCurrency(
      code: 'jpy',
      name: 'Japanese Yen (¥)',
      symbol: '¥',
      shortLabel: 'JPY',
      isPrefix: true,
    ),
    AppCurrency(
      code: 'inr',
      name: 'Indian Rupee (₹)',
      symbol: '₹',
      shortLabel: 'INR',
      isPrefix: true,
    ),
  ];

  static AppCurrency fromCode(String? code) {
    if (code == null || code.isEmpty) return defaultCurrency;
    return supportedCurrencies.firstWhere(
      (c) => c.code.toLowerCase() == code.toLowerCase(),
      orElse: () => defaultCurrency,
    );
  }
}
