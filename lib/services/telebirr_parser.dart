import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'bank_senders.dart';
import '../models/parsed_sms_result.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TelebirrParser
// ─────────────────────────────────────────────────────────────────────────────
class TelebirrParser {
  static const String senderNumber = "127";
  static const String senderName = "Telebirr";

  // ── Quick checks ──────────────────────────────────────────────────────────

  /// Returns true if [message] looks like a Telebirr Savings (Sanduq) SMS.
  static bool isSavingsMessage(String message) {
    if (BankSenders.isSecurityOrAuthMessage(message)) return false;
    final lower = message.toLowerCase();
    return lower.contains('saving account') || lower.contains('saving balance');
  }

  /// Extracts the Saving Account balance from a Telebirr Savings SMS if present.
  static double? extractSavingBalance(String message) {
    final singleLine = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final match = RegExp(
            r'saving\s+balance\s+is\s+ETB\s+([0-9.,]+)',
            caseSensitive: false)
        .firstMatch(singleLine);
    if (match != null) {
      String amtStr = match.group(1)?.replaceAll(',', '').trim() ?? '';
      if (amtStr.endsWith('.')) amtStr = amtStr.substring(0, amtStr.length - 1);
      return double.tryParse(amtStr);
    }
    return null;
  }

  /// Cleans counterparty string by stripping phone numbers in parentheses,
  /// masked phones like "(2519****9104)", and trailing terminal/reference codes like "101813".
  static String cleanCounterparty(String raw) {
    var cleaned = raw.trim();
    // Strip parenthesized phone numbers / identifiers e.g. "(2519****9104) 101813" or "(251912345678)"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(.*'), '').trim();
    // Strip trailing reference numbers / digits if any remain e.g. " 101813"
    cleaned = cleaned.replaceAll(RegExp(r'\s+\d{4,}\b.*'), '').trim();
    return cleaned.isEmpty ? raw.trim() : cleaned;
  }

  // ── Standard Transaction Parser ────────────────────────────────────────────

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;
    if (BankSenders.isSecurityOrAuthMessage(message)) return null;

    final lowerMsg = message.toLowerCase();

    // 1. Airtime Check: Ignore airtime received messages completely
    if (RegExp(r'received etb [0-9.]+\s*airtime').hasMatch(lowerMsg)) {
      return null;
    }

    // 2. Identify Type, Pattern & Amount
    String type = '';
    double amount = 0.0;
    String senderOrRecipient = '';
    SmsPatternType patternType = SmsPatternType.standardTransfer;

    // A helper to extract amount safely
    double extractAmount(RegExp regex) {
      final match = regex.firstMatch(message);
      if (match != null) {
        String amtStr = match.group(1)?.replaceAll(',', '') ?? '0';
        if (amtStr.endsWith('.')) amtStr = amtStr.substring(0, amtStr.length - 1);
        return double.tryParse(amtStr) ?? 0.0;
      }
      return 0.0;
    }

