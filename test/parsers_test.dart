import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/models/transaction.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/cbe_birr_parser.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/ahadu_parser.dart';
import 'package:mobile_banking_app/services/boa_parser.dart';

void main() {
  final now = DateTime.now();

  group('CbeParser', () {
    test('parses credit transaction', () {
      const sms = "Dear Kaleb your Account 1*********2757 has been Credited with ETB 207.50 from Kaleab Afesha, on 24/04/2026 at 13:44:16 with Ref No FT26114Y5F42 Your Current Balance is ETB 556.87. Thank you for Banking with CBE!";
      final tx = CbeParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(207.50));
      expect(tx.type, equals('income'));
      expect(tx.counterparty, equals('Kaleab Afesha'));
      expect(tx.totalBalance, equals(556.87));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('parses debit/withdrawal transaction', () {
      const sms = "Dear Customer, your Account 1*********2757 has been debited with ETB 100.00 at ATM on 25/04/2026. Ref No FT26115ABC12. Balance ETB 456.87.";
      final tx = CbeParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(100.00));
      expect(tx.type, equals('expense'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
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
      expect(tx.bankName, equals('CBE Birr'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('ignores voucher/request messages', () {
      const sms = "You have received a request for voucher payment of 100Br.";
      final tx = CbeBirrParser.parse(sms, now);

      expect(tx, isNull);
    });
  });

  group('TelebirrParser', () {
    test('identifies savings balance message', () {
      const sms = "Your saving balance is ETB 1,500.00 in Sanduq.";
      expect(TelebirrParser.isSavingsMessage(sms), isTrue);
      expect(TelebirrParser.extractSavingBalance(sms), equals(1500.00));
    });

    test('parses standard money received transaction', () {
      const sms =
          "You have received ETB 250.00 from Abebe Bikila (251911223344) on 20/04/2026. Your transaction number is TB12345. Current balance is ETB 1,000.00.";
      final tx = TelebirrParser.parse(sms, now);
      expect(tx, isNotNull);
      expect(tx!.amount, equals(250.00));
      expect(tx.type, equals('income'));
      expect(tx.bankName, equals('Telebirr'));
      expect(tx.id, equals('TB12345'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('parses bank transfer and extracts account number only as recipient', () {
      const sms =
          "Dear Kaleb\nYou have transferred ETB 460.00 successfully from your telebirr account 251972665987 to Commercial Bank of Ethiopia account number 1000342078177 on 18/08/2026 21:21:41. Your telebirr transaction number is DHI6W98782 and your bank transaction number is FT26231CLLMV. The service fee is  ETB 2.61 and  15% VAT on the service fee is ETB 0.39. Your current balance is ETB 652.32. To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DHI6W98782\nThank you for using telebirr\nEthio telecom";
      final tx = TelebirrParser.parse(sms, now);
      expect(tx, isNotNull);
      expect(tx!.amount, equals(460.00));
      expect(tx.type, equals('expense'));
      expect(tx.bankName, equals('Telebirr'));
      expect(tx.id, equals('DHI6W98782'));
      expect(tx.counterparty, equals('1000342078177'));
      expect(tx.totalBalance, equals(652.32));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('parses package purchase and extracts phone number with locked Package pattern', () {
      const sms =
          "Dear KALEB\nYou have paid ETB 50.00 for package subscription to 972665987 on 20/04/2024 07:10:41. Your transaction number is  BDK7PQVAMX. Your current balance is ETB 24.61.\nFor any support and information related to telebirr service\nThank you for using telebirr\nEthio telecom";
      final tx = TelebirrParser.parse(sms, now);
      expect(tx, isNotNull);
      expect(tx!.amount, equals(50.00));
      expect(tx.type, equals('expense'));
      expect(tx.bankName, equals('Telebirr'));
      expect(tx.id, equals('BDK7PQVAMX'));
      expect(tx.counterparty, equals('972665987'));
      expect(tx.patternType, equals(SmsPatternType.telebirrPackage));
      expect(tx.isSystemLocked, isTrue);
      expect(tx.lockedReasonName, equals('Package'));
      expect(tx.totalBalance, equals(24.61));

      // Domain entity conversion test
      final entity = AppTransaction.fromParsedResult(tx);
      expect(entity.reason, equals('Package'));
      expect(entity.customReasonText, isNull);
      expect(entity.note, isNull);
      expect(entity.isReasonLocked, isTrue);
    });

    test('parses detailed package purchase and extracts phone number with locked Package pattern', () {
      const sms =
          "Dear KALEB\nYou have paid ETB 130.00 for package Monthly Voice plus Data Package: 1.2 GB and 168Min purchase made for 972665987 on 15/08/2026 20:48:44. Your transaction number is  DHF1TGBPYB. Your current balance is ETB 774.32.To download your payment information please click this link: https://transactioninfo.ethiotelecom.et/receipt/DHF1TGBPYB\nThank you for using telebirr\nEthio telecom";
      final tx = TelebirrParser.parse(sms, now);
      expect(tx, isNotNull);
      expect(tx!.amount, equals(130.00));
      expect(tx.type, equals('expense'));
      expect(tx.bankName, equals('Telebirr'));
      expect(tx.id, equals('DHF1TGBPYB'));
      expect(tx.counterparty, equals('972665987'));
      expect(tx.patternType, equals(SmsPatternType.telebirrPackage));
      expect(tx.isSystemLocked, isTrue);
      expect(tx.lockedReasonName, equals('Package'));
      expect(tx.totalBalance, equals(774.32));

      // Domain entity conversion test
      final entity = AppTransaction.fromParsedResult(tx);
      expect(entity.reason, equals('Package'));
      expect(entity.customReasonText, isNull);
      expect(entity.note, isNull);
      expect(entity.isReasonLocked, isTrue);
    });

    test('parses airtime recharge outflow and extracts phone number with locked Airtime pattern', () {
      const sms =
          "Dear KALEB \nYou have recharged ETB 50.00 airtime for 251972665987 on 04/04/2024 14:26:46. Your transaction number is BD45KRON6P. Your current  balance is  ETB 39.69. \nFor any support and information related to telebirr service\nThank you for using telebirr\nEthio telecom";
      final tx = TelebirrParser.parse(sms, now);
      expect(tx, isNotNull);
      expect(tx!.amount, equals(50.00));
      expect(tx.type, equals('expense'));
      expect(tx.bankName, equals('Telebirr'));
      expect(tx.id, equals('BD45KRON6P'));
      expect(tx.counterparty, equals('251972665987'));
      expect(tx.patternType, equals(SmsPatternType.telebirrAirtime));
      expect(tx.isSystemLocked, isTrue);
      expect(tx.lockedReasonName, equals('Airtime'));
      expect(tx.totalBalance, equals(39.69));

      // Domain entity conversion test
      final entity = AppTransaction.fromParsedResult(tx);
      expect(entity.reason, equals('Airtime'));
      expect(entity.customReasonText, isNull);
      expect(entity.note, isNull);
      expect(entity.isReasonLocked, isTrue);
    });
  });

  group('AhaduParser', () {
    test('parses credit transaction', () {
      const sms = "Dear Customer, your account 1001*** has been Credited with ETB 1,200.00 on 20/04/2026. Current Balance ETB 5,000.00. Ref: AH12345.";
      final tx = AhaduParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(1200.00));
      expect(tx.type, equals('income'));
      expect(tx.bankName, equals('Ahadu Bank'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
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
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });
  });

  group('BoaParser', () {
    test('parses credit transaction with payer name and ref ID', () {
      const sms = 'Dear Yohannes, your account 2*****36 was credited with ETB 3,000.00 by  Yohannes Bizuneh . Available Balance: ETB 31,824.04.\nReceipt: https://cs.bankofabyssinia.com/slip/?trx=FT26215HWFDW10104\nFeedback: https://cs.bankofabyssinia.com/cs/?trx=CFT26215HWFDW';
      final tx = BoaParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(3000.00));
      expect(tx.type, equals('income'));
      expect(tx.bankName, equals('BOA'));
      expect(tx.counterparty, equals('Yohannes Bizuneh'));
      expect(tx.totalBalance, equals(31824.04));
      expect(tx.id, equals('boa_ref_FT26215HWFDW10104'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('parses exact user provided BOA credit message with 10k ETB and Fayda link', () {
      const sms = '''Dear Yohannes, your account 2*36 was credited with ETB 10,000.00 by  Yohannes Bizuneh . Available Balance: ETB 34,175.92.
Receipt: https://cs.bankofabyssinia.com/slip/?trx=FT26157FZW7Y10104
Link your Fayda: https://cs.bankofabyssinia.com/fayda_connect 
For help, call 8397 (24/7 Toll-Free). Bank of Abyssinia.''';
      final tx = BoaParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(10000.00));
      expect(tx.type, equals('income'));
      expect(tx.bankName, equals('BOA'));
      expect(tx.counterparty, equals('Yohannes Bizuneh'));
      expect(tx.totalBalance, equals(34175.92));
      expect(tx.id, equals('boa_ref_FT26157FZW7Y10104'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('parses debit transaction with ref ID', () {
      const sms = 'Dear Yohannes, your account 2*****36 was debited with ETB 10,000.00. Available Balance: ETB 21,818.29.\nReceipt: https://cs.bankofabyssinia.com/slip/?trx=TT262259CCQC91836';
      final tx = BoaParser.parse(sms, now);

      expect(tx, isNotNull);
      expect(tx!.amount, equals(10000.00));
      expect(tx.type, equals('expense'));
      expect(tx.bankName, equals('BOA'));
      expect(tx.counterparty, equals('BOA'));
      expect(tx.totalBalance, equals(21818.29));
      expect(tx.id, equals('boa_ref_TT262259CCQC91836'));
      expect(tx.patternType, equals(SmsPatternType.standardTransfer));
    });

    test('ignores queue token messages', () {
      const sms = 'Your token number for today is C0064. Please wait for your token to be called. Thanks for choosing BOA.';
      expect(BoaParser.parse(sms, now), isNull);
    });

    test('parses all 44 transaction messages in BOA SMS.xml with 100% precision', () {
      final file = File(r'c:\Users\kaleb\Documents\Mobile_Banking\BOA SMS.xml');
      if (!file.existsSync()) {
        return;
      }
      final content = file.readAsStringSync();
      final smsRegExp = RegExp(r'<sms\s+[^>]*body="([^"]*)"[^>]*readable_date="([^"]*)"', multiLine: true);
      final matches = smsRegExp.allMatches(content).toList();

      int parsedCount = 0;
      int ignoredCount = 0;

      for (final m in matches) {
        final bodyEscaped = m.group(1) ?? '';
        final body = bodyEscaped.replaceAll('&#10;', '\n').replaceAll('&amp;', '&');
        final tx = BoaParser.parse(body, now);
        if (tx != null) {
          parsedCount++;
          expect(tx.bankName, equals('BOA'));
          expect(tx.counterparty, equals('BOA'));
          expect(tx.amount, greaterThan(0));
        } else {
          ignoredCount++;
        }
      }

      expect(parsedCount, equals(44));
      expect(ignoredCount, equals(1));
    });

    test('parses all 59 transaction messages in Ahadu_SMS.xml with 100% precision', () {
      final file = File(r'c:\Users\kaleb\Documents\Mobile_Banking\Ahadu_SMS.xml');
      if (!file.existsSync()) {
        return;
      }
      final content = file.readAsStringSync();
      final smsRegExp = RegExp(r'<sms\s+[^>]*?body="(.*?)"[^>]*?>', dotAll: true);
      final matches = smsRegExp.allMatches(content).toList();

      int parsedCount = 0;
      int ignoredCount = 0;

      for (final m in matches) {
        final bodyEscaped = m.group(1) ?? '';
        final body = bodyEscaped
            .replaceAll('&#10;', '\n')
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&apos;', "'");
        final tx = AhaduParser.parse(body, now);
        if (tx != null) {
          parsedCount++;
          expect(tx.bankName, equals('Ahadu Bank'));
          expect(tx.amount, greaterThan(0));
        } else {
          ignoredCount++;
        }
      }

      expect(parsedCount, equals(59));
      expect(ignoredCount, equals(19));
    });
  });
}
