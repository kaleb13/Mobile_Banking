import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/bunna_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:xml/xml.dart';

void main() {
  group('BunnaParser Unit Tests', () {
    final testDate = DateTime(2026, 6, 4, 15, 27, 53);

    test('Pattern 1: Inbound Deposit via IPS with reference', () {
      const msg =
          'Dear Customer\n'
          'A Deposit of 40,000.00 ETB has been made to your account 426*******611 BY IPS /INCOMMING/ABYSETAA/ABYSETAAFT26155FLQKV on 04-06-2026 15:27:53, your current balance is 40,000.00 ETB. Thank you.\n'
          'Bunna Bank';
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'income');
      expect(result.amount, 40000.00);
      expect(result.counterparty, 'IPS (ABYSETAA)');
      expect(result.id, 'ABYSETAAFT26155FLQKV');
      expect(result.totalBalance, 40000.00);
      expect(result.date, DateTime(2026, 6, 4, 15, 27, 53));
    });

    test('Pattern 2: Inbound Deposit small amount via IPS', () {
      const msg =
          'Dear Customer\n'
          'A Deposit of 100.00 ETB has been made to your account 426*******611 BY IPS /INCOMMING/ABYSETAA/ABYSETAAFT26155TP01K on 04-06-2026 15:34:38, your current balance is 40,100.00 ETB. Thank you.\n'
          'Bunna Bank';
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'income');
      expect(result.amount, 100.00);
      expect(result.counterparty, 'IPS (ABYSETAA)');
      expect(result.id, 'ABYSETAAFT26155TP01K');
      expect(result.totalBalance, 40100.00);
      expect(result.date, DateTime(2026, 6, 4, 15, 34, 38));
    });

    test('Pattern 3: Outbound Withdrawal to Company', () {
      const msg =
          "Dear Customer\n"
          "A Withdrawal of 40,000.00 ETB has been made from your account 426*******611 on 04-06-2026 15:39:51 by TO DMK TECHNOLOGY PLC '' UNDER FORMATION'', your current balance is 100.00 ETB. Thank you.\n"
          "Bunna Bank";
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'expense');
      expect(result.amount, 40000.00);
      expect(result.counterparty, "DMK TECHNOLOGY PLC '' UNDER FORMATION''");
      expect(result.totalBalance, 100.00);
      expect(result.date, DateTime(2026, 6, 4, 15, 39, 51));
      expect(result.id, startsWith('BUNNA-'));
    });

    test('Pattern 4: Withdrawal by Telebirr Transfer', () {
      const msg =
          'Dear Customer\n'
          'A Withdrawal of 56.00 ETB has been made from your account 426*******611 on 08-07-2026 23:20:14 by TELEBIRR TRANSFER, your current balance is 44.00 ETB. Thank you.\n'
          'Bunna Bank';
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'expense');
      expect(result.amount, 56.00);
      expect(result.counterparty, 'Telebirr Transfer');
      expect(result.totalBalance, 44.00);
      expect(result.date, DateTime(2026, 7, 8, 23, 20, 14));
    });

    test('Pattern 5: Deposit from entity with BY FROM', () {
      const msg =
          "Dear Customer\n"
          "A Deposit of 40,000.00 ETB has been made to your account 426*******611 BY FROM DMK TECHNOLOGY PLC '' UNDER FORMATION'' on 05-08-2026 16:22:12, your current balance is 40,044.00 ETB. Thank you.\n"
          "Bunna Bank";
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'income');
      expect(result.amount, 40000.00);
      expect(result.counterparty, "DMK TECHNOLOGY PLC '' UNDER FORMATION''");
      expect(result.totalBalance, 40044.00);
      expect(result.date, DateTime(2026, 8, 5, 16, 22, 12));
    });

    test('Pattern 6: Withdrawal with Digital Advice URL', () {
      const msg =
          'Dear Customer\n'
          'A Withdrawal of 2,012.00 ETB has been made from your account 426*******611 on 08-08-2026 16:01:11 by IPS OUT GOING, your current balance is 38,032.00 ETB. \n'
          'Please Download Your Digital Advice Here: \n'
          'https://online.bunnabanksc.com/receipt/#/lW1L+BNvCOFS8CfWjw1yyBy/f1C4pprSuQijjdsezfw=\n'
          'Please Rate Your Satisfaction Level Here: \n'
          'https://online.bunnabanksc.com/receipt/#/feedback/lW1L+BNvCOFS8CfWjw1yyBy/f1C4pprSuQijjdsezfw=\n'
          'Thank you.\n'
          'Bunna Bank';
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'expense');
      expect(result.amount, 2012.00);
      expect(result.counterparty, 'IPS Outgoing');
      expect(result.totalBalance, 38032.00);
      expect(result.date, DateTime(2026, 8, 8, 16, 1, 11));
      expect(result.id, startsWith('BUNNA-'));
    });

    test('Pattern 7: Telebirr Receivable Account Deposit (1.00 ETB)', () {
      const msg =
          'Dear Customer\n'
          'A Deposit of 1.00 ETB has been made to your account 426***611 BY TELEBIRR RECEIVABLE ACCOUNT TELEINCOME on 06-09-2026 15:55:28, your current balance is 219.47 ETB. Thank you.\n'
          'Bunna Bank';
      final result = BunnaParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Bunna Bank');
      expect(result.type, 'income');
      expect(result.amount, 1.00);
      expect(result.counterparty, 'TELEBIRR RECEIVABLE ACCOUNT TELEINCOME');
      expect(result.totalBalance, 219.47);
      expect(result.date, DateTime(2026, 9, 6, 15, 55, 28));
    });

    test('Sender matching via BankSenders', () {
      expect(BankSenders.match('Bunna Bank'), 'Bunna Bank');
      expect(BankSenders.match('BUNNA'), 'Bunna Bank');
      expect(BankSenders.match('Buna Bank'), 'Bunna Bank');
      expect(BankSenders.match('BUNA'), 'Bunna Bank');
      expect(BankSenders.match('bunnabank'), 'Bunna Bank');
      expect(BankSenders.isSameBank('Bunna Bank', 'BUNA'), isTrue);
      expect(BankSenders.isSameBank('Bunna Bank', 'Buna Bank'), isTrue);
    });

    test('Non-transactional messages return null', () {
      const otpMsg = 'Dear Customer, Use OTP 018947 to verify your account for Fayda harmonization purposes. Valid for 3 minutes. Please do not share this code with anyone.';
      expect(BunnaParser.parse(otpMsg, testDate), isNull);

      const securityMsg = 'Dear Customer\nYou must never share PINs, Passwords, OTPs, Verification codes, or other security credentials with any person under any circumstances.\nBunna Bank SC.';
      expect(BunnaParser.parse(securityMsg, testDate), isNull);

      const pinChangedMsg = 'Welcome to Bunna Bank\nDear customer, your digital banking PIN number has been changed to: 672363\nThank you';
      expect(BunnaParser.parse(pinChangedMsg, testDate), isNull);
    });

    test('Parse all Bunna Bank SMS from CBE and Buna.xml', () {
      final xmlFile = File('CBE and Buna.xml');
      if (xmlFile.existsSync()) {
        final doc = XmlDocument.parse(xmlFile.readAsStringSync());
        final smsElements = doc.findAllElements('sms')
            .where((el) => (el.getAttribute('address') ?? '').trim().toLowerCase().contains('bunna'))
            .toList();

        expect(smsElements.length, 37);

        int parsedCount = 0;
        int ignoredCount = 0;

        for (final el in smsElements) {
          final body = el.getAttribute('body') ?? '';
          final dateEpoch = int.tryParse(el.getAttribute('date') ?? '') ?? 0;
          final date = DateTime.fromMillisecondsSinceEpoch(dateEpoch);

          final result = BunnaParser.parse(body, date);
          if (result != null) {
            expect(result.bankName, 'Bunna Bank');
            expect(result.amount, greaterThan(0));
            expect(['income', 'expense'], contains(result.type));
            expect(result.counterparty, isNotEmpty);
            expect(result.totalBalance, greaterThanOrEqualTo(0));
            parsedCount++;
          } else {
            ignoredCount++;
          }
        }

        expect(parsedCount, 12, reason: 'Expected exactly 12 transactions');
        expect(ignoredCount, 25, reason: 'Expected exactly 25 non-transactional messages ignored');
      }
    });
  });
}
