import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/services/cbe_birr_parser.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';

void main() {
  print('=== Testing Notification & Parsing Logic ===\n');

  // Test 1: Security & PIN messages in English and Amharic
  final securityMessages = [
    'Your OTP is 987654. Do not share this code with anyone.',
    'Sorry, your PIN or password is incorrect. Please try again.',
    'የይለፍ ቃልዎ 123456 ነው። ለማንም አያጋሩ።',
    'የማረጋገጫ ኮድ 876543 ነው።',
    'ሚስጥር ቁጥርዎን ያስገቡ።',
    'Wrong PIN entered 3 times. Account locked.',
  ];

  for (final msg in securityMessages) {
    final isSec = BankSenders.isSecurityOrAuthMessage(msg);
    if (!isSec) throw Exception('Security message failed detection: "$msg"');
    print('[PASS] Security Message Ignored: "$msg"');
  }

  // Test 2: Auto-Parsable financial messages
  final parsableSms = [
    'Dear nahom, you bought 170.00Br. of Airtime for 251723185391 on 17/08/26 09:44,Txn ID DHH51LIMBH5 your CBE Birr account balance is 1,450.30Br.',
    'Dear Kaleb\nYou have successfully deposited ETB 4000.00 to your Saving Account on 16/08/2026 19:35:27. Your telebirr transaction number is DHG6U8JEIM. Your current Saving balance is ETB 11043.34 and Your current telebirr Account balance is ETB 646.32.',
    'Dear Kaleb,\nYou have successfully Withdraw ETB 4000.00 from your saving account on 16/08/2026 17:14:05. Your transaction number is\nDHG4U3HNCE. Your current saving balance is ETB 7043.34 and Your current e-money account balance is ETB 4,683.32.',
  ];

  for (final msg in parsableSms) {
    final isParsable = CbeBirrParser.parse(msg, DateTime.now()) != null ||
        TelebirrParser.parse(msg, DateTime.now()) != null;
    if (!isParsable) throw Exception('Parsable message failed parsing: "$msg"');
    print(
        '[PASS] Parsable Financial SMS Identified: "${msg.split('\n').first}"');
  }

  // Test 3: Unparsable financial message (contains financial keywords, not security, but parser returns null)
  const unparsableSms =
      'Dear Customer, your mystery account was credited with 500 dollars on unknown date.';
  final isSec = BankSenders.isSecurityOrAuthMessage(unparsableSms);
  final isParsable =
      TelebirrParser.parse(unparsableSms, DateTime.now()) != null ||
          CbeParser.parse(unparsableSms, DateTime.now()) != null ||
          CbeBirrParser.parse(unparsableSms, DateTime.now()) != null;
  assert(!isSec, 'Should not be security message');
  assert(!isParsable, 'Should not be parsable');
  print(
      '[PASS] Unparsed Financial SMS correctly routed for developer reporting: "$unparsableSms"');

  print('\nAll notification logic verifications passed successfully! 🎉');
}
