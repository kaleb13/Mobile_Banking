class AppSender {
  final String? id;
  final String senderName;

  AppSender({
    this.id,
    required this.senderName,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': int.tryParse(id!) ?? id,
      'senderName': senderName,
    };
  }

  factory AppSender.fromMap(Map<String, dynamic> map) {
    return AppSender(
      id: map['id']?.toString(),
      senderName: (map['senderName'] ?? '') as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSender &&
          other.id == id &&
          other.senderName.toLowerCase() == senderName.toLowerCase();

  @override
  int get hashCode => Object.hash(id, senderName.toLowerCase());
}

