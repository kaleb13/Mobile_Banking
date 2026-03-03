class ExpenseDefinition {
  final int? id;
  final String name;
  final double defaultAmount;
  final bool isRecurring;
  final String? recurringType; // 'daily', 'interval', 'specific_day'
  final int? intervalDays; // e.g. every 2 days
  final int? specificDay; // e.g. 15th of month
  final DateTime? lastAppliedDate;

  int get timesPerDay => (recurringType == 'daily') ? (intervalDays ?? 1) : 1;

  ExpenseDefinition({
    this.id,
    required this.name,
    required this.defaultAmount,
    this.isRecurring = false,
    this.recurringType,
    this.intervalDays,
    this.specificDay,
    this.lastAppliedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'defaultAmount': defaultAmount,
      'isRecurring': isRecurring ? 1 : 0,
      'recurringType': recurringType,
      'intervalDays': intervalDays,
      'specificDay': specificDay,
      'lastAppliedDate': lastAppliedDate?.toIso8601String(),
    };
  }

  factory ExpenseDefinition.fromMap(Map<String, dynamic> map) {
    return ExpenseDefinition(
      id: map['id'] as int?,
      name: map['name'] as String,
      defaultAmount: (map['defaultAmount'] as num).toDouble(),
      isRecurring: (map['isRecurring'] as int) == 1,
      recurringType: map['recurringType'] as String?,
      intervalDays: map['intervalDays'] as int?,
      specificDay: map['specificDay'] as int?,
      lastAppliedDate: map['lastAppliedDate'] != null
          ? DateTime.parse(map['lastAppliedDate'] as String)
          : null,
    );
  }

  ExpenseDefinition copyWith({
    String? name,
    double? defaultAmount,
    bool? isRecurring,
    String? recurringType,
    int? intervalDays,
    int? specificDay,
    DateTime? lastAppliedDate,
  }) {
    return ExpenseDefinition(
      id: id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      intervalDays: intervalDays ?? this.intervalDays,
      specificDay: specificDay ?? this.specificDay,
      lastAppliedDate: lastAppliedDate ?? this.lastAppliedDate,
    );
  }
}
