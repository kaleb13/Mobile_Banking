import 'package:mobile_banking_app/services/telebirr_parser.dart';

void main() {
  final message = '''Dear Kaleb,
You have successfully Withdraw ETB 4000.00 from your saving account on 16/08/2026 17:14:05. Your transaction number is
DHG4U3HNCE. Your current saving balance is ETB 7043.34 and Your current e-money account balance is ETB 4,683.32.
Thank you for using telebirr
Ethio telecom''';

  final tx = TelebirrParser.parse(message, DateTime.now());
  final savingBal = TelebirrParser.extractSavingBalance(message);

  print('=== Parsed Telebirr Savings Withdrawal ===');
  print('tx != null: ${tx != null}');
  if (tx != null) {
    print('ID: ${tx.id}');
    print('Type: ${tx.type}');
    print('Amount: ${tx.amount} ETB');
    print('Sender/Recipient: ${tx.sender}');
    print('Reason: ${tx.reason}');
    print('Main Account Balance: ${tx.totalBalance} ETB');
    print('Saving Balance: $savingBal ETB');
    print('Date: ${tx.date}');
    print('isReasonLocked: ${tx.isReasonLocked}');
  }
}
