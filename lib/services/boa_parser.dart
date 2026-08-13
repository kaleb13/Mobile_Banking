import '../models/transaction.dart';

class BoaParser {
  static const String senderName = "BOA";

  /// Attempts to extract the account holder's name from "Dear NAME,".
  static String? extractOwnerName(String message) {
    final match = RegExp(r'Dear\s+([A-Za-z0-9\s]+?),', caseSensitive: false)
        .firstMatch(message);
    if (match != null) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return null;
  }

  /// Checks if message should be ignored (promotions, queue tokens, security, etc.)
  static bool shouldIgnore(String message) {
    if (message.isEmpty) return true;
    final lower = message.toLowerCase();

    // Ignore Token numbers
    if (lower.contains('token number for today')) return true;

    // Ignore OTP / auth codes
    if (lower.contains('use otp') ||
        lower.contains('otp code') ||
        lower.contains('boa_kyc')) return true;

    // Ignore promotions, holidays, Fayda info, and security alerts
    if (lower.contains('ለጥምቀት') ||
        lower.contains('የጥንቃቄ') ||
        lower.contains('ይጠንቀቁ') ||
        lower.contains('ማሳሰቢያ') ||
        lower.contains('ወደ አሜሪካ') ||
        lower.contains('ቪዛ ካርድ') ||
        lower.contains('welcome!') ||
        lower.contains('paperless') ||
        lower.contains('እድል') ||
        lower.contains('ለ129ኛው') ||
        lower.contains('ለ130ኛው') ||
        lower.contains('አውደዓመቱ') ||
        lower.contains('የዘመን መለወጫ') ||
        lower.contains('spin the wheel') ||
        lower.contains('ይገበያዩ')) {
      return true;
    }

    // Must contain actual transaction keywords
    if (!lower.contains('was debited with') &&
        !lower.contains('was credited with')) {
      return true;
    }

    return false;
  }

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (shouldIgnore(message)) return null;

    final lowerMsg = message.toLowerCase();

    String type = '';
    String category = 'Auto';
    double amount = 0.0;
    double totalBalance = 0.0;
    String recipientOrSender = '';
    DateTime txDate = fallbackDate;

    // Helper: Extract double amount from regex
    double extractAmount(RegExp regex) {
      final match = regex.firstMatch(message);
      if (match != null) {
        String amtStr = match.group(1)?.replaceAll(',', '') ?? '0';
        if (amtStr.endsWith('.')) {
          amtStr = amtStr.substring(0, amtStr.length - 1);
        }
        return double.tryParse(amtStr) ?? 0.0;
      }
      return 0.0;
    }

    // Extract Transaction Reference ID from Receipt URL or text
    String? refId;
    final refMatch = RegExp(r'trx=([A-Za-z0-9]+)', caseSensitive: false).firstMatch(message);
    if (refMatch != null) {
      refId = refMatch.group(1)?.trim();
    }

    // Extract Total Available Balance
    final balMatch = RegExp(
      r'Available\s+Balance:\s*ETB\s*([0-9,.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (balMatch != null) {
      String balStr = balMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (balStr.endsWith('.')) {
        balStr = balStr.substring(0, balStr.length - 1);
      }
      totalBalance = double.tryParse(balStr) ?? 0.0;
    }

    // 1. Expense / Debit parsing
    if (lowerMsg.contains('was debited with')) {
      type = 'expense';
      category = 'Transferred';

      amount = extractAmount(RegExp(
        r'was\s+debited\s+with\s+ETB\s*([0-9,.]+)',
        caseSensitive: false,
      ));

      // Extract recipient name if present (e.g. "to ...")
      final toMatch = RegExp(
        r'to\s+(.*?)\s+(?:on\s+|\.|\n|Available)',
        caseSensitive: false,
      ).firstMatch(message);
      if (toMatch != null) {
        recipientOrSender = toMatch.group(1)?.trim() ?? '';
      }
      if (recipientOrSender.isEmpty) {
        recipientOrSender = 'BOA Transfer';
      }
    }
    // 2. Income / Credit parsing
    else if (lowerMsg.contains('was credited with')) {
      type = 'income';
      category = 'Deposit';

      amount = extractAmount(RegExp(
        r'was\s+credited\s+with\s+ETB\s*([0-9,.]+)',
        caseSensitive: false,
      ));

      // Extract sender/payer name after "by" (e.g., "by Yohannes Bizuneh . Available")
      final byMatch = RegExp(
        r'by\s+(.*?)(?:\s*\.|\n|Available)',
        caseSensitive: false,
      ).firstMatch(message);
      if (byMatch != null) {
        recipientOrSender = byMatch.group(1)?.replaceAll('.', '').trim() ?? '';
      }
      if (recipientOrSender.isEmpty) {
        recipientOrSender = 'BOA Deposit';
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    final id = refId != null
        ? 'boa_ref_$refId'
        : 'boa_${type}_${txDate.year}${txDate.month.toString().padLeft(2, '0')}${txDate.day.toString().padLeft(2, '0')}_${amount.toStringAsFixed(2)}';

    return AppTransaction(
      id: id,
      name: recipientOrSender,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderName,
      category: category,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
      bankReference: refId,
    );
  }
}
