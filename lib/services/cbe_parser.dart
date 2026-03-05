import '../models/transaction.dart';
import 'package:intl/intl.dart';

class CbeParser {
  static const String senderName = "CBE";

  static AppTransaction? parse(String message, DateTime fallbackDate) {
    if (message.isEmpty) return null;

    final lowerMsg = message.toLowerCase();

    String type = '';
    String category = 'Auto';
    double amount = 0.0;
    String senderOrRecipient = '';

    // Extract amount
    double extractAmount(RegExp regex) {
      final match = regex.firstMatch(message);
      if (match != null) {
        String amtStr = match.group(1)?.replaceAll(',', '') ?? '0';
        // Clean up trailing period if the amount is at the end of a sentence
        if (amtStr.endsWith('.')) {
          amtStr = amtStr.substring(0, amtStr.length - 1);
        }
        return double.tryParse(amtStr) ?? 0.0;
      }
      return 0.0;
    }

    if (lowerMsg.contains('transfered')) {
      type = 'expense';
      category = 'Transferred';
      amount = extractAmount(
          RegExp(r'transferr?ed\s+ETB\s+([0-9,.]+)', caseSensitive: false));

      // Extract recipient: "to Miss Bethelihem on"
      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        senderOrRecipient = toMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('debited')) {
      type = 'expense';
      category = 'Withdrawed';
      senderOrRecipient =
          'ATM or Other'; // Default recipient for debited/withdrawal

      // 'has been debited with ETB5.00' OR 'has been debited with ETB 5.00'
      final startStr = 'has been debited with ETB';
      final startIdx = message.toLowerCase().indexOf(startStr.toLowerCase());
      if (startIdx != -1) {
        final valStart = startIdx + startStr.length;
        // Skip optional whitespace between ETB and number
        int numStart = valStart;
        while (numStart < message.length && message[numStart] == ' ') {
          numStart++;
        }
        // End markers: ' including', '.Including', '.', ' '
        int valEnd = -1;
        for (final marker in [' .', '.Including', ' including', ' Including']) {
          final idx = message.indexOf(marker, numStart);
          if (idx != -1 && (valEnd == -1 || idx < valEnd)) {
            valEnd = idx;
          }
        }
        if (valEnd == -1) valEnd = message.indexOf(' ', numStart);
        if (valEnd != -1) {
          String amtStr =
              message.substring(numStart, valEnd).replaceAll(',', '').trim();
          // Remove trailing period if it exists (e.g. "50.00.")
          if (amtStr.endsWith('.')) {
            amtStr = amtStr.substring(0, amtStr.length - 1);
          }
          amount = double.tryParse(amtStr) ?? 0.0;
        }
      }
      // Regex fallback: ETB with optional whitespace before amount
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'debited\s+with\s+ETB\s*([0-9,.]+)', caseSensitive: false));
      }
    } else if (lowerMsg.contains('credited')) {
      type = 'income';
      category = 'Deposit';
      amount = extractAmount(
          RegExp(r'credited\s+with\s+ETB\s+([0-9,.]+)', caseSensitive: false));

      // Extract sender: "from Kaleab Afesha," or "from Kaleab Afesha "
      final fromMatch =
          RegExp(r'from\s+(.*?)(?=\s*,|\s+on|\.\s+)').firstMatch(message);
      if (fromMatch != null) {
        senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

    // Extract Ref No / Transaction ID
    String? id;
    final idStartStr = 'id=';
    final idIdx = message.indexOf(idStartStr);
    if (idIdx != -1) {
      final valStart = idIdx + idStartStr.length;
      int valEnd = message.indexOf(' ', valStart);
      if (valEnd == -1) valEnd = message.length;
      id = message.substring(valStart, valEnd).trim();
    } else {
      final refRegex1 =
          RegExp(r'Ref\s*No\.?\s*([A-Za-z0-9]+)', caseSensitive: false);
      final refMatch1 = refRegex1.firstMatch(message);
      if (refMatch1 != null) {
        id = refMatch1.group(1);
      } else {
        // Fallback to standalone reference like FT...
        final ftRegex = RegExp(r'(FT[0-9A-Z]+)', caseSensitive: true);
        final ftMatch = ftRegex.firstMatch(message);
        if (ftMatch != null) {
          id = ftMatch.group(1);
        }
      }
    }

    // Since ATM withdrawals don't have a transaction ID in the text,
    // we generate a unique fallback ID using the date/message hash.
    id ??=
        'CBE-ATM-${fallbackDate.millisecondsSinceEpoch}-${message.hashCode.abs()}';

    // Extract Balance
    double totalBalance = 0.0;
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final balStartStr = 'Your Current Balance is ETB ';
    final balIdx = singleLineMsg.indexOf(balStartStr);
    if (balIdx != -1) {
      final valStart = balIdx + balStartStr.length;
      final valEnd = singleLineMsg.indexOf(' Thank', valStart);
      if (valEnd != -1) {
        String balStr = singleLineMsg
            .substring(valStart, valEnd)
            .replaceAll(',', '')
            .trim();
        // Remove trailing period if it exists right before 'Thank'
        if (balStr.endsWith('.')) {
          balStr = balStr.substring(0, balStr.length - 1);
        }
        totalBalance = double.tryParse(balStr) ?? 0.0;
      }
    }

    // RegEx fallback for balance
    if (totalBalance <= 0) {
      final balanceMatch =
          RegExp(r'Current Balance is\s+ETB\s+([0-9.,]+)', caseSensitive: false)
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

    // Extract Date
    DateTime txDate = fallbackDate;
    final dateRegex = RegExp(
        r'on\s+(\d{2}/\d{2}/\d{4})\s+at\s+(\d{2}:\d{2}:\d{2})',
        caseSensitive: false);
    final dateMatch = dateRegex.firstMatch(message);
    if (dateMatch != null) {
      try {
        final dateStr = '${dateMatch.group(1)} ${dateMatch.group(2)}';
        final format = DateFormat('dd/MM/yyyy HH:mm:ss');
        txDate = format.parse(dateStr);
      } catch (e) {
        // ignore
      }
    }

    return AppTransaction(
      id: id,
      name: senderName,
      amount: amount,
      type: type,
      date: txDate,
      sender: senderOrRecipient.isNotEmpty ? senderOrRecipient : senderName,
      category: category,
      rawMessage: message,
      isAutoDetected: true,
      totalBalance: totalBalance,
    );
  }
}
