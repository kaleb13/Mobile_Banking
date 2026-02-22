import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final SmsQuery query = SmsQuery();

  Future<bool> requestPermission() async {
    var permission = await Permission.sms.status;
    if (permission.isGranted) {
      return true;
    } else {
      var newPermission = await Permission.sms.request();
      return newPermission.isGranted;
    }
  }

  Future<List<SmsMessage>> getAllMessages({DateTime? since}) async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) return [];

    List<SmsMessage> messages = await query.querySms(
      kinds: [SmsQueryKind.inbox],
      count: 1000,
    );

    // Filter out messages that arrived before 'since' if provided
    if (since != null) {
      return messages.where((msg) {
        if (msg.date == null) return false;
        return msg.date!.isAfter(since);
      }).toList();
    }

    return messages;
  }

  Future<List<String>> getUniqueSenders() async {
    List<SmsMessage> messages = await getAllMessages();
    Set<String> uniqueSenders = {};

    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    final transactionRegex = RegExp(
      r'(rs\.?|inr|₹|\$|credited|debited|spent|txn|balance|a/c|account)',
      caseSensitive: false,
    );

    for (var msg in messages) {
      if (msg.sender != null && msg.sender!.isNotEmpty) {
        String sender = msg.sender!;
        String body = msg.body ?? '';

        bool looksLikeBank = !phoneRegex.hasMatch(sender);
        bool hasTxn = transactionRegex.hasMatch(body);

        if (looksLikeBank || hasTxn) {
          uniqueSenders.add(sender);
        }
      }
    }
    return uniqueSenders.toList();
  }

  // --- Smart Parser logic ---
  static double extractAmount(String message) {
    // Basic regex to find amounts, e.g., RS 500, ₹450, 20.00
    // Looks for numbers with optional decimals
    RegExp regExp = RegExp(
      r'(?:Rs|INR|₹|ETB|\$)?\s?(\d+(?:,\d{3})*(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    var matches = regExp.allMatches(message);
    if (matches.isNotEmpty) {
      // Find the first match that looks like an amount
      // or the largest amount, but first match is usually the transaction amount
      String amountStr = matches.first.group(1) ?? "0";
      amountStr = amountStr.replaceAll(',', '');
      return double.tryParse(amountStr) ?? 0.0;
    }
    return 0.0;
  }
}
