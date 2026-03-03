import '../models/transaction.dart';
import 'package:intl/intl.dart';

class CbeBirrParser {
  static const String senderName = "CBEBirr";
  static const String senderNameFormatted = "CBE Birr";

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Ignore Voucher Messages
    if (lowerMsg.contains('request') || lowerMsg.contains('voucher')) {
      return null;
    }

    String type = '';
    String category = '';
    double amount = 0.0;
    String senderOrRecipient = 'From your CBE or unknown';
    String dateStr = '';

    // 2. Classify and Extract
    if (lowerMsg.contains("withdrawn") && lowerMsg.contains("atm")) {
      category = "Cash";
      type = "expense";
      final amountMatch =
          RegExp(r'withdrawn\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("credited")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'credited with\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("received")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'received\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      final senderMatch = RegExp(r'from\s+(.*?)\s+on', caseSensitive: false)
          .firstMatch(message);
      if (senderMatch != null) {
        String rawSender = senderMatch.group(1)!.trim();
        // Strip leading phone number: "251921607264 - nahom abreham" → "nahom abreham"
        final dashSplit = rawSender.split(' - ');
        if (dashSplit.length >= 2 &&
            RegExp(r'^\d+$').hasMatch(dashSplit.first.trim())) {
          senderOrRecipient = dashSplit.sublist(1).join(' - ').trim();
        } else {
          senderOrRecipient = rawSender;
        }
      }

      final dateMatch =
          RegExp(r'on\s+(.*?)(\s*,eqn|\s*,txn id)', caseSensitive: false)
              .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("sent") ||
        lowerMsg.contains("paid") ||
        lowerMsg.contains("transferred")) {
      category = "Transferred";
      type = "expense";
      final amountMatch = RegExp(r'(?:sent|paid|transferred)\s+([0-9.,]+)br\.?',
              caseSensitive: false)
          .firstMatch(message);
      if (amountMatch != null) {
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      final recipMatch =
          RegExp(r'to\s+(.*?)\s+on', caseSensitive: false).firstMatch(message);
      if (recipMatch != null) {
        String rawRecip = recipMatch.group(1)!.trim();
        rawRecip = rawRecip
            .replaceAll(
                RegExp(r'by Acc\. number\s+[0-9]+', caseSensitive: false), '')
            .trim();
        if (rawRecip.isNotEmpty) senderOrRecipient = rawRecip;
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // 3. Extract Txn ID
    String? id;
    final idMatch = RegExp(r'txn id\s+([A-Z0-9]+)', caseSensitive: false)
        .firstMatch(message);
    if (idMatch != null) {
      id = idMatch.group(1);
    } else {
      // Revert if Txn ID is required for CBEBirr
      return null;
    }

    // 4. Extract Total Balance
    double totalBalance = 0.0;
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final balanceMatch =
        RegExp(r'(?:account\s+)?balance is\s+([0-9.,]+)', caseSensitive: false)
            .firstMatch(singleLineMsg);
    if (balanceMatch != null) {
      String strippedBalance = balanceMatch.group(1)!.replaceAll(',', '');
      if (strippedBalance.endsWith('.')) {
        strippedBalance =
            strippedBalance.substring(0, strippedBalance.length - 1);
      }
      totalBalance = double.tryParse(strippedBalance) ?? 0.0;
    }

    // 5. Extract Date
    DateTime txDate = fallbackDate;
    if (dateStr.isNotEmpty) {
      try {
        final format = DateFormat('dd/MM/yy HH:mm');
        txDate = format.parse(dateStr);
      } catch (e) {
        try {
          final formatFallback = DateFormat('yy/MM/dd HH:mm');
          txDate = formatFallback.parse(dateStr);
        } catch (e2) {
          // ignore
        }
      }
    }

    return AppTransaction(
      id: id,
      name: senderNameFormatted,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderOrRecipient,
      category: category,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
    );
  }
}