    if (lowerMsg.contains('airtime') ||
        ((lowerMsg.contains('recharged') || lowerMsg.contains('bought')) &&
            lowerMsg.contains('airtime'))) {
      patternType = SmsPatternType.telebirrAirtime;
      if (lowerMsg.contains('received')) {
        type = 'income';
        amount = extractAmount(
            RegExp(r'(?:received|recharged)\s+ETB\s+([0-9,.]+)'));
        if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));
        final fromMatch =
            RegExp(r'from\s+((?:251|0)?[97]\d{8}|\S+)').firstMatch(message);
        senderOrRecipient = fromMatch?.group(1)?.trim() ?? 'Airtime';
      } else {
        type = 'expense';
        amount = extractAmount(
            RegExp(r'(?:recharged|bought)\s+ETB\s+([0-9,.]+)'));
        if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));
        final phoneMatch = RegExp(
          r'airtime\s+for\s+((?:251|0)?[97]\d{8})',
          caseSensitive: false,
        ).firstMatch(message);
        senderOrRecipient = phoneMatch?.group(1)?.trim() ?? 'Airtime';
      }
    } else if (lowerMsg.contains('package') &&
        (lowerMsg.contains('paid') ||
            lowerMsg.contains('bought') ||
            lowerMsg.contains('package subscription') ||
            lowerMsg.contains('monthly voice'))) {
      type = 'expense';
      patternType = SmsPatternType.telebirrPackage;
      amount = extractAmount(RegExp(r'(?:paid|bought)\s+ETB\s+([0-9,.]+)'));
      if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));

      final phoneMatch = RegExp(
        r'(?:made\s+for|to|for)\s+((?:251|0)?[97]\d{8})',
        caseSensitive: false,
      ).firstMatch(message);
      senderOrRecipient = phoneMatch?.group(1)?.trim() ?? 'Package';
    } else if (lowerMsg.contains('saving account') ||
        lowerMsg.contains('saving balance') ||
        lowerMsg.contains('sanduq') ||
        lowerMsg.contains('shamo') ||
        (lowerMsg.contains('reserved') && lowerMsg.contains('account'))) {
      // Telebirr Savings (Sanduq / Shamo) Deposit or Withdrawal
      patternType = SmsPatternType.telebirrSanduq;
      senderOrRecipient =
          lowerMsg.contains('shamo') ? 'Shamo Account' : 'Sanduq Savings';

      if (lowerMsg.contains('deposit') ||
          lowerMsg.contains('to your saving account') ||
          lowerMsg.contains('to your saving') ||
          lowerMsg.contains('reserved')) {
        type = 'expense';
        amount = extractAmount(RegExp(
            r'(?:deposited|deposit|transferred|reserved)\s+ETB\s+([0-9,.]+(?:\.[0-9]+)?)',
            caseSensitive: false));
        if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));
      } else if (lowerMsg.contains('withdraw') ||
          lowerMsg.contains('from your saving account') ||
          lowerMsg.contains('from your saving')) {
        type = 'income';
        amount = extractAmount(RegExp(
            r'(?:withdrawn|withdraw|transferred)\s+ETB\s+([0-9,.]+(?:\.[0-9]+)?)',
            caseSensitive: false));
        if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));
      } else {
        type = 'expense';
        amount = extractAmount(RegExp(
            r'(?:ETB\s+)?([0-9,.]+(?:\.[0-9]+)?)\s+(?:to|from)\s+your\s+saving',
            caseSensitive: false));
        if (amount <= 0) amount = extractAmount(RegExp(r'ETB\s+([0-9,.]+)'));
      }
    } else if (lowerMsg.contains('received')) {
      type = 'income';
      amount = extractAmount(RegExp(r'received\s+ETB\s+([0-9,.]+)'));

      // NEW template: "from Commercial Bank of Ethiopia to your telebirr Account"
      final bankDepositMatch = RegExp(
              r'from\s+(.*?)\s+to your telebirr Account',
              caseSensitive: false)
          .firstMatch(message);

      if (bankDepositMatch != null) {
        senderOrRecipient = bankDepositMatch.group(1)?.trim() ?? '';
      } else {
        final fromMatch =
            RegExp(r'from\s+(.*?)(?=\s*\(|on\s+\d{2}/\d{2}|to\s+your|$)')
                .firstMatch(message);
        if (fromMatch != null) {
          senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
        }
      }
    } else if (lowerMsg.contains('transferred')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'transferred ETB ([0-9,.]+)'));

      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        final rawRecipient = toMatch.group(1)?.trim() ?? '';
        final accMatch = RegExp(
          r'account\s+(?:number\s+)?([0-9A-Za-z]+)',
          caseSensitive: false,
        ).firstMatch(rawRecipient);

        if (accMatch != null) {
          senderOrRecipient = accMatch.group(1)?.trim() ?? rawRecipient;
        } else {
          senderOrRecipient = rawRecipient;
        }
      }
    } else if (lowerMsg.contains('debited')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'debited\s+with\s+ETB\s+([0-9,.]+)'));

      final atMatch = RegExp(r'at\s+(.*?)\.\s+Your\s+transaction\s+number',
              caseSensitive: false)
          .firstMatch(message);
      if (atMatch != null) {
        senderOrRecipient = atMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('paid')) {
      type = 'expense';
      amount = extractAmount(
          RegExp(r'paid\s+ETB\s+([0-9,.]+)', caseSensitive: false));

      var forMatch = RegExp(
              r'(?:to|for)\s+(.*?)\s+(?:on\s+\d{2}/\d{2}|for\s+)',
              caseSensitive: false)
          .firstMatch(message);
      forMatch ??= RegExp(
              r'(?:to|for)\s+(.*?)\s+on\s+\d{2}/\d{2}',
              caseSensitive: false)
          .firstMatch(message);
      if (forMatch != null) {
        final rawDesc = forMatch.group(1)?.trim() ?? '';

        final phoneMatch = RegExp(
          r'(?:made\s+for|to|for)\s+((?:251|0)?[97]\d{8})',
          caseSensitive: false,
        ).firstMatch(rawDesc);

        if (phoneMatch != null) {
          senderOrRecipient = phoneMatch.group(1)?.trim() ?? rawDesc;
        } else {
          senderOrRecipient = rawDesc;
        }
      }
    } else if (lowerMsg.contains('credited with etb') ||
        lowerMsg.contains('credited with')) {
      type = 'income';
      amount = extractAmount(RegExp(r'credited\s+with\s+ETB\s+([0-9,.]+)'));

      final agentMatch = RegExp(
              r'via\s+(?:telebirr\s+agent|agent)\s+([0-9A-Za-z]+)',
              caseSensitive: false)
          .firstMatch(message);
      if (agentMatch != null) {
        senderOrRecipient = 'telebirr agent ${agentMatch.group(1)}';
      } else {
        senderOrRecipient = 'Telebirr Deposit';
      }
    } else if (lowerMsg.contains('deposited') && lowerMsg.contains('to')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'deposited\s+ETB\s+([0-9,.]+)'));
      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        String rawRecip = toMatch.group(1)?.trim() ?? '';
        final dashSplit = rawRecip.split(' - ');
        if (dashSplit.length >= 2 &&
            RegExp(r'^\d+$').hasMatch(dashSplit.first.trim())) {
          senderOrRecipient = dashSplit.sublist(1).join(' - ').trim();
        } else {
          senderOrRecipient = rawRecip;
        }
      }
    } else {
      // Must contain airtime, package, received, transferred, debited, paid, credited, deposited, or saving
      return null;
    }

    if (amount <= 0) return null; // Safety check

    // Strip newlines to make tracing and regex matching resilient
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

    // 3. Extract Transaction ID
    // Supports both:
    //   OLD: "transaction number is XXXXX"
    //   NEW: "transaction number XXXXX"  (no "is")
    //   DEPOSIT: "transaction number XXXXX on"
    final idRegex = RegExp(
        r'transaction\s+number\s+(?:is\s+)?([A-Za-z0-9]+)',
        caseSensitive: false);
    final idMatch = idRegex.firstMatch(singleLineMsg);
    String? id = idMatch?.group(1)?.trim();
    if (id == null || id.isEmpty) {
      final normalised = message.replaceAll(RegExp(r'\s+'), ' ').trim();
      final hash = sha256.convert(utf8.encode('TELEBIRR|$normalised')).toString();
      id = 'TB-${hash.substring(0, 16).toUpperCase()}';
    }

    // 4. Extract Post Balance (Telebirr Checking / E-Money account balance)
    // Supports:
    //   - "Your current balance is ETB 123.45"
    //   - "Your current  balance is  ETB 123.45"
    //   - "Your current balance is ETB 123.45."
    //   - "Your current telebirr Account balance is ETB 1800.00"
    //   - "Your current telebirr E-Money Account balance is ETB 123.45."
    //   - "Your current e-money account balance is ETB 4,683.32."
    // Note: NEVER match "saving balance is ETB ..." for the checking account balance.
    double totalBalance = 0.0;
    final allBalanceMatches = RegExp(
        r'(?:(saving\s+)?balance\s+is\s+ETB\s*)([0-9,]+(?:\.[0-9]+)?)',
        caseSensitive: false).allMatches(singleLineMsg);

    for (final m in allBalanceMatches) {
      final isSaving = m.group(1) != null && m.group(1)!.trim().isNotEmpty;
      if (!isSaving) {
        String raw = m.group(2)?.replaceAll(',', '') ?? '0';
        if (raw.endsWith('.')) raw = raw.substring(0, raw.length - 1);
        final parsedVal = double.tryParse(raw) ?? 0.0;
        if (parsedVal > 0) {
          totalBalance = parsedVal;
          break;
        }
      }
    }

    // 5. Extract Date
    // Supports:
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

    return ParsedSmsResult(
      id: id,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: senderOrRecipient.isNotEmpty ? cleanCounterparty(senderOrRecipient) : senderNumber,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: patternType,
    );
  }
}
