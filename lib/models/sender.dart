import 'dart:convert';

class AppSender {
  final String? id;
  final String senderName;
  final List<String> depositKeywords;
  final List<String> expenseKeywords;
  final String? accountNumber;
  final String? pin;

  AppSender({
    this.id,
    required this.senderName,
    this.depositKeywords = const [],
    this.expenseKeywords = const [],
    this.accountNumber,
    this.pin,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderName': senderName,
      'depositKeywords': jsonEncode(depositKeywords),
      'expenseKeywords': jsonEncode(expenseKeywords),
      'accountNumber': accountNumber,
      'pin': pin,
    };
  }

  factory AppSender.fromMap(Map<String, dynamic> map) {
    return AppSender(
      id: map['id']?.toString(),
      senderName: map['senderName'],
      depositKeywords: List<String>.from(
        jsonDecode(map['depositKeywords'] ?? '[]'),
      ),
      expenseKeywords: List<String>.from(
        jsonDecode(map['expenseKeywords'] ?? '[]'),
      ),
      accountNumber: map['accountNumber'],
      pin: map['pin'],
    );
  }
}
