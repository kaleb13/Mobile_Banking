import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/parsed_sms_result.dart';
import 'package:intl/intl.dart';

class ZemenParser {
  static const String senderName = "Zemen Bank";

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Must contain banking transactional cues
    if (!lowerMsg.contains('withdrawn') &&
        !lowerMsg.contains('credited') &&
        !lowerMsg.contains('debited') &&
        !lowerMsg.contains('transferred') &&
        !lowerMsg.contains('transfer') &&
        !lowerMsg.contains('available bal') &&
        !lowerMsg.contains('available balance') &&
        !lowerMsg.contains('bal.') &&
        !lowerMsg.contains('zemen')) {
      return null;
    }

    String type = '';
    double amount = 0.0;
    String counterparty = '';
    double totalBalance = 0.0;
    String? id;
    DateTime txDate = fallbackDate;
    SmsPatternType patternType = SmsPatternType.standardTransfer;

    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

    double parseAmount(RegExp regex) {
      final match = regex.firstMatch(singleLine);
      if (match != null) {
        String amtStr = match.group(1)?.replaceAll(',', '').trim() ?? '0';
        if (amtStr.endsWith('.')) {
          amtStr = amtStr.substring(0, amtStr.length - 1);
        }
        return double.tryParse(amtStr) ?? 0.0;
      }
      return 0.0;
    }

