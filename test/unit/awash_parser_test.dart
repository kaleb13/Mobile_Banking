import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/awash_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:xml/xml.dart';

void main() {
  group('AwashParser Unit Tests', () {
    final testDate = DateTime(2026, 3, 21, 10, 0, 0);

    test('Pattern 1: Inbound Credit via IPS / TeleBirr C2B', () {
      const msg1 =
          'Dear Customer, your Account 01320xxxxxx7700 has been Credited with ETB 600.00 on 2026-03-21 07:17:06 by BISRAT TESFAYE ADEM via IPS Bank of Abyssinia. Your balance now is ETB 650.00. For any complaint or enquiry, please call 8980. Thank You. Awash Bank.';
      final result1 = AwashParser.parse(msg1, testDate);
      expect(result1, isNotNull);
      expect(result1!.bankName, 'Awash Bank');
      expect(result1.type, 'income');
      expect(result1.amount, 600.00);
      expect(result1.counterparty, 'BISRAT TESFAYE ADEM');
      expect(result1.totalBalance, 650.00);
      expect(result1.date, DateTime(2026, 3, 21, 7, 17, 6));

      const msg2 =
          'Dear Customer, your Account 01320xxxxxx7700 has been Credited with ETB 4500.00 on 2026-06-12 19:37:08 by TeleBirr C2B to Awash with reference DFC2TV0K20. Your balance now is ETB 4555.36. For any complaint or enquiry, please call 8980. Thank You. Awash Bank.';
      final result2 = AwashParser.parse(msg2, testDate);
      expect(result2, isNotNull);
      expect(result2!.type, 'income');
      expect(result2.amount, 4500.00);
      expect(result2.counterparty, 'TeleBirr C2B to Awash');
      expect(result2.id, 'DFC2TV0K20');
      expect(result2.totalBalance, 4555.36);
    });

    test('Pattern 2: Inbound Direct / P2P Credit', () {
      const msg =
          'Dear Customer, ETB 2,425 has been credited to your account from Alpha Dawit on : 2026-03-28 10:38:47  with Txn ID: 260328103874225 . Your available balance is now ETB 2,510.12. Receipt  Link: https://awashpay.awashbank.com:8225/-2KA12VKO8H-43V46E. Contact center  8980.\n\nAlert: Awash Bank will never ask for your PIN, password, or OTP. Do not share your confidential information with anyone.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'income');
      expect(result.amount, 2425.00);
      expect(result.counterparty, 'Alpha Dawit');
      expect(result.id, '260328103874225');
      expect(result.totalBalance, 2510.12);
      expect(result.date, DateTime(2026, 3, 28, 10, 38, 47));
    });

    test('Pattern 3: Outbound P2P Transfer', () {
      const msg =
          'Dear Customer, You have sent ETB 1,600 To (01335625418100) - BEREKET LIBIYOS BERGENE by Transaction ID: 260615193827946 charge- 2.00 VAT- 0.30 Date 2026-06-15 19:38:24 . Your Available Balance is 4,136.96. Download the receipt by link https://awashpay.awashbank.com:8225/-2KDOYTIQ96-4XHM84.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 1600.00);
      expect(result.counterparty, 'BEREKET LIBIYOS BERGENE');
      expect(result.id, '260615193827946');
      expect(result.totalBalance, 4136.96);
      expect(result.date, DateTime(2026, 6, 15, 19, 38, 24));
    });

    test('Pattern 4: Outbound Other Bank Transfer', () {
      const msg =
          'Dear Customer , You have transferred to other bank ETB  400  To 1000711508736 (MRS EYERUS MENGESHA MOLLA) In Commercial Bank of Ethiopia VAT: 0.36. Your available Balance is  ETB 191.12. Receipt Link: https://awashpay.awashbank.com:8225/-2K9ZQJ149U-42W10H. Contact Center  8980.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 400.00);
      expect(result.counterparty, 'MRS EYERUS MENGESHA MOLLA');
      expect(result.id, '-2K9ZQJ149U-42W10H');
      expect(result.totalBalance, 191.12);
    });

    test('Pattern 5: Outbound Telebirr Transfer', () {
      const msg =
          'Dear Customer; Telebirr Transfer of 50.00 ETB to Bisrat Tesfaye Adem  - 251984163455 from 013201620127700/BANK,  Reason- Airtime , Charge 5.00 VAT: 0.75 . Your Balance is  ETB 594.00 . Receipt Link: https://awashpay.awashbank.com:8225/-2K9YTOKSIN-423RSV. Contact Center 8980.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 50.00);
      expect(result.counterparty, 'Bisrat Tesfaye Adem');
      expect(result.id, '-2K9YTOKSIN-423RSV');
      expect(result.totalBalance, 594.00);
    });

    test('Pattern 6: Outbound MPESA Transfer', () {
      const msg =
          'Dear Customer,  MPESA transfer of  50.00 ETB for 0705043455 ,Bisrat Tesfaye Adam Ref 260721215098790 Date 2026-07-21 09:50:54 PM. VAT: 0.75  Your Balance is ETB 6,121.64.  Receipt Link: https://awashpay.awashbank.com:8225/-2KF1O7UIEE-5B948B. Contact Center 8980.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 50.00);
      expect(result.counterparty, 'Bisrat Tesfaye Adam');
      expect(result.id, '260721215098790');
      expect(result.totalBalance, 6121.64);
      expect(result.date, DateTime(2026, 7, 21, 21, 50, 54));
    });

    test('Pattern 7: Outbound Airtime Purchase', () {
      const msg =
          'Dear customer, You have bought airtime worth ETB 16.00 for 0705043455. Your Balance  is ETB 5,739.36. Receipt Link: https://awashpay.awashbank.com:8225/-2KDOX63EN7-4X6YHM. \nHelp us do better – Please take our mini survey: https://shorturl.at/WISQB  Thank You. Awash Bank!';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 16.00);
      expect(result.patternType, SmsPatternType.telebirrAirtime);
      expect(result.counterparty, 'Airtime (0705043455)');
      expect(result.id, '-2KDOX63EN7-4X6YHM');
      expect(result.totalBalance, 5739.36);
    });

    test('Pattern 8: Outbound Telebirr Agent Transfer', () {
      const msg =
          'Dear Customer, Telebirr Agent Transfer of 300.00   to  Ac : 01138******300/BANK at agent: Samuel Sankura SamagoAgent Code: 428360 Transaction Id: 260822194176925.Receipt from Link: https://awashpay.awashbank.com:8225/-2KGC286LR1-5N6TG1. Contact Center 8980.';
      final result = AwashParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Awash Bank');
      expect(result.type, 'expense');
      expect(result.amount, 300.00);
      expect(result.counterparty, 'Samuel Sankura Samago');
      expect(result.id, '260822194176925');
    });

    test('Extract Owner Name from Harmonization / Linking SMS', () {
      const harmonizationMsg =
          'Dear BISRAT TESFAYE ADEM, Thank you for submitting your request to harmonize your bank account with your National ID (fayda) information.\nAwash Bank!';
      expect(AwashParser.extractOwnerName(harmonizationMsg), 'BISRAT TESFAYE ADEM');

      const approvedMsg =
          'Dear BISRAT TESFAYE ADEM, Your National ID data and account harmonization have been successfully completed.\n\nThank you for your cooperation.\n\nAwash Bank';
      expect(AwashParser.extractOwnerName(approvedMsg), 'BISRAT TESFAYE ADEM');
    });

    test('BankSenders matching for Awash', () {
      expect(BankSenders.match('Awash Bank'), 'Awash Bank');
      expect(BankSenders.match('AWASH'), 'Awash Bank');
      expect(BankSenders.match('AwashBirr'), 'Awash Bank');
      expect(BankSenders.getKeywordsForBank('Awash Bank'), contains('awash'));
    });

    test('All 229 SMS in Awash Bank.xml are correctly parsed or ignored without errors', () async {
      final file = File('Awash Bank.xml');
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      final doc = XmlDocument.parse(content);
      final smsElements = doc.findAllElements('sms');

      int parsedCount = 0;
      int ignoredCount = 0;

      for (final elem in smsElements) {
        final body = (elem.getAttribute('body') ?? '')
            .replaceAll('&#10;', '\n')
            .replaceAll('&amp;', '&');

        if (BankSenders.isIgnoredMessage(body)) {
          ignoredCount++;
          continue;
        }

        final parsed = AwashParser.parse(body, DateTime.now());
        if (parsed != null) {
          parsedCount++;
          expect(parsed.amount, greaterThan(0));
          expect(parsed.bankName, 'Awash Bank');
          expect(parsed.id, isNotEmpty);
        } else {
          // If not parsed and not ignored, it must be informational marketing/holiday/terms text
          ignoredCount++;
        }
      }

      expect(parsedCount, 141);
      expect(parsedCount + ignoredCount, smsElements.length);
    });
  });
}
