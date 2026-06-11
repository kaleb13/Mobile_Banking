import 'package:intl/intl.dart';

class AppTransaction {
  String? id;
  String? name;
  double amount;
  String type;
  DateTime date;
  String sender;
  String category;
  String rawMessage;
  bool isAutoDetected;
  double totalBalance;

  AppTransaction({
    this.id,
    this.name,
    required this.amount,
    required this.type,
    required this.date,
    required this.sender,
    required this.category,
    required this.rawMessage,
    required this.isAutoDetected,
    required this.totalBalance,
  });

  @override
  String toString() {
    return 'AppTransaction(id: $id, amount: $amount, type: $type, date: $date, sender: $sender, category: $category, totalBalance: $totalBalance)';
  }
}

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

      final toMatch =
          RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
      if (toMatch != null) {
        senderOrRecipient = toMatch.group(1)?.trim() ?? '';
      }
    } else if (lowerMsg.contains('debited')) {
      type = 'expense';
      category = 'Withdrawed';
      senderOrRecipient = 'ATM or Other';

      final startStr = 'has been debited with ETB';
      final startIdx = message.toLowerCase().indexOf(startStr.toLowerCase());
      if (startIdx != -1) {
        final valStart = startIdx + startStr.length;
        int numStart = valStart;
        while (numStart < message.length && message[numStart] == ' ') {
          numStart++;
        }
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
          if (amtStr.endsWith('.')) {
            amtStr = amtStr.substring(0, amtStr.length - 1);
          }
          amount = double.tryParse(amtStr) ?? 0.0;
        }
      }
      if (amount <= 0) {
        amount = extractAmount(
            RegExp(r'debited\s+with\s+ETB\s*([0-9,.]+)', caseSensitive: false));
      }
    } else if (lowerMsg.contains('credited')) {
      type = 'income';
      category = 'Deposit';
      amount = extractAmount(
          RegExp(r'credited\s+with\s+ETB\s+([0-9,.]+)', caseSensitive: false));

      final fromMatch =
          RegExp(r'from\s+(.*?)(?=\s*,|\s+on|\.\s+)').firstMatch(message);
      if (fromMatch != null) {
        senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
      }
    } else {
      return null;
    }

    if (amount <= 0) return null;

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
        final ftRegex = RegExp(r'(FT[0-9A-Z]+)', caseSensitive: true);
        final ftMatch = ftRegex.firstMatch(message);
        if (ftMatch != null) {
          id = ftMatch.group(1);
        }
      }
    }

    id ??=
        'CBE-ATM-${fallbackDate.millisecondsSinceEpoch}-${message.hashCode.abs()}';

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
        if (balStr.endsWith('.')) {
          balStr = balStr.substring(0, balStr.length - 1);
        }
        totalBalance = double.tryParse(balStr) ?? 0.0;
      }
    }

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

void main() {
  final msg = "Dear Kaleb, You have transfered ETB 130.00 to Mr Tesfa on 17/04/2026 at 19:06:35 from your account 1*********2757. Your account has been debited with a S.charge of ETB 0.50 and VAT(15%) of ETB0.08 and Disaster Fund (5%) of ETB0.03, with a total of ETB 130.61. Your Current Balance is ETB 195.98. Thank you for Banking with CBE! https://apps.cbe.com.et:100/?id=FT2610791XDK17182757 For feedback click the link https://forms.gle/R1s9nkJ6qZVCxRVu9";
  final result = CbeParser.parse(msg, DateTime.now());
  if (result != null) {
    print("YES");
    print("ID: ${result.id}");
    print("Amount: ${result.amount}");
    print("Recipient: ${result.sender}");
    print("Balance: ${result.totalBalance}");
    print("Date: ${result.date}");
  } else {
    print("NO");
  }
}
