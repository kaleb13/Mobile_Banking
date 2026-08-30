class TransactionSplit {
  final int? id;
  final String transactionId;
  final double amount;
  final int? reasonId;
  final String? reasonName;
  final int? categoryId;
  final int? subcategoryId;
  final String? customReasonText;
  final String? note;
  final DateTime createdAt;

  TransactionSplit({
    this.id,
    required this.transactionId,
    required this.amount,
    this.reasonId,
    this.reasonName,
    this.categoryId,
    this.subcategoryId,
    this.customReasonText,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'transactionId': transactionId,
      'amount': amount,
      'reasonId': reasonId,
      'reasonName': reasonName,
      'categoryId': categoryId,
      'subcategoryId': subcategoryId,
      'customReasonText': customReasonText,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TransactionSplit.fromMap(Map<String, dynamic> map) {
    return TransactionSplit(
      id: map['id'] as int?,
      transactionId: map['transactionId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reasonId: map['reasonId'] as int?,
      reasonName: map['reasonName'] as String?,
      categoryId: map['categoryId'] as int?,
      subcategoryId: map['subcategoryId'] as int?,
      customReasonText: map['customReasonText'] as String?,
      note: map['note'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  TransactionSplit copyWith({
    int? id,
    String? transactionId,
    double? amount,
    int? reasonId,
    String? reasonName,
    int? categoryId,
    int? subcategoryId,
    String? customReasonText,
    String? note,
    DateTime? createdAt,
    bool clearReasonId = false,
    bool clearReasonName = false,
    bool clearCategoryId = false,
    bool clearSubcategoryId = false,
    bool clearCustomReason = false,
  }) {
    return TransactionSplit(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      reasonId: clearReasonId ? null : (reasonId ?? this.reasonId),
      reasonName: clearReasonName ? null : (reasonName ?? this.reasonName),
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      subcategoryId:
          clearSubcategoryId ? null : (subcategoryId ?? this.subcategoryId),
      customReasonText:
          clearCustomReason ? null : (customReasonText ?? this.customReasonText),
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
