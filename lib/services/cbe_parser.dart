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
        return double.tryParse(match.group(1)?.replaceAll(',', '') ?? '0') ??
            0.0;
      }
      return 0.0;
    }

    if (lowerMsg.contains('transfered')) {
      type =
          'expense'; // Or 'Transfer', but system currently uses 'expense' and 'income' for calculations logic. Let's use 'expense' for UI color handling (red), but we can store it as 'expense' and category 'Transfer'.
      // Wait, user asks for type -> Transfer, Withdrawal, Deposit.
      // Let's stick to 'expense' for debited/transferred and 'income' for credited, but we can set the type exactly as requested if the system supports it.
      // Our UI expects `tx.type == 'income'` or `tx.type == 'expense'` for colors and math. Let's map: Deposit -> income, Transfer/Withdrawal -> expense. We'll use category for the specific detail or adjust the model type.
      type = 'expense';
      category = 'Transfer';
      amount = extractAmount(RegExp(r'transfered\s+ETB\s+([0-9,.]+)'));

      // Extract recipient: "to Miss Bethelihem on"
      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        senderOrRecipient = toMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('debited')) {
      type = 'expense';
      category = 'Withdrawal';
      amount = extractAmount(RegExp(r'debited\s+with\s+ETB\s+([0-9,.]+)'));
    } else if (lowerMsg.contains('credited')) {
      type = 'income';
      category = 'Deposit';
      amount = extractAmount(RegExp(r'Credited\s+with\s+ETB\s+([0-9,.]+)'));

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
      } else {
        // Fallback to URL ID
        final urlRegex = RegExp(r'id=([A-Za-z0-9]+)');
        final urlMatch = urlRegex.firstMatch(message);
        if (urlMatch != null) {
          id = urlMatch.group(1);
        }
      }
    }

    if (id == null) return null; // Needs an ID

    // Extract Balance
    double totalBalance = 0.0;
    String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');
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