    // ── 1. ATM Cash Withdrawal (Debit) ──────────────────────────────────────
    if (lowerMsg.contains('withdrawn') && lowerMsg.contains('atm')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+has\s+been\s+withdrawn', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'withdrawn\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final atmBranchMatch = RegExp(r'via\s+ATM(?:\s+at\s+(.*?))?\s+on', caseSensitive: false).firstMatch(singleLine);
      if (atmBranchMatch != null && atmBranchMatch.group(1) != null && atmBranchMatch.group(1)!.trim().isNotEmpty) {
        counterparty = 'ATM (${atmBranchMatch.group(1)!.trim()})';
      } else {
        counterparty = 'ATM Cash Withdrawal';
      }
    }
    // ── 2. Inward RTGS / IPS Transfer (Credit) ──────────────────────────────
    else if (lowerMsg.contains('inward') && lowerMsg.contains('transfer')) {
      type = 'income';
      amount = parseAmount(RegExp(r'transfer\s+of\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      final fromMatch = RegExp(r'from\s+(.*?)\s+to\s+your\s+account', caseSensitive: false).firstMatch(singleLine);
      counterparty = fromMatch?.group(1)?.trim() ?? 'Inward RTGS Transfer';
    }
    // ── 3. POS Purchase / Merchant Debit ────────────────────────────────────
    else if (lowerMsg.contains('pos transaction') || lowerMsg.contains('pos purchase') || (lowerMsg.contains('debited') && lowerMsg.contains('pos'))) {
      type = 'expense';
      amount = parseAmount(RegExp(r'debited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      final atMatch = RegExp(r'at\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      counterparty = atMatch?.group(1)?.trim() ?? 'POS Purchase';
    }
    // ── 4. Telebirr Wallet Outward Transfer ─────────────────────────────────
    else if (lowerMsg.contains('telebirr') && lowerMsg.contains('transferred')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+transferred', caseSensitive: false));
      if (amount <= 0) return null;

      final phoneMatch = RegExp(r'Telebirr\s+Wallet\s+([0-9+]+)', caseSensitive: false).firstMatch(singleLine);
      if (phoneMatch != null) {
        counterparty = 'Telebirr (${phoneMatch.group(1)!.trim()})';
      } else {
        counterparty = 'Telebirr Wallet';
      }
    }
    // ── 5. Airtime Top-up ───────────────────────────────────────────────────
    else if (lowerMsg.contains('airtime')) {
      type = 'expense';
      patternType = SmsPatternType.telebirrAirtime;
      amount = parseAmount(RegExp(r'debited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      counterparty = 'Airtime';
    }
    // ── 6. Direct Transfer / P2P Outbound ───────────────────────────────────
    else if (lowerMsg.contains('transferred from account') || lowerMsg.contains('transferred to')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+transferred', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'transferred\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final toMatch = RegExp(r'to\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      counterparty = toMatch?.group(1)?.trim() ?? 'Transfer Out';
    }
    // ── 7. Direct Deposit / Salary / Credited Inward ────────────────────────
    else if (lowerMsg.contains('credited with') || lowerMsg.contains('credited')) {
      type = 'income';
      amount = parseAmount(RegExp(r'credited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+has\s+been\s+credited', caseSensitive: false));
      }
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'credited\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final byMatch = RegExp(r'(?:by|from)\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      if (byMatch != null) {
        counterparty = byMatch.group(1)?.trim() ?? 'Deposit';
      } else {
        final fallbackByMatch = RegExp(r'(?:by|from)\s+(.*?)(?=\.\s*A/c|\.\s*Available|\.|\n|$)', caseSensitive: false).firstMatch(singleLine);
        counterparty = fallbackByMatch?.group(1)?.trim() ?? 'Deposit';
      }
    }
    // ── 8. Utility Payment or Generic Debit ─────────────────────────────────
    else if (lowerMsg.contains('debited with') || lowerMsg.contains('debited')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'debited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+debited', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final forMatch = RegExp(r'for\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      if (forMatch != null) {
        counterparty = forMatch.group(1)?.trim() ?? 'Payment';
      } else {
        final fallbackForMatch = RegExp(r'for\s+(.*?)(?=\.\s*Available|\.\s*A/c|\.|\n|$)', caseSensitive: false).firstMatch(singleLine);
        counterparty = fallbackForMatch?.group(1)?.trim() ?? 'Debit';
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // ── Extract Transaction ID / Reference ──────────────────────────────────
    final refMatch = RegExp(
      r'(?:Ref|Txn\s*ID|Transaction\s*ID|Reference)[:\s]+([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    if (refMatch != null) {
      id = refMatch.group(1)?.trim();
    } else {
      final norm = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hash = sha256.convert(utf8.encode('ZEMEN|$norm')).toString();
      id = 'ZEMEN-${hash.substring(0, 16).toUpperCase()}';
    }

    // ── Extract Available Balance ───────────────────────────────────────────
    final balMatch = RegExp(
      r'(?:A/c\s+Available\s+Bal\.|Available\s+balance|Available\s+Bal\.|Bal\.)\s*(?:is\s*)?(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    if (balMatch != null) {
      String bStr = balMatch.group(1)?.replaceAll(',', '').trim() ?? '0';
      if (bStr.endsWith('.')) {
        bStr = bStr.substring(0, bStr.length - 1);
      }
      totalBalance = double.tryParse(bStr) ?? 0.0;
    }

    // ── Extract Date ────────────────────────────────────────────────────────
    final dateMatch = RegExp(
      r'on\s+(\d{1,2}/\d{1,2}/\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    if (dateMatch != null) {
      final rawDateStr = dateMatch.group(1)!.trim();
      final dateFormats = [
        'dd/MM/yyyy HH:mm:ss',
        'dd/MM/yyyy HH:mm',
        'dd/MM/yyyy',
        'dd/MM/yy HH:mm:ss',
        'dd/MM/yy HH:mm',
        'dd/MM/yy',
      ];
      for (final fmt in dateFormats) {
        try {
          txDate = DateFormat(fmt).parse(rawDateStr);
          break;
        } catch (_) {}
      }
    }

    return ParsedSmsResult(
      id: id!,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: counterparty,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: patternType,
    );
  }

  /// Extracts the account owner name from welcome or profile messages if present.
  static String? extractOwnerName(String message) {
    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final dearMatch = RegExp(r'Dear\s+([A-Za-z\s]+?),', caseSensitive: false).firstMatch(singleLine);
    if (dearMatch != null) {
      final name = dearMatch.group(1)?.trim();
      if (name != null &&
          name.isNotEmpty &&
          name.toLowerCase() != 'customer' &&
          name.toLowerCase() != 'valued customer') {
        return name;
      }
    }
    return null;
  }
}
