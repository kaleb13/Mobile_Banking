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
  });

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
    );
  }
}
