class AppReason {
  final int? id;
  final String name;
  final bool isSystem;

  AppReason({
    this.id,
    required this.name,
    this.isSystem = false,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'isSystem': isSystem ? 1 : 0,
    };
  }

  factory AppReason.fromMap(Map<String, dynamic> map) {
    return AppReason(
      id: map['id'] as int?,
      name: map['name'] as String,
      isSystem: (map['isSystem'] as int) == 1,
    );
  }

  AppReason copyWith({String? name}) {
    return AppReason(id: id, name: name ?? this.name, isSystem: isSystem);
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
