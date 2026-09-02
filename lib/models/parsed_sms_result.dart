/// Represents the classification pattern detected in a banking SMS message.
enum SmsPatternType {
  /// Standard transfer, deposit, payment, or withdrawal
  standardTransfer,

  /// Airtime recharge outflow (Locked system reason)
  telebirrAirtime,

  /// Data/voice package purchase or subscription (Locked system reason)
  telebirrPackage,

  /// Internal transfer to Telebirr Sanduq / Savings account (Locked system reason)
  telebirrSanduq,

  /// Internal transfer between user accounts / SIMs (Locked system reason)
  internalTransfer,

  /// Unrecognized non-financial or malformed message
  unrecognized;

  /// True if this pattern corresponds to an immutable, locked system reason.
  bool get isLocked =>
      this == SmsPatternType.telebirrSanduq ||
      this == SmsPatternType.internalTransfer;
}

/// Pure Data Transfer Object (DTO) containing ONLY objective facts extracted from raw SMS text.
///
/// Parsers output this DTO without any knowledge of database IDs, user personal notes,
/// or categorization business rules.
class ParsedSmsResult {
  /// Unique bank transaction reference / code (e.g. "BD45KRON6P", "FT24107T1361")
  final String id;

  /// Financial institution or service provider (e.g. "Telebirr", "CBE", "BOA", "Ahadu", "Dashen")
  final String bankName;

  /// Transaction monetary amount (guaranteed > 0)
  final double amount;

  /// Cash flow direction: "income" or "expense"
  final String type;

  /// Date and time extracted from SMS text (or delivery timestamp fallback)
  final DateTime date;

  /// Counterparty identifier: Phone number, Account number, or Person name
  final String counterparty;

  /// Post-transaction running balance reported by the bank
  final double totalBalance;

  /// Original, unmodified raw SMS message body
  final String rawMessage;

  /// Specific pattern type detected in the SMS
  final SmsPatternType patternType;

  const ParsedSmsResult({
    required this.id,
    required this.bankName,
    required this.amount,
    required this.type,
    required this.date,
    required this.counterparty,
    required this.totalBalance,
    required this.rawMessage,
    this.patternType = SmsPatternType.standardTransfer,
  });

  /// Convenience getter indicating if this parsed result has a locked system pattern.
  bool get isSystemLocked => patternType.isLocked;

  /// Maps the pattern type to the official locked system reason name, or null if standard.
  String? get lockedReasonName {
    switch (patternType) {
      case SmsPatternType.telebirrAirtime:
        return 'Airtime';
      case SmsPatternType.telebirrPackage:
        return 'Package';
      case SmsPatternType.telebirrSanduq:
      case SmsPatternType.internalTransfer:
        return 'Internal Transfer';
      default:
        return null;
    }
  }
}
