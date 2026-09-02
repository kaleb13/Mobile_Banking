import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import '../models/parsed_sms_result.dart';

class DashenParser {
  static const String senderName = "Dashen Bank";

  /// Attempts to extract the account holder's name from "Dear, NAME Your Account" or "Dear NAME,".
  static String? extractOwnerName(String message) {
    if (message.isEmpty) return null;

    // Pattern 1: "Dear, Nahom Your Account..." or "Dear, Nahom,"
    final matchComma = RegExp(r'Dear,\s*([A-Za-z\s]+?)(?:\s+Your\s+Account|,)',
            caseSensitive: false)
        .firstMatch(message);
    if (matchComma != null) {
      final name = matchComma.group(1)?.trim();
      if (name != null &&
          name.isNotEmpty &&
          !name.toLowerCase().startsWith('customer')) {
        return name;
      }
    }

    // Pattern 2: "Dear Nahom," or "Dear Nahom Your Account"
    final matchSpace = RegExp(r'Dear\s+([A-Za-z\s]+?)(?:\s+Your\s+Account|,)',
            caseSensitive: false)
        .firstMatch(message);
    if (matchSpace != null) {
      final name = matchSpace.group(1)?.trim();
      if (name != null &&
          name.isNotEmpty &&
          !name.toLowerCase().startsWith('customer')) {
        return name;
      }
    }

    return null;
  }

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    // Must be a Dashen Bank transaction or mention Dashen / account / current balance
    if (!lowerMsg.contains('dashen') &&
        !lowerMsg.contains('current balance') &&
        !lowerMsg.contains('account balance') &&
        !lowerMsg.contains('debited') &&
        !lowerMsg.contains('credited') &&
        !lowerMsg.contains('deposited') &&
        !lowerMsg.contains('withdrawn')) {
      return null;
    }

    String type = '';
    double amount = 0.0;
    double totalBalance = 0.0;
    String recipientOrSender = '';
    String? referenceNumber;
    DateTime txDate = fallbackDate;

    // ── Helper: Extract double amount ──────────────────────────────────────
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

    // ── Helper: Extract Reference Number ───────────────────────────────────
    final refMatch = RegExp(
            r'(?:transaction\s*reference|ref\s*no|reference|ref|txn\s*id|txn\s*no)[:\s]*([A-Za-z0-9]+)',
            caseSensitive: false)
        .firstMatch(message);
    if (refMatch != null) {
      referenceNumber = refMatch.group(1)?.trim();
    }

