import 'bank_senders.dart';
import '../models/transaction.dart';
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

  // ── Standard Transaction Parser ────────────────────────────────────────────

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;
    if (BankSenders.isSecurityOrAuthMessage(message)) return null;

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
    String? reason;

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

    if (lowerMsg.contains('saving account') || lowerMsg.contains('saving balance')) {
      // Telebirr Savings (Sanduq) Deposit or Withdrawal
      category = 'Auto';
      reason = 'Internal Transfer';
      senderOrRecipient = 'Telebirr Saving Account';

      if (lowerMsg.contains('deposit') ||
          lowerMsg.contains('to your saving account') ||
          lowerMsg.contains('to your saving')) {
        type = 'expense';
        amount = extractAmount(RegExp(
            r'(?:deposited|deposit|transferred)\s+ETB\s+([0-9,.]+(?:\.[0-9]+)?)',
            caseSensitive: false));
      } else if (lowerMsg.contains('withdraw') ||
          lowerMsg.contains('from your saving account') ||
          lowerMsg.contains('from your saving')) {
        type = 'income';
        amount = extractAmount(RegExp(
            r'(?:withdrawn|withdraw|transferred)\s+ETB\s+([0-9,.]+(?:\.[0-9]+)?)',
            caseSensitive: false));
      } else {
        type = 'expense';
        amount = extractAmount(RegExp(
            r'(?:ETB\s+)?([0-9,.]+(?:\.[0-9]+)?)\s+(?:to|from)\s+your\s+saving',
            caseSensitive: false));
      }
    } else if (lowerMsg.contains('received')) {
      type = 'income';
      amount = extractAmount(RegExp(r'received\s+ETB\s+([0-9,.]+)'));

      // NEW template: "from Commercial Bank of Ethiopia to your telebirr Account"
      // Note: We search the whole message since the order might vary
      final bankDepositMatch = RegExp(
              r'from\s+(.*?)\s+to your telebirr Account',
              caseSensitive: false)
          .firstMatch(message);

      if (bankDepositMatch != null) {
        senderOrRecipient = bankDepositMatch.group(1)?.trim() ?? '';
      } else {
        // Check for "from" appearing elsewhere if the specific "to your telebirr Account" isn't strictly after it
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

      // Extract to: "to Commercial Bank of Ethiopia account number 1000342078177 on "
      //         or: "to Ahadu Bank SC account number 0087364810101 on "
      //         or: "to Abebe Kebede (251911223344) on "
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

      // Extract at: "at telebirr Agent 248168. Your transaction number"
      final atMatch = RegExp(r'at\s+(.*?)\.\s+Your\s+transaction\s+number',
              caseSensitive: false)
          .firstMatch(message);
      if (atMatch != null) {
        senderOrRecipient = atMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('recharged') && lowerMsg.contains('airtime')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'recharged ETB ([0-9,.]+)'));

      // Extract phone: "for 251972665987 on 04/04/2024" or "for 0935389104 on "
      final phoneMatch = RegExp(
        r'airtime\s+for\s+((?:251|0)?[97]\d{8})',
        caseSensitive: false,
      ).firstMatch(message);
      if (phoneMatch != null) {
        senderOrRecipient = phoneMatch.group(1)?.trim() ?? '';
      }

      reason = 'Airtime';
    } else if (lowerMsg.contains('paid')) {
      type = 'expense';
      amount = extractAmount(RegExp(r'paid ETB ([0-9,.]+)'));

      // Extract for: "for package Monthly Voice plus Data Package: 1.2 GB and 168Min purchase made for 972665987 on "
      //         or: "for package subscription to 972665987 on "
      //         or: "for package Hourly unlimited Internet purchase made for 972665987 on "
      final forMatch =
          RegExp(r'for\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (forMatch != null) {
        final rawDesc = forMatch.group(1)?.trim() ?? '';

        // If it's a package purchase made for a phone number (e.g. "... made for 972665987" or "... to 972665987"):
        // Extract the phone number as the recipient.
        final phoneMatch = RegExp(
          r'(?:made\s+for|to|for)\s+((?:251|0)?[97]\d{8})',
          caseSensitive: false,
        ).firstMatch(rawDesc);

        if (phoneMatch != null) {
          senderOrRecipient = phoneMatch.group(1)?.trim() ?? rawDesc;
        } else {
          senderOrRecipient = rawDesc;
        }

        if (lowerMsg.contains('package')) {
          reason = 'Package';
        }
      }
    } else {
      // Must contain received, transferred, paid, or saving
      return null;
    }

    if (amount <= 0) return null; // Safety check

    // Strip newlines to make tracing and regex matching resilient
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

    // 3. Extract Transaction ID
    // Supports both:
    //   OLD: "transaction number is XXXXX"
    //   NEW: "transaction number XXXXX"  (no "is")
    String? id;
    final idRegex = RegExp(r'transaction number(?:\s+is)?\s+([A-Z0-9]+)',
        caseSensitive: false);
    final idMatch = idRegex.firstMatch(singleLineMsg);
    if (idMatch != null) {
      id = idMatch.group(1);
    } else {
      return null; // A valid Telebirr message must have a transaction ID
    }

    // 4. Extract Current Balance (Main Telebirr / e-money Account)
    double totalBalance = 0.0;

    // Check for explicit "telebirr / e-money Account balance is ETB ..." first (for dual-balance messages)
    final mainAccMatch = RegExp(
            r'(?:telebirr|e-money|e\s+money)\s+(?:account\s+)?balance\s+is\s+ETB\s+([0-9.,]+)',
            caseSensitive: false)
        .firstMatch(singleLineMsg);

    if (mainAccMatch != null) {
      String strippedBalance =
          mainAccMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (strippedBalance.endsWith('.')) {
        strippedBalance =
            strippedBalance.substring(0, strippedBalance.length - 1);
      }
      totalBalance = double.tryParse(strippedBalance) ?? 0.0;
    } else {
      final balanceMatch =
          RegExp(r'balance is\s+ETB\s+([0-9.,]+)', caseSensitive: false)
              .firstMatch(singleLineMsg);
      if (balanceMatch != null) {
        String strippedBalance =
            balanceMatch.group(1)?.replaceAll(',', '') ?? '0';
        if (strippedBalance.endsWith('.')) {
          strippedBalance =
              strippedBalance.substring(0, strippedBalance.length - 1);
        }
        totalBalance = double.tryParse(strippedBalance) ?? 0.0;
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

    return AppTransaction(
      id: id,
      name: senderName,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderOrRecipient.isNotEmpty ? senderOrRecipient : senderNumber,
      category: category,
      reason: reason,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
    );
  }
}
