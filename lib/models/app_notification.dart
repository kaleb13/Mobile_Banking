class AppNotification {
  final String id;
  final String sender;
  final String body;
  final DateTime date;
  final bool isRead;
  final String? reason;

  AppNotification({
    required this.id,
    required this.sender,
    required this.body,
    required this.date,
    this.isRead = false,
    this.reason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': sender,
        'body': body,
        'date': date.toIso8601String(),
        'isRead': isRead ? 1 : 0,
        'reason': reason,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        sender: map['sender'] as String,
        body: map['body'] as String,
        date: DateTime.parse(map['date'] as String),
        isRead: (map['isRead'] as int) == 1,
        reason: map['reason'] as String?,
      );

  AppNotification copyWith({
    String? id,
    String? sender,
    String? body,
    DateTime? date,
    bool? isRead,
    String? reason,
  }) {
    return AppNotification(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      date: date ?? this.date,
      isRead: isRead ?? this.isRead,
      reason: reason ?? this.reason,
    );
  }

  /// Unified sender name for UI display & filtering (normalizes '127' to 'Telebirr').
  String get displaySender {
    final s = sender.trim();
    if (s == '127' || s.toLowerCase() == 'telebirr') return 'Telebirr';
    return s;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
