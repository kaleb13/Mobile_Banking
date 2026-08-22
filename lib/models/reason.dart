class AppReason {
  final int? id;
  final String name;
  final bool isSystem;
  final int? parentId;
  final bool isSpecial;
  final String? icon;
  final String? color;

  AppReason({
    this.id,
    required this.name,
    this.isSystem = false,
    this.parentId,
    this.isSpecial = false,
    this.icon,
    this.color,
  });

  bool get isSubcategory => parentId != null;
  bool get isTopLevelCategory => parentId == null && !isSpecial;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'isSystem': isSystem ? 1 : 0,
      'parentId': parentId,
      'isSpecial': isSpecial ? 1 : 0,
      'icon': icon,
      'color': color,
    };
  }

  factory AppReason.fromMap(Map<String, dynamic> map) {
    return AppReason(
      id: map['id'] as int?,
      name: map['name'] as String,
      isSystem: (map['isSystem'] as int?) == 1,
      parentId: map['parentId'] as int?,
      isSpecial: (map['isSpecial'] as int?) == 1,
      icon: map['icon'] as String?,
      color: map['color'] as String?,
    );
  }

  AppReason copyWith({
    String? name,
    bool? isSystem,
    int? parentId,
    bool? isSpecial,
    String? icon,
    String? color,
  }) {
    return AppReason(
      id: id,
      name: name ?? this.name,
      isSystem: isSystem ?? this.isSystem,
      parentId: parentId ?? this.parentId,
      isSpecial: isSpecial ?? this.isSpecial,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppReason && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class AppReasonLink {
  final int? id;
  final int reasonId;
  final String linkedName;
  final String linkType; // 'sender' or 'receiver'

  AppReasonLink({
    this.id,
    required this.reasonId,
    required this.linkedName,
    required this.linkType,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'reasonId': reasonId,
      'linkedName': linkedName,
      'linkType': linkType,
    };
  }

  factory AppReasonLink.fromMap(Map<String, dynamic> map) {
    return AppReasonLink(
      id: map['id'] as int?,
      reasonId: map['reasonId'] as int,
      linkedName: map['linkedName'] as String,
      linkType: map['linkType'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppReasonLink && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Scope options when creating an auto-link rule for a counterparty.
enum LinkScope {
  /// Applies the category to all matching past transactions AND auto-categorizes all future transactions.
  allTransactions,

  /// Keeps past transactions unchanged, but auto-categorizes all future incoming transactions.
  futureTransactionsOnly,
}

/// Scope options when removing/unlinking a category for a counterparty.
enum UnlinkScope {
  /// Completely deletes the link rule and resets all matching past transactions to Uncategorized.
  allTransactions,

  /// Unlinks only the current individual transaction; keeps the persistent rule for other past and future transactions.
  thisTransactionOnly,

  /// Deletes the link rule so future transactions are not auto-categorized, but keeps existing past transactions categorized.
  futureTransactionsOnly,
}

