import '../models/transaction.dart';
import 'package:intl/intl.dart';

class CbeBirrParser {
  static const String senderName = "CBEBirr";
  static const String senderNameFormatted = "CBE Birr";

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Ignore Voucher, PIN, OTP, and Administrative / Error Messages
    if (lowerMsg.contains('request') ||
        lowerMsg.contains('voucher') ||
        lowerMsg.contains('otp') ||
        lowerMsg.contains('wrong pin') ||
        lowerMsg.contains('pin code has been') ||
        lowerMsg.contains('pin is locked') ||
        lowerMsg.contains('please change your pin') ||
        lowerMsg.contains('profile has been updated') ||
        lowerMsg.contains('approved by cbe birr') ||
        lowerMsg.contains('balance is insufficient') ||
        lowerMsg.contains('transaction is cancelled') ||
        lowerMsg.contains('e-money account balance')) {
      return null;
    }

    String type = '';
    String category = 'Auto';
    double amount = 0.0;
    String senderOrRecipient = 'From your CBE or unknown';
    String dateStr = '';

    double parseAmt(String str) {
      return double.tryParse(str.replaceAll(',', '').trim()) ?? 0.0;
    }

    // 2. Classify and Extract

    // A. Cash Out / ATM Withdrawal
    if (lowerMsg.contains("withdrawn") && lowerMsg.contains("atm")) {
      category = "Cash";
      type = "expense";
      final amountMatch =
          RegExp(r'withdrawn\s+([0-9.,]+)\s*br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount = parseAmt(amountMatch.group(1)!);
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    }
    // B. Bought Airtime / Package
    else if (lowerMsg.contains("bought") ||
        (lowerMsg.contains("airtime") && lowerMsg.contains("for"))) {
      category = "Transferred";
      type = "expense";
      final amountMatch =
          RegExp(r'bought\s+([0-9.,]+)\s*br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount = parseAmt(amountMatch.group(1)!);
      }

      final recipMatch = RegExp(r'for\s+([0-9+]+)\s+on', caseSensitive: false)
          .firstMatch(message);
      if (recipMatch != null) {
        senderOrRecipient = 'Airtime (${recipMatch.group(1)!.trim()})';
      } else {
        senderOrRecipient = 'Airtime';
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    }
    // C. Credited / Inward Deposit
    else if (lowerMsg.contains("credited")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'credited with\s+([0-9.,]+)\s*br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount = parseAmt(amountMatch.group(1)!);
      }

      final fromMatch = RegExp(r'from\s+(.*?)\s+on\s+\d{2}/\d{2}',
              caseSensitive: false)
          .firstMatch(message.replaceAll('\n', ' '));
      if (fromMatch != null) {
        senderOrRecipient = fromMatch.group(1)!.trim();
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    }
    // D. Received (Money or Airtime)
    else if (lowerMsg.contains("received")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'received\s+([0-9.,]+)\s*br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null) {
        amount = parseAmt(amountMatch.group(1)!);
      }

      final senderMatch = RegExp(r'from\s+(.*?)\s+on', caseSensitive: false)
          .firstMatch(message);
      if (senderMatch != null) {
        String rawSender = senderMatch.group(1)!.trim();
        // Strip leading phone number if formatted as "251921607264 - nahom abreham"
        final dashSplit = rawSender.split(' - ');
        if (dashSplit.length >= 2 &&
            RegExp(r'^\d+$').hasMatch(dashSplit.first.trim())) {
          senderOrRecipient = dashSplit.sublist(1).join(' - ').trim();
        } else {
          senderOrRecipient = rawSender;
        }
      }

      final dateMatch = RegExp(
              r'on\s+(.*?)(\s*,eqn|\s*,txn id|\s+with txn id)',
              caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    }
    // E. Outgoing Transfer / Payment ("sent", "paid", "transferred", "made X.XXBr. transfer/payment")
    else if (lowerMsg.contains("sent") ||
        lowerMsg.contains("paid") ||
        lowerMsg.contains("transferred") ||
        lowerMsg.contains("made")) {
      category = "Transferred";
      type = "expense";

      var amountMatch = RegExp(
              r'(?:sent|paid|transferred)\s+([0-9.,]+)\s*br\.?',
              caseSensitive: false)
          .firstMatch(message);
      amountMatch ??= RegExp(
              r'made\s+([0-9.,]+)\s*br\.?\s+(?:transfer|payment)',
              caseSensitive: false)
          .firstMatch(message);

      if (amountMatch != null) {
        amount = parseAmt(amountMatch.group(1)!);
      }

      final recipMatch = RegExp(
              r'(?:to|for)\s+(.*?)\s+(?:on|with reference)',
              caseSensitive: false)
          .firstMatch(message);
      if (recipMatch != null) {
        String rawRecip = recipMatch.group(1)!.trim();
        rawRecip = rawRecip
            .replaceAll(
                RegExp(r'by Acc\. number\s+[0-9]+', caseSensitive: false), '')
            .trim();
        if (rawRecip.isNotEmpty) senderOrRecipient = rawRecip;
      }

      final dateMatch = RegExp(
              r'on\s+(.*?)(\.txn id|,txn id|\s+with reference)',
              caseSensitive: false)
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
      final dateFormats = [
        'dd/MM/yy HH:mm',
        'dd-MM-yyyy HH:mm:ss',
        'dd/MM/yyyy HH:mm',
        'yy/MM/dd HH:mm',
      ];
      for (final fmtStr in dateFormats) {
        try {
          txDate = DateFormat(fmtStr).parse(dateStr);
          break;
        } catch (_) {}
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
