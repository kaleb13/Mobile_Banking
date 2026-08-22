import 'transaction_attachment.dart';
import 'parsed_sms_result.dart';
import '../utils/link_extractor.dart';

class AppTransaction {
  final String? id;
  final String name;
  final double amount;
  final String type; // 'income' or 'expense'
  final DateTime date;
  final String sender;
  final String category;
  final String rawMessage;
  final bool isAutoDetected;
  final double totalBalance;

  // Reason & Hierarchy system
  final int? reasonId; // points to reasons table (reusable)
  final int? categoryId; // points to top-level category in reasons table
  final int? subcategoryId; // points to subcategory in reasons table
  final String? customReasonText; // one-time text, stored only on transaction
  final String? reason; // legacy / convenience resolved name
  final String? note; // free-text context note
  final List<TransactionAttachment> attachments;

  final String? linkedTransactionId; // points to another transaction for internal transfers
  final String? bankReference; // original reference number from the bank SMS
  final bool isBookmarked;

  AppTransaction({
    this.id,
    required this.name,
    required this.amount,
    required this.type,
    required this.date,
    required this.sender,
    required this.category,
    required this.rawMessage,
    required this.isAutoDetected,
    this.totalBalance = 0.0,
    this.reasonId,
    this.categoryId,
    this.subcategoryId,
    this.customReasonText,
    this.reason,
    this.note,
    this.attachments = const [],
    this.linkedTransactionId,
    this.bankReference,
    this.isBookmarked = false,
  });

  /// Factory that enriches a pure parser DTO (ParsedSmsResult) into an AppTransaction entity.
  factory AppTransaction.fromParsedResult(
    ParsedSmsResult result, {
    int? reasonId,
    String? reason,
    String? customReasonText,
    String? note,
    String? linkedTransactionId,
    String? bankReference,
    bool isBookmarked = false,
  }) {
    return AppTransaction(
      id: result.id,
      name: result.bankName,
      amount: result.amount,
      type: result.type,
      date: result.date,
      sender: result.counterparty,
      category: 'Auto',
      totalBalance: result.totalBalance,
      rawMessage: result.rawMessage,
      isAutoDetected: true,
      reasonId: reasonId,
      reason: reason ?? result.lockedReasonName,
      customReasonText: customReasonText,
      note: note,
      linkedTransactionId: linkedTransactionId,
      bankReference: bankReference,
      isBookmarked: isBookmarked,
    );
  }

  /// Resolved display label: prefer reason name from `reason` field (pre-resolved),
  /// fallback to customReasonText.
  String? get resolvedReason => reason ?? customReasonText;

  /// Extracts all URLs found in the raw message body.
  List<String> get extractedLinks => LinkExtractor.extractUrls(rawMessage);

  /// True if this transaction's raw message body contains any web links.
  bool get hasLinks => extractedLinks.isNotEmpty;

  /// True when this transaction was auto-created with an immutable system reason from SMS
  /// (strictly Telebirr Airtime, Telebirr Package, or Telebirr Sanduq/Savings).
  bool get isReasonLocked {
    final lower = rawMessage.toLowerCase();
    final isTelebirr = name.toLowerCase().contains('telebirr') ||
        sender.toLowerCase().contains('127') ||
        sender.toLowerCase().contains('telebirr');
    if (!isTelebirr) return false;

    // 1. Airtime recharge outflow
    if (lower.contains('airtime') &&
        (lower.contains('recharged') || lower.contains('bought'))) {
      return true;
    }
    // 2. Package subscription outflow
    if (lower.contains('package') &&
        (lower.contains('paid') ||
            lower.contains('bought') ||
            lower.contains('package subscription') ||
            lower.contains('monthly voice'))) {
      return true;
    }
    // 3. Sanduq / Savings account transfer
    if (lower.contains('saving account') ||
        lower.contains('saving balance') ||
        lower.contains('sanduq')) {
      return true;
    }

    return false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'sender': sender,
      'category': category,
      'rawMessage': rawMessage,
      'isAutoDetected': isAutoDetected ? 1 : 0,
      'totalBalance': totalBalance,
      'reasonId': reasonId,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'customReasonText': customReasonText,
      // Keep legacy 'reason' column in sync for backward compat
      'reason': reason ?? customReasonText,
      'note': note,
      'linkedTransactionId': linkedTransactionId,
      'bankReference': bankReference,
      'isBookmarked': isBookmarked ? 1 : 0,
    };
  }

  factory AppTransaction.fromMap(
    Map<String, dynamic> map, {
    List<TransactionAttachment> attachments = const [],
  }) {
    return AppTransaction(
      id: map['id']?.toString(),
      name: map['name'] ?? 'Unknown',
      amount: (map['amount'] as num).toDouble(),
      type: map['type'],
      date: DateTime.parse(map['date']),
      sender: map['sender'],
      category: map['category'],
      rawMessage: map['rawMessage'],
      isAutoDetected: map['isAutoDetected'] == 1,
      totalBalance: (map['totalBalance'] as num?)?.toDouble() ?? 0.0,
      reasonId: map['reasonId'] as int?,
      categoryId: map['categoryId'] as int?,
      subcategoryId: map['subcategoryId'] as int?,
      customReasonText: map['customReasonText'] as String?,
      reason: map['reason'] as String?,
      note: map['note'] as String?,
      attachments: attachments,
      linkedTransactionId: map['linkedTransactionId'] as String?,
      bankReference: map['bankReference'] as String?,
      isBookmarked: (map['isBookmarked'] as int? ?? 0) == 1,
    );
  }

  AppTransaction copyWith({
    DateTime? date,
    int? reasonId,
    bool clearReasonId = false,
    int? categoryId,
    bool clearCategoryId = false,
    int? subcategoryId,
    bool clearSubcategoryId = false,
    String? customReasonText,
    bool clearCustomReason = false,
    String? reason,
    bool clearReason = false,
    String? note,
    bool clearNote = false,
    List<TransactionAttachment>? attachments,
    String? linkedTransactionId,
    bool clearLinkedTransactionId = false,
    double? totalBalance,
    String? bankReference,
    bool clearBankReference = false,
    bool? isBookmarked,
  }) {
    return AppTransaction(
      id: id,
      name: name,
      amount: amount,
      type: type,
      date: date ?? this.date,
      sender: sender,
      category: category,
      rawMessage: rawMessage,
      isAutoDetected: isAutoDetected,
      totalBalance: totalBalance ?? this.totalBalance,
      reasonId: clearReasonId ? null : (reasonId ?? this.reasonId),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subcategoryId: clearSubcategoryId ? null : (subcategoryId ?? this.subcategoryId),
      customReasonText: clearCustomReason
          ? null
          : (customReasonText ?? this.customReasonText),
      reason: clearReason ? null : (reason ?? this.reason),
      note: clearNote ? null : (note ?? this.note),
      attachments: attachments ?? this.attachments,
      linkedTransactionId: clearLinkedTransactionId
          ? null
          : (linkedTransactionId ?? this.linkedTransactionId),
      bankReference: clearBankReference
          ? null
          : (bankReference ?? this.bankReference),
      isBookmarked: isBookmarked ?? this.isBookmarked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppTransaction && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
