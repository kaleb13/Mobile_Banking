import 'dart:io';
import '../lib/services/telebirr_parser.dart';

void main() {
  final message = '''Dear Kaleb
You have successfully deposited ETB 4000.00 to your Saving Account on 16/08/2026 19:35:27. Your telebirr transaction number is DHG6U8JEIM. Your current Saving balance is ETB 11043.34 and Your current telebirr Account balance is ETB 646.32.
Thank you for using telebirr
Ethio telecom''';

  final tx = TelebirrParser.parse(message, DateTime.now());
  final savingBal = TelebirrParser.extractSavingBalance(message);

  print('=== Parsed Telebirr Savings Transaction ===');
  print('tx != null: ${tx != null}');
  if (tx != null) {
    print('ID: ${tx.id}');
    print('Type: ${tx.type}');
    print('Amount: ${tx.amount} ETB');
    print('Sender/Recipient: ${tx.sender}');
    print('Category: ${tx.category}');
    print('Reason: ${tx.reason}');
    print('CustomReasonText: ${tx.customReasonText}');
    print('Main Account Balance: ${tx.totalBalance} ETB');
    print('Extracted Saving Balance: $savingBal ETB');
    print('Date: ${tx.date}');
    print('isReasonLocked: ${tx.isReasonLocked}');
  }
}
