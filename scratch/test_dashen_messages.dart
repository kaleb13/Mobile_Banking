import 'package:mobile_banking_app/services/dashen_parser.dart';

void main() {
  print('=== Testing Dashen Bank Parser with Various Messages ===\n');

  final messages = [
    // 1. Deposit by person
    "Dear Customer, ABREHAHSILASSIEHIRUY has deposited ETB 8,000.00 to your account '5016******005' on 29/01/2024. Your current balance is ETB 368,464.98.\nDashen Bank - Always one step ahead!",
    // 2. Credited from other bank
    "Dear, Nahom Your Account '5017******011' has been credited with ETB 7,000.00 from other bank on 04/02/2026. your current balance is ETB 39,226.94.\nDashen Bank - Always one step ahead!",
    // 3. ATM withdrawal
    "Dear Nahom, you have withdrawn ETB 5,000.00 from ATM on 13/08/2026 at 02:15 PM. Your account balance is ETB 31,119.00.\nDashen Bank",
    // 4. Transfer to someone
    "Dear Customer, ETB 1,500.00 has been debited from your account '5016******005' transfer to KALEB AFESHA on 15/08/2026. Your current balance is ETB 29,619.00.\nDashen Bank",
    // 5. Transfer from telebirr
    "Dear Customer, your account has been credited with ETB 500.00 from telebirr Sender Name: Yonas Gebre, Phone Number: 0911223344 on 16/08/2026. Current balance is ETB 30,119.00.\nDashen Bank",
  ];

  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    final tx = DashenParser.parse(msg, DateTime.now());
    if (tx == null) {
      print('[FAIL] Message #${i + 1} could not be parsed!');
      continue;
    }
    print(
        '[PASS #${i + 1}] Bank: "${tx.name}" | Party: "${tx.sender}" | Type: ${tx.type} | Amt: ${tx.amount} | Bal: ${tx.totalBalance} | Date: ${tx.date}');
  }

  print('\nAll Dashen parser tests passed successfully! 🎉');
}
