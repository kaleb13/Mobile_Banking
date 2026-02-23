void main() {
  String msg1 =
      "you have withdrawn 300.00Br. from CBE ATM on 19/02/26 18:08,Txn ID DBJ416E1LLU… Your CBE Birr account balance is 51.64Br.";
  String msg2 =
      "your CBE Birr account has been credited with 300.00Br. on 19/02/26 18:03,Txn ID DBJ616E19PK. Your balance is 352.85Br.";
  String msg3 =
      "you have sent 60.00Br. to nahom abreham on 22/10/25 13:29,Txn ID CJM7WKJP97. Your CBE Birr account balance is 499.12Br.";
  String msg4 =
      "you have received 503.41Br. payment from 232320 - Chapafinancialtechnology s.c on 07/06/25 13:08 ,Txn ID CF71P0LFCD.";
  String msg5 = "as per your request for CBE Birr ATM cash out voucher…";

  void parseMessage(String message) {
    if (message.contains("request") || message.contains("voucher")) {
      print("Ignore Voucher");
      return;
    }

    String type = '';
    String category = '';
    double amount = 0;
    String dateStr = '';
    String txnId = '';
    double balance = 0;
    String participant = 'From your CBE or unknown';

    final lowerMsg = message.toLowerCase();

    if (lowerMsg.contains("withdrawn") && lowerMsg.contains("atm")) {
      category = "Cash";
      type = "expense";
      final amountMatch =
          RegExp(r'withdrawn\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null)
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("credited")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'credited with\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null)
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("received")) {
      category = "Deposit";
      type = "income";
      final amountMatch =
          RegExp(r'received\s+([0-9.,]+)br\.?', caseSensitive: false)
              .firstMatch(message);
      if (amountMatch != null)
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      final senderMatch = RegExp(r'from\s+(.*?)\s+on', caseSensitive: false)
          .firstMatch(message);
      if (senderMatch != null) participant = senderMatch.group(1)!.trim();

      final dateMatch = RegExp(r'on\s+(.*?)\s*,?txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    } else if (lowerMsg.contains("sent") ||
        lowerMsg.contains("paid") ||
        lowerMsg.contains("transferred")) {
      category = "Transfer";
      type = "expense";
      // extract amount before Br.
      final amountMatch = RegExp(r'(?:sent|paid|transferred)\s+([0-9.,]+)br\.?',
              caseSensitive: false)
          .firstMatch(message);
      if (amountMatch != null)
        amount =
            double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0;

      final recipMatch =
          RegExp(r'to\s+(.*?)\s+on', caseSensitive: false).firstMatch(message);
      if (recipMatch != null) {
        String rawRecip = recipMatch.group(1)!.trim();
        rawRecip = rawRecip
            .replaceAll(
                RegExp(r'by Acc\. number\s+[0-9]+', caseSensitive: false), '')
            .trim();
        participant = rawRecip.isNotEmpty ? rawRecip : participant;
      }

      final dateMatch = RegExp(r'on\s+(.*?),txn id', caseSensitive: false)
          .firstMatch(message);
      if (dateMatch != null) dateStr = dateMatch.group(1)!.trim();
    }

    final txnIdMatch = RegExp(r'txn id\s+([A-Z0-9]+)', caseSensitive: false)
        .firstMatch(message);
    if (txnIdMatch != null) txnId = txnIdMatch.group(1)!;

    final balMatch =
        RegExp(r'(?:account\s+)?balance is\s+([0-9.,]+)', caseSensitive: false)
            .firstMatch(message);
    if (balMatch != null)
      balance = double.tryParse(balMatch.group(1)!.replaceAll(',', '')) ?? 0;

    print(
        "Cat: $category, Amt: $amount, Date: $dateStr, Txn: $txnId, Bal: $balance, Part: $participant");
  }

  parseMessage(msg1);
  parseMessage(msg2);
  parseMessage(msg3);
  parseMessage(msg4);
  parseMessage(msg5);
}
