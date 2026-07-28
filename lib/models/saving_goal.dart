import 'dart:convert';

/// Determines how the feasibility engine sources money for this goal.
enum AllocationMode {
  /// Use X% of the total balance across all accounts (default: 30%).
  globalPercent,
  /// Use X% of one specific account's balance.
  accountSpecific,
  /// Use defined % from multiple accounts, each listed separately.
  multiAccount,
}

class SavingGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double savedAmount;
  final String imagePath;
  final String category;
  final String status;
  final String? targetDate;
  final int priority;

  /// How this goal sources money for its feasibility calculation.
  /// Serialised as 'global_percent' | 'account_specific' | 'multi_account'.
  final AllocationMode allocationMode;

  /// The allocation percentages keyed by account name.
  /// For globalPercent: {'*': 30.0}
  /// For accountSpecific: {'CBE': 100.0}
  /// For multiAccount: {'CBE': 60.0, 'Telebirr': 40.0}
  final Map<String, double> accountAllocations;

  const SavingGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.savedAmount,
    this.imagePath = 'assets/images/Saving_Goal_Icon.png',
    this.category = 'goal',
    this.status = 'active',
    this.targetDate,
    this.priority = 1,
    this.allocationMode = AllocationMode.globalPercent,
    this.accountAllocations = const {'*': 30.0},
  });

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    final pct = (savedAmount / targetAmount) * 100;
    return pct > 100 ? 100.0 : (pct < 0 ? 0.0 : pct);
  }

  double get remainingAmount {
    final rem = targetAmount - savedAmount;
    return rem < 0 ? 0.0 : rem;
  }

  bool get isCompleted => savedAmount >= targetAmount;

  SavingGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? savedAmount,
    String? imagePath,
    String? category,
    String? status,
    String? targetDate,
    int? priority,
    AllocationMode? allocationMode,
    Map<String, double>? accountAllocations,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      imagePath: imagePath ?? this.imagePath,
      category: category ?? this.category,
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      priority: priority ?? this.priority,
      allocationMode: allocationMode ?? this.allocationMode,
      accountAllocations: accountAllocations ?? this.accountAllocations,
    );
  }

  static String _modeToString(AllocationMode m) {
    switch (m) {
      case AllocationMode.accountSpecific: return 'account_specific';
      case AllocationMode.multiAccount:    return 'multi_account';
      case AllocationMode.globalPercent:   return 'global_percent';
    }
  }

  static AllocationMode _modeFromString(String? s) {
    switch (s) {
      case 'account_specific': return AllocationMode.accountSpecific;
      case 'multi_account':    return AllocationMode.multiAccount;
      default:                 return AllocationMode.globalPercent;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'targetAmount': targetAmount,
      'savedAmount': savedAmount,
      'imagePath': imagePath,
      'category': category,
      'status': status,
      'targetDate': targetDate,
      'priority': priority,
      'allocation_mode': _modeToString(allocationMode),
      'account_allocations': json.encode(
          accountAllocations.map((k, v) => MapEntry(k, v))),
    };
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map) {
    // Parse accountAllocations from JSON string (nullable for legacy rows)
    Map<String, double> allocations = const {'*': 30.0};
    final allocJson = map['account_allocations'];
    if (allocJson != null && allocJson.toString().isNotEmpty) {
      try {
        final decoded = json.decode(allocJson.toString()) as Map<String, dynamic>;
        allocations = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }
    return SavingGoal(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0.0,
      imagePath: map['imagePath']?.toString() ?? 'assets/images/Saving_Goal_Icon.png',
      category: map['category']?.toString() ?? 'goal',
      status: map['status']?.toString() ?? 'active',
      targetDate: map['targetDate']?.toString(),
      priority: (map['priority'] as num?)?.toInt() ?? 1,
      allocationMode: _modeFromString(map['allocation_mode']?.toString()),
      accountAllocations: allocations,
    );
  }

  String toJson() => json.encode(toMap());

  factory SavingGoal.fromJson(String source) => SavingGoal.fromMap(json.decode(source));
}
