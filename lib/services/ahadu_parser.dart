import '../models/parsed_sms_result.dart';
import 'package:intl/intl.dart';

class AhaduParser {
  static const String senderName = "Ahadu Bank";

  /// Attempts to extract the account holder's name from "Dear NAME,".
  static String? extractOwnerName(String message) {
    final match = RegExp(r'Dear\s+([A-Za-z\s]+?),', caseSensitive: false)
        .firstMatch(message);
    if (match != null) {
      final name = match.group(1)?.trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return null;
  }

  static ParsedSmsResult? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

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

    // 1. Determine Transaction Type & Amount
    if (lowerMsg.contains('transfer') ||
        lowerMsg.contains('paid') ||
        lowerMsg.contains('debited') ||
        lowerMsg.contains('debit') ||
        lowerMsg.contains('withdrawn') ||
        lowerMsg.contains('sent') ||
        lowerMsg.contains('cashout') ||
        lowerMsg.contains('purchase')) {
      type = 'expense';

      amount = extractAmount(RegExp(
          r'(?:transfer\s+of|debited\s+with|debit\s+of|debit|paid|withdrawn|sent)\s+ETB\s*([0-9,.]+)',
          caseSensitive: false));
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'ETB\s+(?:ETB\s+)?([0-9,.]+)', caseSensitive: false));
      }
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'ETB\s*([0-9,.]+)', caseSensitive: false));
      }

      final toMatchRef = RegExp(
              r'to\s+(.*?)\s+(?:with\s+reference|with\s+ref|on\s+\d{1,2}-|\.)',
              caseSensitive: false)
          .firstMatch(message);
      if (toMatchRef != null) {
        recipientOrSender = toMatchRef.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('received') ||
        lowerMsg.contains('credited') ||
        lowerMsg.contains('credit') ||
        lowerMsg.contains('deposited') ||
        lowerMsg.contains('deposit') ||
        lowerMsg.contains('cashin')) {
      type = 'income';

      amount = extractAmount(RegExp(
          r'(?:deposit\s+of|received|credited\s+with|credit|deposited)\s+ETB\s*([0-9,.]+)',
          caseSensitive: false));
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'ETB\s+(?:ETB\s+)?([0-9,.]+)', caseSensitive: false));
      }
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'ETB\s*([0-9,.]+)', caseSensitive: false));
      }

      final fromMatch = RegExp(
              r'from\s+(.*?)\s+(?:with\s+reference|with\s+ref|on\s+\d{1,2}-|\.)',
              caseSensitive: false)
          .firstMatch(message);
      if (fromMatch != null) {
        recipientOrSender = fromMatch.group(1)?.trim() ?? '';
      }
    } else {
      if (lowerMsg.contains('etb')) {
        amount = extractAmount(
            RegExp(r'ETB\s+(?:ETB\s+)?([0-9,.]+)', caseSensitive: false));
        if (amount <= 0) {
          amount = extractAmount(
              RegExp(r'ETB\s*([0-9,.]+)', caseSensitive: false));
        }
        type = 'expense';
      }
    }

    if (amount <= 0) return null;

    // 2. Extract Available Balance: "Your Available Balance is ETB 4,937.35."
    totalBalance = extractAmount(RegExp(
        r'(?:Available\s+Balance|Balance)\s+(?:is\s+)?ETB\s*([0-9,.]+)',
        caseSensitive: false));

    // 3. Extract Date — three supported formats:
    //   a) "on 14-JUL-26"  → DD-MMM-YY  (transfer messages)
    //   b) "on 14-JUL-2026" → DD-MMM-YYYY
    //   c) "on 02-07-2026" → DD-MM-YYYY  (deposit messages — all numeric)
    //   d) "on 14/07/2026" → DD/MM/YYYY
    final dateMatch = RegExp(
            r'on\s+(\d{1,2}-[A-Za-z]{3}-\d{2,4}|\d{1,2}-\d{2}-\d{4}|\d{1,2}/\d{1,2}/\d{2,4})',
            caseSensitive: false)
        .firstMatch(message);
    if (dateMatch != null) {
      final dateStr = dateMatch.group(1)!;
      txDate = _parseAhaduDate(dateStr, fallbackDate);
    }

    // 4. Extract Reference/Transaction ID — used as the deduplication key.
    // Ahadu format: "with reference number w2b17840409529101436"
    // Fallback: digital receipt URL parameter "digitalreceipt?es=1008700007948/05-AUG-26/5509"
    String? refId;
    final refMatch = RegExp(
            r'(?:reference\s+number|ref(?:erence)?\s*(?:no\.?)?|ref\.?)\s*:?\s*([A-Za-z0-9]+)',
            caseSensitive: false)
        .firstMatch(message);
    if (refMatch != null) {
      refId = refMatch.group(1)?.trim();
    } else {
      final urlRefMatch = RegExp(
              r'digitalreceipt\?es=([A-Za-z0-9/\-_]+)', caseSensitive: false)
          .firstMatch(message);
      if (urlRefMatch != null) {
        refId = urlRefMatch.group(1)?.trim();
      }
    }

    // Build unique transaction ID: prefer reference number, fall back to
    // type+amount+date (e.g. for deposit messages that have no ref number).
    final txId = refId != null
        ? 'ahadu_ref_$refId'
        : 'ahadu_${type}_${txDate.year}${txDate.month.toString().padLeft(2,'0')}${txDate.day.toString().padLeft(2,'0')}_${amount.toStringAsFixed(2)}';

    // Clean up recipient/sender label
    if (recipientOrSender.isEmpty) {
      recipientOrSender = type == 'income' ? 'Ahadu Deposit' : 'Ahadu Transfer';
    }

    return ParsedSmsResult(
      id: txId,
      bankName: senderName,
      amount: amount,
      type: type,
      date: txDate,
      counterparty: recipientOrSender,
      totalBalance: totalBalance,
      rawMessage: message,
      patternType: SmsPatternType.standardTransfer,
    );
  }

  static DateTime _parseAhaduDate(String dateStr, DateTime fallback) {
    try {
      DateTime parsed;
      if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final rawMonth = parts[1].trim();
          var year = parts[2].trim();
          if (year.length == 2) year = '20$year';

          // Detect numeric month (e.g. 05-08-2026 → DD-MM-YYYY)
          final monthAsInt = int.tryParse(rawMonth);
          if (monthAsInt != null) {
            parsed = DateFormat('dd-MM-yyyy')
                .parse('$day-${rawMonth.padLeft(2,'0')}-$year');
          } else {
            // Month is a word abbreviation: DD-MMM-YY(YY)
            final month = rawMonth[0].toUpperCase() +
                rawMonth.substring(1).toLowerCase();
            parsed = DateFormat('dd-MMM-yyyy').parse('$day-$month-$year');
          }
          return DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            fallback.hour,
            fallback.minute,
            fallback.second,
          );
        }
      } else if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          var year = parts[2];
          if (year.length == 2) year = '20$year';
          parsed = DateFormat('dd/MM/yyyy').parse('$day/$month/$year');
          return DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            fallback.hour,
            fallback.minute,
            fallback.second,
          );
        }
      }
    } catch (_) {}
    return fallback;
  }
}
