import '../models/transaction.dart';
import 'package:intl/intl.dart';

class TelebirrParser {
  static const String senderNumber = "127";
  static const String senderName = "Telebirr";

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Airtime Check: Ignore airtime messages completely
    if (RegExp(r'received etb [0-9.]+\s*airtime').hasMatch(lowerMsg)) {
      return null;
    }

    // 2. Identify Category & Amount
    String type = '';
    String category = 'Auto';
    double amount = 0.0;
    String senderOrRecipient = '';

    // A helper to extract amount safely
    double extractAmount(RegExp regex) {
      final match = regex.firstMatch(message);
      if (match != null) {
        return double.tryParse(match.group(1)?.replaceAll(',', '') ?? '0') ??
            0.0;
      }
      return 0.0;
    }

    if (lowerMsg.contains('received')) {
      type = 'income';
      amount = extractAmount(RegExp(r'received ETB ([0-9,.]+)'));

      // NEW template: "from Commercial Bank of Ethiopia to your telebirr Account"
      final bankDepositMatch = RegExp(
              r'from\s+(.*?)\s+to your telebirr Account',
              caseSensitive: false)
          .firstMatch(message);
      if (bankDepositMatch != null) {
        senderOrRecipient = bankDepositMatch.group(1)?.trim() ?? '';
      } else {
        // OLD template: "from Amanuel Mandefro(2519****1346) 101305 on "
        final fromMatch = RegExp(r'from\s+(.*?)(?=\s*\(|on\s+\d{2}/\d{2})')
            .firstMatch(message);
        if (fromMatch != null) {
          senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
        }
      }
    } else if (lowerMsg.contains('transferred')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'transferred ETB ([0-9,.]+)'));

      // Extract to: "to Ahadu Bank SC account number 0087364810101 on "
      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        senderOrRecipient = toMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('paid')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'paid ETB ([0-9,.]+)'));

      // Extract for: "for package Hourly unlimited Internet purchase made for 972665987 on "
      final forMatch =
          RegExp(r'for\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (forMatch != null) {
        senderOrRecipient = forMatch.group(1)?.trim() ?? '';
      }
    } else {
      // Must contain received, transferred, or paid
      return null;
    }

    if (amount <= 0) return null; // Safety check

    // 3. Extract Transaction ID
    // Supports both:
    //   OLD: "transaction number is XXXXX"
    //   NEW: "transaction number XXXXX"  (no "is")
    String? id;
    final idRegex = RegExp(r'transaction number(?:\s+is)?\s+([A-Z0-9]+)',
        caseSensitive: false);
    final idMatch = idRegex.firstMatch(message);
    if (idMatch != null) {
      id = idMatch.group(1);
    } else {
      return null; // A valid Telebirr message must have a transaction ID
    }

    // 4. Extract Current Balance
    double totalBalance = 0.0;
    // Strip newlines to make tracing easier
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final balanceMatch =
        RegExp(r'balance is\s+ETB\s+([0-9.,]+)', caseSensitive: false)
            .firstMatch(singleLineMsg);
    if (balanceMatch != null) {
      String strippedBalance =
          balanceMatch.group(1)?.replaceAll(',', '') ?? '0';
      // Safety drop trailing dots if present incorrectly
      if (strippedBalance.endsWith('.')) {
        strippedBalance =
            strippedBalance.substring(0, strippedBalance.length - 1);
      }
      totalBalance = double.tryParse(strippedBalance) ?? 0.0;
    }

    // 5. Extract Date
    // Supports both:
    //   OLD: "on DD/MM/YYYY HH:mm:ss"
    //   NEW: "on YYYY-MM-DD HH:mm:ss"  (ISO-style from bank deposit messages)
    DateTime txDate = fallbackDate;

    // Try OLD format first: dd/MM/yyyy HH:mm:ss
    final oldDateRegex =
        RegExp(r'on\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})');
    final oldDateMatch = oldDateRegex.firstMatch(message);
    if (oldDateMatch != null) {
      try {
        final format = DateFormat('dd/MM/yyyy HH:mm:ss');
        txDate = format.parse(oldDateMatch.group(1)!);
      } catch (e) {
        // use fallbackDate
      }
    } else {
      // Try NEW ISO format: yyyy-MM-dd HH:mm:ss
      final newDateRegex =
          RegExp(r'on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})');
      final newDateMatch = newDateRegex.firstMatch(message);
      if (newDateMatch != null) {
        try {
          final format = DateFormat('yyyy-MM-dd HH:mm:ss');
          txDate = format.parse(newDateMatch.group(1)!);
        } catch (e) {
          // use fallbackDate
        }
      }
    }

    return AppTransaction(
      id: id,
      name: senderName,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderOrRecipient.isNotEmpty ? senderOrRecipient : senderNumber,
      category: category,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
    );
  }
}
