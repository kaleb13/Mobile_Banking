import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/parsed_sms_result.dart';

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
    if (lower.contains('token number for today')) {
      return true;
    }

    // Ignore OTP / auth codes
    if (lower.contains('use otp') ||
        lower.contains('otp code') ||
        lower.contains('boa_kyc')) {
      return true;
    }

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
    if (!lower.contains('debited') && !lower.contains('credited')) {
      return true;
    }

    return false;
  }

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (shouldIgnore(message)) return null;

    final lowerMsg = message.toLowerCase();

    String type = '';
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
    } else {
      final textRef = RegExp(r'(?:Ref(?:\s*No)?|Txn(?:\s*ID)?)\s*:?\s*([A-Za-z0-9]+)', caseSensitive: false).firstMatch(message);
      if (textRef != null) {
        refId = textRef.group(1)?.trim();
      }
    }

    // Extract Total Available Balance
    final balMatch = RegExp(
      r'(?:Available\s+Balance|Current\s+Balance|Balance)\s*(?:is|:)?\s*(?:ETB|Birr|Br\.?)?\s*([0-9,.]+)',
      caseSensitive: false,
    ).firstMatch(message);
    if (balMatch != null) {
      String balStr = balMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (balStr.endsWith('.')) {
        balStr = balStr.substring(0, balStr.length - 1);
      }
      totalBalance = double.tryParse(balStr) ?? 0.0;
    }

    // Extract date if present: "on 12-Nov-2023 14:20" or "on 12/11/2023"
    final dateMatch = RegExp(
            r'on\s+(\d{1,2}-[A-Za-z]{3}-\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?|\d{1,2}/\d{1,2}/\d{2,4})')
        .firstMatch(message);
    if (dateMatch != null) {
      final dStr = dateMatch.group(1)!;
      try {
        final parts = dStr.split(' ');
        final dPart = parts[0];
        final tPart = parts.length > 1 ? parts[1] : '00:00';
        final dParts = dPart.contains('-') ? dPart.split('-') : dPart.split('/');
        final day = int.parse(dParts[0]);
        final monthStr = dParts[1];
        final year = int.parse(dParts[2].length == 2 ? '20${dParts[2]}' : dParts[2]);
        int month = 1;
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        final mIdx = months.indexOf(monthStr.toLowerCase());
        if (mIdx != -1) {
          month = mIdx + 1;
        } else {
          month = int.tryParse(monthStr) ?? 1;
        }
        final tParts = tPart.split(':');
        final hour = int.parse(tParts[0]);
        final min = int.parse(tParts[1]);
        txDate = DateTime(year, month, day, hour, min);
      } catch (_) {
        txDate = fallbackDate;
      }
    }

    // 1. Expense / Debit parsing
    if (lowerMsg.contains('debited')) {
      type = 'expense';
      amount = extractAmount(RegExp(
        r'debited\s+(?:with\s+)?(?:ETB|Birr|Br\.?)?\s*([0-9,.]+)',
        caseSensitive: false,
      ));

      final toMatch = RegExp(
        r'to\s+(.*?)\s+(?:on\s+|\.|\n|Available|Receipt|Link|Feedback)',
        caseSensitive: false,
      ).firstMatch(message);
      if (toMatch != null) {
        recipientOrSender = toMatch.group(1)?.trim() ?? '';
      }
      if (recipientOrSender.isEmpty) {
        recipientOrSender = senderName;
      }
    }
    // 2. Income / Credit parsing
    else if (lowerMsg.contains('credited')) {
      type = 'income';
      amount = extractAmount(RegExp(
        r'credited\s+(?:with\s+)?(?:ETB|Birr|Br\.?)?\s*([0-9,.]+)',
        caseSensitive: false,
      ));

      final byMatch = RegExp(
        r'by\s+(.*?)(?:\s*\.|\n|Available|Receipt|Link|Feedback)',
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

    final String id;
    if (refId != null) {
      id = 'boa_ref_$refId';
    } else {
      final normalised = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hash = sha256.convert(utf8.encode(normalised)).toString();
      id = 'BOA-${hash.substring(0, 16)}';
    }

    return ParsedSmsResult(
      id: id,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: recipientOrSender.isNotEmpty ? recipientOrSender : senderName,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: SmsPatternType.standardTransfer,
    );
  }
}