    // ── 1. Determine Type, Category, Amount, Counterparty ──────────────────
    if (lowerMsg.contains('debited') ||
        lowerMsg.contains('debit') ||
        lowerMsg.contains('withdrawn') ||
        lowerMsg.contains('withdrawal') ||
        lowerMsg.contains('paid') ||
        lowerMsg.contains('transfer') ||
        lowerMsg.contains('transferred')) {
      type = 'expense';

      // Amount extraction for debits / withdrawals
      amount = extractAmount(RegExp(
          r'(?:debited\s+with|withdrawn|debit|paid|transferred)\s+(?:ETB|Birr|USD)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false));

      if (amount <= 0) {
        amount = extractAmount(RegExp(
            r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false));
      }

      if (lowerMsg.contains('withdrawn') || lowerMsg.contains('withdrawal')) {
        recipientOrSender = 'ATM / Cash Withdrawal';
      } else {
        // Look for "to <recipient>"
        final toMatch = RegExp(
                r"to\s+([A-Za-z0-9\s().+'’*:\/\\#-]+?)(?:\s+on\s+\d|\s+at\s+\d|\.\s*|\n|$)",
                caseSensitive: false)
            .firstMatch(message);
        if (toMatch != null) {
          String toTarget = toMatch.group(1)?.trim() ?? '';
          if (!toTarget.toLowerCase().startsWith('your account') &&
              !toTarget.toLowerCase().startsWith('account')) {
            toTarget = toTarget
                .replaceAll(
                    RegExp(r"(?:'s|’s)?\s+(?:tele\s*birr\s+|telebirr\s+)?account(?:\s+number)?(?:\s*[:.\s]*[0-9+*]+)?.*$",
                        caseSensitive: false),
                    '')
                .trim();
            if (toTarget.isNotEmpty) {
              recipientOrSender = toTarget;
            }
          }
        }
        if (recipientOrSender.isEmpty) {
          recipientOrSender = senderName;
        }
      }
    } else if (lowerMsg.contains('credited') ||
        lowerMsg.contains('credit') ||
        lowerMsg.contains('deposited') ||
        lowerMsg.contains('deposit') ||
        lowerMsg.contains('received')) {
      type = 'income';

      // Amount extraction for credits / deposits
      amount = extractAmount(RegExp(
          r'(?:credited\s+with|has\s+deposited|deposited|received)\s+(?:ETB|Birr|USD)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false));

      if (amount <= 0) {
        amount = extractAmount(RegExp(
            r'(?:ETB|Birr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false));
      }

      // Check for Deposit by a named person: "Dear Customer, <NAME> has deposited ETB..."
      final depositedByMatch = RegExp(
              r'Dear\s+Customer,\s*([A-Za-z\s]+?)\s+has\s+deposited',
              caseSensitive: false)
          .firstMatch(message);

      if (depositedByMatch != null) {
        final sender = depositedByMatch.group(1)?.trim();
        if (sender != null && sender.isNotEmpty) {
          recipientOrSender = sender;
        }
      }

      // Check for "from telebirr Sender Name: <NAME>, Phone Number: <PHONE>"
      if (recipientOrSender.isEmpty && lowerMsg.contains('telebirr')) {
        final telebirrNameMatch = RegExp(
                r'from\s+telebirr\s+Sender\s+Name:\s*([A-Za-z\s]+?),',
                caseSensitive: false)
            .firstMatch(message);
        if (telebirrNameMatch != null) {
          final name = telebirrNameMatch.group(1)?.trim();
          if (name != null && name.isNotEmpty) {
            recipientOrSender = '$name (telebirr)';
          }
        } else {
          recipientOrSender = 'Telebirr';
        }
      }

      // Check for "from <NAME> (Bank)" e.g. "from NAHOM ABRAHAM (Ahadu Bank)" or "from other bank"
      if (recipientOrSender.isEmpty) {
        final fromMatch = RegExp(
                r'from\s+([A-Za-z0-9\s().-]+?)(?:\s+on|\s+at|\.|\n)',
                caseSensitive: false)
            .firstMatch(message);
        if (fromMatch != null) {
          final fromTarget = fromMatch.group(1)?.trim();
          if (fromTarget != null &&
              fromTarget.isNotEmpty &&
              !fromTarget.toLowerCase().startsWith('your account')) {
            recipientOrSender = fromTarget;
          }
        }
      }

      if (recipientOrSender.isEmpty) {
        recipientOrSender = senderName;
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // ── 2. Extract Total Current Balance ───────────────────────────────────
    final balMatch = RegExp(
            r'(?:current\s+balance\s+is|account\s+balance\s+is)\s*(?:ETB|Birr)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false)
        .firstMatch(message);
    if (balMatch != null) {
      String balStr = balMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (balStr.endsWith('.')) {
        balStr = balStr.substring(0, balStr.length - 1);
      }
      totalBalance = double.tryParse(balStr) ?? 0.0;
    }

    // ── 3. Extract Date & Time ─────────────────────────────────────────────
    // Format A: "on 2026-08-14 at 08:52:25" or "on 05/03/2026 at 04:44:08 PM"
    final dateTimeMatch = RegExp(
            r'on\s+(\d{1,4}[-/]\d{1,2}[-/]\d{2,4})\s+(?:at\s+)?(\d{1,2}:\d{1,2}(?::\d{1,2})?\s*(?:[AP]M)?)',
            caseSensitive: false)
        .firstMatch(message);

    if (dateTimeMatch != null) {
      final dStr = dateTimeMatch.group(1)!.trim();
      final tStr = dateTimeMatch.group(2)!.trim();
      try {
        final fullStr = '$dStr $tStr';
        final formats = [
          'yyyy-MM-dd HH:mm:ss',
          'yyyy-MM-dd hh:mm:ss a',
          'yyyy-MM-dd HH:mm',
          'yyyy-MM-dd hh:mm a',
          'dd/MM/yyyy hh:mm:ss a',
          'dd/MM/yyyy h:mm:ss a',
          'dd/MM/yyyy hh:mm a',
          'dd/MM/yyyy h:mm a',
          'dd/MM/yyyy HH:mm:ss',
          'dd/MM/yyyy HH:mm',
          'dd-MM-yyyy HH:mm:ss',
          'd/M/yyyy h:mm:ss a',
          'd/M/yyyy HH:mm:ss',
        ];
        for (final fmt in formats) {
          try {
            txDate = DateFormat(fmt, 'en_US').parseLoose(fullStr);
            break;
          } catch (_) {}
        }
      } catch (_) {}
    } else {
      // Format B: "on 2026-08-14" or "on 29/01/2024"
      final dateOnlyMatch = RegExp(
              r'on\s+(\d{1,4}[-/]\d{1,2}[-/]\d{2,4})',
              caseSensitive: false)
          .firstMatch(message);
      if (dateOnlyMatch != null) {
        final dStr = dateOnlyMatch.group(1)!.trim();
        try {
          final formats = ['yyyy-MM-dd', 'dd/MM/yyyy', 'd/M/yyyy', 'dd/MM/yy', 'd/M/yy', 'dd-MM-yyyy'];
          for (final fmt in formats) {
            try {
              final parsed = DateFormat(fmt).parseLoose(dStr);
              txDate = DateTime(
                parsed.year < 100 ? parsed.year + 2000 : parsed.year,
                parsed.month,
                parsed.day,
                fallbackDate.hour,
                fallbackDate.minute,
                fallbackDate.second,
              );
              break;
            } catch (_) {}
          }
        } catch (_) {}
      }
    }

    // ── 4. Generate Unique Transaction ID ──────────────────────────────────
    final normalised = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hash = sha256.convert(utf8.encode('DASHEN BANK|$normalised')).toString();
    final String txId = (referenceNumber != null && referenceNumber.isNotEmpty)
        ? referenceNumber
        : 'DASHEN-${hash.substring(0, 16).toUpperCase()}';

    SmsPatternType patternType = SmsPatternType.standardTransfer;
    if (lowerMsg.contains('airtime') || lowerMsg.contains('air time')) {
      patternType = SmsPatternType.telebirrAirtime;
      recipientOrSender = 'Airtime';
    }

    return ParsedSmsResult(
      id: txId,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: recipientOrSender.isNotEmpty ? recipientOrSender : senderName,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: patternType,
    );
  }
}
