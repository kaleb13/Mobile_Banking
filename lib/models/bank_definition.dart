import 'package:flutter/material.dart';
import 'parsed_sms_result.dart';

/// Represents the complete declarative definition of a bank.
///
/// Contains all properties required to identify, brand, and parse SMS
/// messages for a bank dynamically without compiling new code.
class BankDefinition {
  final String id;
  final String bankName;
  final String officialTitle;
  final String subtitle;
  final String accountType; // 'bank' or 'wallet'
  final BankSenderIdentifier senderIdentifiers;
  final BankBranding branding;
  final Map<String, dynamic> metadata;
  final BankParsingRule parsing;

  const BankDefinition({
    required this.id,
    required this.bankName,
    required this.officialTitle,
    required this.subtitle,
    this.accountType = 'bank',
    required this.senderIdentifiers,
    required this.branding,
    this.metadata = const {},
    required this.parsing,
  });

  factory BankDefinition.fromJson(Map<String, dynamic> json) {
    return BankDefinition(
      id: json['id'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      officialTitle: json['officialTitle'] as String? ?? json['bankName'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'bank',
      senderIdentifiers: BankSenderIdentifier.fromJson(
        json['senderIdentifiers'] as Map<String, dynamic>? ?? {},
      ),
      branding: BankBranding.fromJson(
        json['branding'] as Map<String, dynamic>? ?? {},
      ),
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      parsing: BankParsingRule.fromJson(
        json['parsing'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bankName': bankName,
    'officialTitle': officialTitle,
    'subtitle': subtitle,
    'accountType': accountType,
    'senderIdentifiers': senderIdentifiers.toJson(),
    'branding': branding.toJson(),
    'metadata': metadata,
    'parsing': parsing.toJson(),
  };
}

/// Identifiers used to associate incoming SMS senders with this bank.
class BankSenderIdentifier {
  final String canonical;
  final List<String> keywords;
  final List<String> exactSenders;
  final String? numericShortCode;

  const BankSenderIdentifier({
    required this.canonical,
    this.keywords = const [],
    this.exactSenders = const [],
    this.numericShortCode,
  });

  factory BankSenderIdentifier.fromJson(Map<String, dynamic> json) {
    return BankSenderIdentifier(
      canonical: json['canonical'] as String? ?? '',
      keywords: (json['keywords'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList() ?? const [],
      exactSenders: (json['exactSenders'] as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList() ?? const [],
      numericShortCode: json['numericShortCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'canonical': canonical,
    'keywords': keywords,
    'exactSenders': exactSenders,
    'numericShortCode': numericShortCode,
  };

  /// Returns true if [sender] matches this bank's identifiers.
  bool matches(String sender) {
    final sTrim = sender.trim();
    if (sTrim.isEmpty) return false;

    // Check numeric shortcode
    if (numericShortCode != null && sTrim == numericShortCode) {
      return true;
    }

    final sUpper = sTrim.toUpperCase();
    for (final exact in exactSenders) {
      if (sUpper == exact) return true;
    }

    final sLower = sTrim.toLowerCase();
    for (final kw in keywords) {
      if (sLower.contains(kw)) return true;
    }

    return false;
  }
}

/// Visual branding and card properties for this bank.
class BankBranding {
  final List<String> gradientColorsHex;
  final bool isDarkTextTheme;
  final String? iconUrl;
  final String? iconAssetFallback;
  final String? localIconPath;
  final String? iconChecksum;

  const BankBranding({
    required this.gradientColorsHex,
    this.isDarkTextTheme = false,
    this.iconUrl,
    this.iconAssetFallback,
    this.localIconPath,
    this.iconChecksum,
  });

  factory BankBranding.fromJson(Map<String, dynamic> json) {
    return BankBranding(
      gradientColorsHex: (json['gradientColors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      isDarkTextTheme: json['isDarkTextTheme'] as bool? ?? false,
      iconUrl: json['iconUrl'] as String?,
      iconAssetFallback: json['iconAssetFallback'] as String?,
      localIconPath: json['localIconPath'] as String?,
      iconChecksum: json['iconChecksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'gradientColors': gradientColorsHex,
    'isDarkTextTheme': isDarkTextTheme,
    'iconUrl': iconUrl,
    'iconAssetFallback': iconAssetFallback,
    if (localIconPath != null) 'localIconPath': localIconPath,
    if (iconChecksum != null) 'iconChecksum': iconChecksum,
  };

  /// Converts hex color strings to a `List<Color>` for Flutter gradients.
  List<Color> toColorList({List<Color>? fallback}) {
    if (gradientColorsHex.isEmpty) {
      return fallback ?? const [Color(0xFF2F2F39), Color(0xFF4F4F59)];
    }
    try {
      return gradientColorsHex.map((hex) {
        String cleanHex = hex.replaceFirst('#', '');
        if (cleanHex.length == 6) {
          cleanHex = 'FF$cleanHex';
        }
        return Color(int.parse(cleanHex, radix: 16));
      }).toList();
    } catch (_) {
      return fallback ?? const [Color(0xFF2F2F39), Color(0xFF4F4F59)];
    }
  }
}

/// Rules for filtering and parsing SMS for this bank.
class BankParsingRule {
  final String? securityFilterRegex;
  final String? ignoreFilterRegex;
  final List<BankPatternRule> patterns;

  const BankParsingRule({
    this.securityFilterRegex,
    this.ignoreFilterRegex,
    this.patterns = const [],
  });

  factory BankParsingRule.fromJson(Map<String, dynamic> json) {
    return BankParsingRule(
      securityFilterRegex: json['securityFilterRegex'] as String?,
      ignoreFilterRegex: json['ignoreFilterRegex'] as String?,
      patterns: (json['patterns'] as List<dynamic>?)
              ?.map((e) => BankPatternRule.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'securityFilterRegex': securityFilterRegex,
    'ignoreFilterRegex': ignoreFilterRegex,
    'patterns': patterns.map((p) => p.toJson()).toList(),
  };
}

/// A specific regex pattern rule for extracting transaction facts.
class BankPatternRule {
  final String patternId;
  final String name;
  final String type; // 'income' or 'expense'
  final String patternType; // 'standardTransfer', 'telebirrAirtime', etc.
  final List<String> triggerKeywords;
  final String regex;
  final int amountGroup;
  final int counterpartyGroup;
  final String? counterpartyDefault;
  final int? balanceGroup;
  final int? idGroup;
  final int? dateGroup;
  final String? dateFormat;

  const BankPatternRule({
    required this.patternId,
    required this.name,
    required this.type,
    this.patternType = 'standardTransfer',
    this.triggerKeywords = const [],
    required this.regex,
    this.amountGroup = 1,
    this.counterpartyGroup = 2,
    this.counterpartyDefault,
    this.balanceGroup,
    this.idGroup,
    this.dateGroup,
    this.dateFormat,
  });

  factory BankPatternRule.fromJson(Map<String, dynamic> json) {
    return BankPatternRule(
      patternId: json['patternId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'expense',
      patternType: json['patternType'] as String? ?? 'standardTransfer',
      triggerKeywords: (json['triggerKeywords'] as List<dynamic>?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          const [],
      regex: json['regex'] as String? ?? '',
      amountGroup: json['amountGroup'] as int? ?? 1,
      counterpartyGroup: json['counterpartyGroup'] as int? ?? 2,
      counterpartyDefault: json['counterpartyDefault'] as String?,
      balanceGroup: json['balanceGroup'] as int?,
      idGroup: json['idGroup'] as int?,
      dateGroup: json['dateGroup'] as int?,
      dateFormat: json['dateFormat'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'patternId': patternId,
    'name': name,
    'type': type,
    'patternType': patternType,
    'triggerKeywords': triggerKeywords,
    'regex': regex,
    'amountGroup': amountGroup,
    'counterpartyGroup': counterpartyGroup,
    if (counterpartyDefault != null) 'counterpartyDefault': counterpartyDefault,
    if (balanceGroup != null) 'balanceGroup': balanceGroup,
    if (idGroup != null) 'idGroup': idGroup,
    if (dateGroup != null) 'dateGroup': dateGroup,
    if (dateFormat != null) 'dateFormat': dateFormat,
  };

  SmsPatternType get resolvedPatternType {
    switch (patternType) {
      case 'telebirrAirtime':
        return SmsPatternType.telebirrAirtime;
      case 'telebirrPackage':
        return SmsPatternType.telebirrPackage;
      case 'telebirrSanduq':
        return SmsPatternType.telebirrSanduq;
      case 'internalTransfer':
        return SmsPatternType.internalTransfer;
      case 'schoolFee':
        return SmsPatternType.schoolFee;
      default:
        return SmsPatternType.standardTransfer;
    }
  }
}
