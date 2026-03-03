class CashTransaction {
  final int? id;
  final String type; // 'addition' or 'expense'
  final double amount;
  final DateTime date;
  final String? description;
  final int? expenseDefinitionId;

  CashTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.description,
    this.expenseDefinitionId,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'date': date.toIso8601String(),
      'description': description,
      'expenseDefinitionId': expenseDefinitionId,
    };
  }

  factory CashTransaction.fromMap(Map<String, dynamic> map) {
    return CashTransaction(
      id: map['id'] as int?,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      description: map['description'] as String?,
      expenseDefinitionId: map['expenseDefinitionId'] as int?,
    );
  }

  CashTransaction copyWith({
    String? type,
    double? amount,
    DateTime? date,
    String? description,
    int? expenseDefinitionId,
  }) {
    return CashTransaction(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      expenseDefinitionId: expenseDefinitionId ?? this.expenseDefinitionId,
    );
  }
}
