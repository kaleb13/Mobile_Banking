class AppNotification {
  final String id;
  final String sender;
  final String body;
  final DateTime date;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.sender,
    required this.body,
    required this.date,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sender': sender,
        'body': body,
        'date': date.toIso8601String(),
        'isRead': isRead ? 1 : 0,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        sender: map['sender'] as String,
        body: map['body'] as String,
        date: DateTime.parse(map['date'] as String),
        isRead: (map['isRead'] as int) == 1,
      );
}
