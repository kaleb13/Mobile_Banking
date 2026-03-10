class ExpenseDefinition {
  final int? id;
  final String name;
  final double defaultAmount;
  final bool isRecurring;
  final String?
      recurringType; // 'daily', 'interval', 'specific_day', 'days_of_week'
  final int? intervalDays; // e.g. every 2 days
  final int? specificDay; // e.g. 15th of month
  final String? selectedDaysOfWeek; // e.g. "1,3,5" for Mon, Wed, Fri
  final int timesPerDay;
  final bool isActive;
  final DateTime? lastAppliedDate;
  final int? reasonId;

  ExpenseDefinition({
    this.id,
    required this.name,
    required this.defaultAmount,
    this.isRecurring = false,
    this.recurringType,
    this.intervalDays,
    this.specificDay,
    this.selectedDaysOfWeek,
    this.timesPerDay = 1,
    this.isActive = true,
    this.lastAppliedDate,
    this.reasonId,
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
      'selectedDaysOfWeek': selectedDaysOfWeek,
      'timesPerDay': timesPerDay,
      'isActive': isActive ? 1 : 0,
      'lastAppliedDate': lastAppliedDate?.toIso8601String(),
      'reasonId': reasonId,
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
      selectedDaysOfWeek: map['selectedDaysOfWeek'] as String?,
      timesPerDay: map['timesPerDay'] as int? ?? 1,
      isActive: (map['isActive'] as int? ?? 1) == 1,
      lastAppliedDate: map['lastAppliedDate'] != null
          ? DateTime.parse(map['lastAppliedDate'] as String)
          : null,
      reasonId: map['reasonId'] as int?,
    );
  }

  ExpenseDefinition copyWith({
    int? id,
    String? name,
    double? defaultAmount,
    bool? isRecurring,
    String? recurringType,
    int? intervalDays,
    int? specificDay,
    String? selectedDaysOfWeek,
    int? timesPerDay,
    bool? isActive,
    DateTime? lastAppliedDate,
    int? reasonId,
  }) {
    return ExpenseDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringType: recurringType ?? this.recurringType,
      intervalDays: intervalDays ?? this.intervalDays,
      specificDay: specificDay ?? this.specificDay,
      selectedDaysOfWeek: selectedDaysOfWeek ?? this.selectedDaysOfWeek,
      timesPerDay: timesPerDay ?? this.timesPerDay,
      isActive: isActive ?? this.isActive,
      lastAppliedDate: lastAppliedDate ?? this.lastAppliedDate,
      reasonId: reasonId ?? this.reasonId,
    );
  }
}
