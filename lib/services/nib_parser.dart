import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/parsed_sms_result.dart';
import 'package:intl/intl.dart';

class NibParser {
  static const String senderName = "Nib Bank";

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Must contain banking transactional cues
    if (!lowerMsg.contains('credited') &&
        !lowerMsg.contains('debited') &&
        !lowerMsg.contains('transferred') &&
        !lowerMsg.contains('purchased airtime') &&
        !lowerMsg.contains('paid') &&
        !lowerMsg.contains('available balance') &&
        !lowerMsg.contains('nib')) {
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

    // ── 1. Airtime Purchase ──────────────────────────────────────────────────
    if (lowerMsg.contains('purchased airtime')) {
      type = 'expense';
      patternType = SmsPatternType.telebirrAirtime;
      amount = parseAmount(RegExp(r'airtime\s+of\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final forMatch = RegExp(r'for\s+([0-9+]+)', caseSensitive: false).firstMatch(singleLine);
      if (forMatch != null) {
        counterparty = 'Airtime (${forMatch.group(1)!.trim()})';
      } else {
        counterparty = 'Airtime';
      }
    }
    // ── 2. Utility / Bill Payment ────────────────────────────────────────────
    else if (lowerMsg.contains('paid') && lowerMsg.contains('for')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'paid\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final forMatch = RegExp(r'for\s+(.*?)\s+from\s+A/C', caseSensitive: false).firstMatch(singleLine);
      if (forMatch != null) {
        counterparty = forMatch.group(1)!.trim();
      } else {
        final fallbackFor = RegExp(r'for\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
        counterparty = fallbackFor?.group(1)?.trim() ?? 'Bill Payment';
      }
    }
    // ── 3. ATM Cash Withdrawal ───────────────────────────────────────────────
    else if (lowerMsg.contains('debited') && lowerMsg.contains('atm')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'debited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'total\s+debited:\s*(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final atmMatch = RegExp(r'at\s+(ATM\s+[A-Za-z0-9\s]+?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      counterparty = atmMatch?.group(1)?.trim() ?? 'ATM Cash Withdrawal';
    }
    // ── 4. Outbound Transfer ─────────────────────────────────────────────────
    else if (lowerMsg.contains('transferred') && lowerMsg.contains('to')) {
      type = 'expense';
      amount = parseAmount(RegExp(r'transferred\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final toMatch = RegExp(r'to\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      counterparty = toMatch?.group(1)?.trim() ?? 'Transfer Out';
    }
    // ── 5. Inbound IPS Transfer ──────────────────────────────────────────────
    else if (lowerMsg.contains('credited') && lowerMsg.contains('via ips')) {
      type = 'income';
      amount = parseAmount(RegExp(r'credited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) return null;

      final fromMatch = RegExp(r'from\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      if (fromMatch != null) {
        counterparty = '${fromMatch.group(1)!.trim()} via IPS';
      } else {
        counterparty = 'IPS Inward Transfer';
      }
    }
    // ── 6. Inbound Credit / P2P / Salary ─────────────────────────────────────
    else if (lowerMsg.contains('credited')) {
      type = 'income';
      amount = parseAmount(RegExp(r'credited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)\s+by', caseSensitive: false));
      }
      if (amount <= 0) return null;

      final byMatch = RegExp(r'by\s+(.*?)\s+on\s+\d{1,2}/\d{1,2}/\d{2,4}', caseSensitive: false).firstMatch(singleLine);
      if (byMatch != null) {
        counterparty = byMatch.group(1)!.trim();
      } else {
        final fallbackBy = RegExp(r'by\s+(.*?)(?=\.\s*Available|\.|\n|$)', caseSensitive: false).firstMatch(singleLine);
        counterparty = fallbackBy?.group(1)?.trim() ?? 'Deposit';
      }
    }
    // ── 7. Direct Debit with optional Service Charge / Total Debited ────────
    else if (lowerMsg.contains('debited')) {
      type = 'expense';
      // Prefer Total Debited if specified to accurately reflect ledger change
      amount = parseAmount(RegExp(r'total\s+debited:\s*(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      if (amount <= 0) {
        amount = parseAmount(RegExp(r'debited\s+with\s+(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]+)?)', caseSensitive: false));
      }
      if (amount <= 0) return null;

      counterparty = 'Debit';
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
      final hash = sha256.convert(utf8.encode('NIB|$norm')).toString();
      id = 'NIB-${hash.substring(0, 16).toUpperCase()}';
    }

    // ── Extract Available Balance ───────────────────────────────────────────
    final balMatch = RegExp(
      r'(?:Available\s+Balance|Available\s+Bal\.|Bal\.)[:\s]+(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)',
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
