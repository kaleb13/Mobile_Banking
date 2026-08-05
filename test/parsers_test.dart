import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/cbe_birr_parser.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/ahadu_parser.dart';

void main() {
  final now = DateTime.now();

  group('CbeParser', () {
    test('parses credit transaction', () {
      const sms = "Dear Kaleb your Account 1*********2757 has been Credited with ETB 207.50 from Kaleab Afesha, on 24/04/2026 at 13:44:16 with Ref No FT26114Y5F42 Your Current Balance is ETB 556.87. Thank you for Banking with CBE!";
      final tx = CbeParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(207.50));
      expect(tx.type, equals('income'));
      expect(tx.sender, equals('Kaleab Afesha'));
      expect(tx.totalBalance, equals(556.87));
    });

    test('parses debit/withdrawal transaction', () {
      const sms = "Dear Customer, your Account 1*********2757 has been debited with ETB 100.00 at ATM on 25/04/2026. Ref No FT26115ABC12. Balance ETB 456.87.";
      final tx = CbeParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(100.00));
      expect(tx.type, equals('expense'));
    });

    test('returns null for empty or invalid message', () {
      expect(CbeParser.parse('', now), isNull);
    });
  });

  group('CbeBirrParser', () {
    test('parses credited message', () {
      const sms = "Your CBE Birr account has been credited with 500.00Br. on 24/04/26 14:00, txn id CB123456. Account Balance is 1500.00Br.";
      final tx = CbeBirrParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(500.00));
      expect(tx.type, equals('income'));
      expect(tx.name, equals('CBE Birr'));
    });

    test('ignores voucher/request messages', () {
      const sms = "You have received a request for voucher payment of 100Br.";
      final tx = CbeBirrParser.parse(sms, now);

      expect(tx, isNull);
    });
  });

  group('TelebirrParser', () {
    test('identifies credit disbursement SMS', () {
      const sms = "Your credit request with DGV0EMRXKY contract number is successful. Credit amount 1000 ETB, facilitation fee 20 ETB.";
      expect(TelebirrParser.isCreditDisbursement(sms), isTrue);
    });

    test('identifies credit repayment SMS', () {
      const sms = "your outstanding Credit amount has been paid successfully. Paid amount 500 ETB.";
      expect(TelebirrParser.isCreditRepayment(sms), isTrue);
    });
  });

  group('AhaduParser', () {
    test('parses credit transaction', () {
      const sms = "Dear Customer, your account 1001*** has been Credited with ETB 1,200.00 on 20/04/2026. Current Balance ETB 5,000.00. Ref: AH12345.";
      final tx = AhaduParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(1200.00));
      expect(tx.type, equals('income'));
      expect(tx.name, equals('Ahadu Bank'));
    });

    test('parses debit transaction with receipt link ref and date', () {
      const sms = '''
Dear Customer,
A debit of ETB 670.00 from your account XXXXXXXXX0101 on 05-08-2026 . Your Current balance is ETB 17,332.54  (A transaction fee with 15% VAT is applied).

Ahadu Bank
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/05-AUG-26/5509
For Fayda ID Update
https://verifayda.ahadubank.com/
''';
      final fallback = DateTime(2026, 8, 5, 13, 23, 10);
      final tx = AhaduParser.parse(sms, fallback);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(670.00));
      expect(tx.type, equals('expense'));
      expect(tx.totalBalance, equals(17332.54));
      expect(tx.id, equals('ahadu_ref_1008700007948'));
      expect(tx.date.year, equals(2026));
      expect(tx.date.month, equals(8));
      expect(tx.date.day, equals(5));
      expect(tx.date.hour, equals(13));
      expect(tx.date.minute, equals(23));
    });
  });
}
