import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/parsed_sms_result.dart';

/// Pure-fact SMS parser for Bunna Bank (Buna Bank).
///
/// Strictly conforms to Layer 1 architecture:
/// - Extracts ONLY the 8 objective facts in [ParsedSmsResult]
/// - No derived UI getters, buttons, or database logic
class BunnaParser {
  static const String senderName = "Bunna Bank";

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Must contain Bunna banking transactional cues
    final hasTransactionCues = (lowerMsg.contains('deposit') ||
            lowerMsg.contains('withdrawal') ||
            lowerMsg.contains('credited') ||
            lowerMsg.contains('debited') ||
            lowerMsg.contains('transferred')) &&
        (lowerMsg.contains('current balance is') ||
            lowerMsg.contains('balance is') ||
            lowerMsg.contains('account') ||
            lowerMsg.contains('bunna') ||
            lowerMsg.contains('buna'));

    if (!hasTransactionCues) {
      return null;
    }

    // Ignore OTP, PIN, security warnings, or non-transaction alerts
    if (lowerMsg.contains('otp') ||
        lowerMsg.contains('pin number has been changed') ||
        lowerMsg.contains('fayda harmonization') ||
        lowerMsg.contains('never share pins')) {
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

    // ── 1. Deposit (Income) ──────────────────────────────────────────────────
    // e.g. "A Deposit of 40,000.00 ETB has been made to your account 426*******611 BY IPS /INCOMMING/ABYSETAA/ABYSETAAFT26155FLQKV on 04-06-2026 15:27:53, your current balance is 40,000.00 ETB."
    // e.g. "A Deposit of 40,000.00 ETB has been made to your account 426*******611 BY FROM DMK TECHNOLOGY PLC '' UNDER FORMATION'' on 05-08-2026 16:22:12..."
    if (lowerMsg.contains('deposit')) {
      type = 'income';
      amount = parseAmount(RegExp(
        r'deposit\s+of\s+([0-9,]+(?:\.[0-9]+)?)\s*(?:ETB|Birr)?',
        caseSensitive: false,
      ));
      if (amount <= 0) {
        amount = parseAmount(RegExp(
          r'(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:ETB|Birr)?\s+has\s+been\s+made\s+to\s+your\s+account',
          caseSensitive: false,
        ));
      }
      if (amount <= 0) return null;

      // Extract counterparty after "BY" or "by"
      final byMatch = RegExp(
        r'(?:BY|by)\s+(.*?)\s+on\s+\d{2}[-/]\d{2}[-/]\d{2,4}',
        caseSensitive: false,
      ).firstMatch(singleLine);

      if (byMatch != null) {
        String rawCp = byMatch.group(1)!.trim();
        // Clean leading FROM / TO if present
        if (rawCp.toUpperCase().startsWith('FROM ')) {
          rawCp = rawCp.substring(5).trim();
        } else if (rawCp.toUpperCase().startsWith('TO ')) {
          rawCp = rawCp.substring(3).trim();
        }

        // Check for IPS reference in counterparty: e.g. IPS /INCOMMING/ABYSETAA/ABYSETAAFT26155FLQKV
        final ipsMatch = RegExp(r'IPS\s*/INCOMMING/([^/]+)/([A-Za-z0-9]+)', caseSensitive: false).firstMatch(rawCp);
        if (ipsMatch != null) {
          final bankCode = ipsMatch.group(1)?.trim();
          id = ipsMatch.group(2)?.trim();
          counterparty = bankCode != null && bankCode.isNotEmpty ? 'IPS ($bankCode)' : 'IPS Inward';
        } else {
          counterparty = rawCp;
        }
      } else {
        counterparty = 'Deposit';
      }
    }
    // ── 2. Withdrawal (Expense) ──────────────────────────────────────────────
    // e.g. "A Withdrawal of 40,000.00 ETB has been made from your account 426*******611 on 04-06-2026 15:39:51 by TO DMK TECHNOLOGY PLC '' UNDER FORMATION'', your current balance is 100.00 ETB."
    // e.g. "A Withdrawal of 56.00 ETB has been made from your account 426*******611 on 08-07-2026 23:20:14 by TELEBIRR TRANSFER, your current balance is 44.00 ETB."
    // e.g. "A Withdrawal of 2,012.00 ETB has been made from your account 426*******611 on 08-08-2026 16:01:11 by IPS OUT GOING, your current balance is 38,032.00 ETB."
    else if (lowerMsg.contains('withdrawal')) {
      type = 'expense';
      amount = parseAmount(RegExp(
        r'withdrawal\s+of\s+([0-9,]+(?:\.[0-9]+)?)\s*(?:ETB|Birr)?',
        caseSensitive: false,
      ));
      if (amount <= 0) {
        amount = parseAmount(RegExp(
          r'(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:ETB|Birr)?\s+has\s+been\s+made\s+from\s+your\s+account',
          caseSensitive: false,
        ));
      }
      if (amount <= 0) return null;

      // Extract counterparty after "by" or "BY"
      final byMatch = RegExp(
        r'(?:by|BY)\s+(.*?)(?=,\s*(?:your\s+)?current\s+balance|\.\s*(?:your\s+)?current\s+balance|\s+(?:your\s+)?current\s+balance|\.\s*Please|\s*Please|\n|$)',
        caseSensitive: false,
      ).firstMatch(singleLine);

      if (byMatch != null) {
        String rawCp = byMatch.group(1)!.trim();
        // Clean trailing comma / dot
        if (rawCp.endsWith(',') || rawCp.endsWith('.')) {
          rawCp = rawCp.substring(0, rawCp.length - 1).trim();
        }
        // Clean leading TO / FROM
        if (rawCp.toUpperCase().startsWith('TO ')) {
          rawCp = rawCp.substring(3).trim();
        } else if (rawCp.toUpperCase().startsWith('FROM ')) {
          rawCp = rawCp.substring(5).trim();
        }

        if (rawCp.toUpperCase() == 'TELEBIRR TRANSFER') {
          counterparty = 'Telebirr Transfer';
        } else if (rawCp.toUpperCase() == 'IPS OUT GOING' || rawCp.toUpperCase() == 'IPS OUTGOING') {
          counterparty = 'IPS Outgoing';
        } else {
          counterparty = rawCp;
        }
      } else {
        counterparty = 'Withdrawal';
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // ── Extract Transaction ID / Reference ──────────────────────────────────
    if (id == null) {
      final refMatch = RegExp(
        r'(?:Ref|Txn\s*ID|Transaction\s*ID|Reference)[:\s]+([A-Za-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(singleLine);
      if (refMatch != null) {
        id = refMatch.group(1)?.trim();
      }
    }

    // If still null, check for receipt URL hash token if present
    if (id == null) {
      final urlMatch = RegExp(r'receipt/#/([A-Za-z0-9+/=_-]{12,})').firstMatch(singleLine);
      if (urlMatch != null) {
        final hashToken = urlMatch.group(1)!.replaceAll('/', '').replaceAll('+', '').replaceAll('=', '');
        final snippet = hashToken.length > 14 ? hashToken.substring(0, 14) : hashToken;
        id = 'BUNNA-$snippet';
      }
    }

    // Deterministic fallback hash ensuring idempotency
    if (id == null || id.isEmpty) {
      final norm = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hash = sha256.convert(utf8.encode('BUNNA|$norm')).toString();
      id = 'BUNNA-${hash.substring(0, 16).toUpperCase()}';
    }

    // ── Extract Total / Current Balance ──────────────────────────────────────
    final balMatch = RegExp(
      r'(?:your\s+)?current\s+balance\s+is\s*([0-9,]+(?:\.[0-9]+)?)\s*(?:ETB|Birr)?',
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
      r'on\s+(\d{2}[-/]\d{2}[-/]\d{2,4}(?:\s+\d{1,2}:\d{2}(?::\d{2})?)?)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    if (dateMatch != null) {
      final rawDateStr = dateMatch.group(1)!.trim();
      final dateFormats = [
        'dd-MM-yyyy HH:mm:ss',
        'dd-MM-yyyy HH:mm',
        'dd-MM-yyyy',
        'dd/MM/yyyy HH:mm:ss',
        'dd/MM/yyyy HH:mm',
        'dd/MM/yyyy',
        'dd-MM-yy HH:mm:ss',
        'dd/MM/yy HH:mm:ss',
      ];
      for (final fmt in dateFormats) {
        try {
          txDate = DateFormat(fmt).parse(rawDateStr);
          break;
        } catch (_) {}
      }
    }

    return ParsedSmsResult(
      id: id,
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

  /// Extracts customer name if welcome or profile message is encountered.
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
