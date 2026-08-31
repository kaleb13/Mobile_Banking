import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/boa_parser.dart';
import 'package:mobile_banking_app/services/ahadu_parser.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/cbe_birr_parser.dart';
import 'package:mobile_banking_app/services/dashen_parser.dart';
import 'package:mobile_banking_app/models/transaction.dart';

void main() {
  group('Transaction Deduplication & Engine Parity Tests', () {
    test('BOA and Ahadu parsers return pure reference IDs without arbitrary prefixes', () {
      final now = DateTime.now();

      const boaSms = 'Dear Customer, your account 2*****36 was credited with ETB 1,000.00 by John Doe. Available Balance: ETB 10,000.00.\nReceipt: https://cs.bankofabyssinia.com/slip/?trx=FT998877';
      final boaParsed = BoaParser.parse(boaSms, now);
      expect(boaParsed, isNotNull);
      expect(boaParsed!.id, 'FT998877');

      const ahaduSms = 'Dear Customer, your Account 123 has been debited with ETB 500.00 with reference number w2b998877 on 14-JUL-26. Balance is ETB 4,000.00.';
      final ahaduParsed = AhaduParser.parse(ahaduSms, now);
      expect(ahaduParsed, isNotNull);
      expect(ahaduParsed!.id, 'w2b998877');
    });

    test('All parsers generate identical deterministic uppercase IDs for unreferenced/ATM SMS', () {
      final now = DateTime.now();

      const cbeAtm = 'Dear Customer, your account 1000 was debited with ETB 1,000.00 at ATM. Your current balance is ETB 5,000.00.';
      final cbeParsed1 = CbeParser.parse(cbeAtm, now);
      final cbeParsed2 = CbeParser.parse(cbeAtm, now);
      expect(cbeParsed1, isNotNull);
      expect(cbeParsed2, isNotNull);
      expect(cbeParsed1!.id, cbeParsed2!.id);
      expect(cbeParsed1.id.startsWith('CBE-'), isTrue);

      const tbSms = 'You have successfully bought 100 ETB airtime. Your current balance is ETB 400.00.';
      final tbParsed1 = TelebirrParser.parse(tbSms, now);
      final tbParsed2 = TelebirrParser.parse(tbSms, now);
      expect(tbParsed1, isNotNull);
      expect(tbParsed2, isNotNull);
      expect(tbParsed1!.id, tbParsed2!.id);
      expect(tbParsed1.id.startsWith('TB-'), isTrue);

      const cbeBirrSms = 'You have transferred 50.00 Br. to 0912345678. Your balance is 200.00 Br.';
      final cbeBirr1 = CbeBirrParser.parse(cbeBirrSms, now);
      final cbeBirr2 = CbeBirrParser.parse(cbeBirrSms, now);
      expect(cbeBirr1, isNotNull);
      expect(cbeBirr2, isNotNull);
      expect(cbeBirr1!.id, cbeBirr2!.id);
      expect(cbeBirr1.id.startsWith('CBEBIRR-'), isTrue);

      const dashenSms = 'Your Account 1234 has been debited with ETB 100.00. Current balance is ETB 1000.00.';
      final dashen1 = DashenParser.parse(dashenSms, now);
      final dashen2 = DashenParser.parse(dashenSms, now);
      expect(dashen1, isNotNull);
      expect(dashen2, isNotNull);
      expect(dashen1!.id, dashen2!.id);
      expect(dashen1.id.startsWith('DASHEN-'), isTrue);
    });

    test('AppTransaction.fromParsedResult creates unique primary key with bank ref and simSlot', () {
      final now = DateTime.now();

      const boaSms = 'Dear Customer, your account 2*****36 was credited with ETB 1,000.00 by John Doe. Available Balance: ETB 10,000.00.\nReceipt: https://cs.bankofabyssinia.com/slip/?trx=FT998877';
      final boaParsed = BoaParser.parse(boaSms, now)!;
      final tx = AppTransaction.fromParsedResult(boaParsed, simSlot: 0);

      expect(tx.id, 'FT998877_slot0_income');
      expect(tx.bankReference, 'FT998877');
    });
  });
}
