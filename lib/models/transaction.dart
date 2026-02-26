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

  // Reason system
  final int? reasonId; // points to reasons table (reusable)
  final String? customReasonText; // one-time text, stored only on transaction
  final String? reason; // legacy / convenience resolved name

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
    this.customReasonText,
    this.reason,
  });

  /// Resolved display label: prefer reason name from `reason` field (pre-resolved),
  /// fallback to customReasonText.
  String? get resolvedReason => reason ?? customReasonText;

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
      'customReasonText': customReasonText,
      // Keep legacy 'reason' column in sync for backward compat
      'reason': reason ?? customReasonText,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
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
      customReasonText: map['customReasonText'] as String?,
      reason: map['reason'] as String?,
    );
  }

  AppTransaction copyWith({
    int? reasonId,
    bool clearReasonId = false,
    String? customReasonText,
    bool clearCustomReason = false,
    String? reason,
    bool clearReason = false,
  }) {
    return AppTransaction(
      id: id,
      name: name,
      amount: amount,
      type: type,
      date: date,
      sender: sender,
      category: category,
      rawMessage: rawMessage,
      isAutoDetected: isAutoDetected,
      totalBalance: totalBalance,
      reasonId: clearReasonId ? null : (reasonId ?? this.reasonId),
      customReasonText: clearCustomReason
          ? null
          : (customReasonText ?? this.customReasonText),
      reason: clearReason ? null : (reason ?? this.reason),
    );
  }
}
