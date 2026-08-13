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
}
