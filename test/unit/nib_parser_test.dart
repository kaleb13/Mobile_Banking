import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/nib_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:xml/xml.dart';

void main() {
  group('NibParser Unit Tests', () {
    final testDate = DateTime(2026, 8, 10, 10, 0, 0);

    test('Pattern 1: Inbound Credit (Transfer / Deposit)', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 has been credited with ETB 6,000.00 by BIRUK ASSEFA on 10/08/2026. Available Balance: ETB 18,500.00. Ref: NIB112233.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'income');
      expect(result.amount, 6000.00);
      expect(result.counterparty, 'BIRUK ASSEFA');
      expect(result.id, 'NIB112233');
      expect(result.totalBalance, 18500.00);
      expect(result.date, DateTime(2026, 8, 10));
    });

    test('Pattern 2: Debit with Service Charge (Total Debited)', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 has been debited with ETB 1,500.00 on 11/08/2026. Service Charge: ETB 5.00. Total Debited: ETB 1,505.00. Available Balance: ETB 16,995.00. Ref: NIB889900.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'expense');
      expect(result.amount, 1505.00);
      expect(result.counterparty, 'Debit');
      expect(result.id, 'NIB889900');
      expect(result.totalBalance, 16995.00);
      expect(result.date, DateTime(2026, 8, 11));
    });

    test('Pattern 3: Outbound Transfer to Person', () {
      const msg =
          'Dear Customer, you have transferred ETB 2,000.00 from A/C 440xxxx1122 to SELAMAWIT KASSA on 12/08/2026. Service Charge: ETB 2.00 VAT: ETB 0.30. Available Balance: ETB 14,992.70. Ref: NIB556677.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'expense');
      expect(result.amount, 2000.00);
      expect(result.counterparty, 'SELAMAWIT KASSA');
      expect(result.id, 'NIB556677');
      expect(result.totalBalance, 14992.70);
      expect(result.date, DateTime(2026, 8, 12));
    });

    test('Pattern 4: Airtime Purchase (Unlocked Reason)', () {
      const msg =
          'Dear Customer, you have purchased airtime of ETB 50.00 for 0911554433 from A/C 440xxxx1122 on 13/08/2026. Available Balance: ETB 14,942.70. Ref: NIBAIR88.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'expense');
      expect(result.amount, 50.00);
      expect(result.counterparty, 'Airtime (0911554433)');
      expect(result.id, 'NIBAIR88');
      expect(result.totalBalance, 14942.70);
      expect(result.patternType, SmsPatternType.telebirrAirtime);
      expect(result.isSystemLocked, isFalse);
      expect(result.date, DateTime(2026, 8, 13));
    });

    test('Pattern 5: Inbound IPS / Interbank Transfer', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 has been credited with ETB 12,500.00 via IPS from CBE on 14/08/2026. Available Balance: ETB 27,442.70. Ref: NIBIPS99.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'income');
      expect(result.amount, 12500.00);
      expect(result.counterparty, 'CBE via IPS');
      expect(result.id, 'NIBIPS99');
      expect(result.totalBalance, 27442.70);
      expect(result.date, DateTime(2026, 8, 14));
    });

    test('Pattern 6: ATM Cash Withdrawal', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 has been debited with ETB 3,000.00 at ATM PIASSA on 15/08/2026. Available Balance: ETB 24,442.70. Ref: NIBATM33.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'expense');
      expect(result.amount, 3000.00);
      expect(result.counterparty, 'ATM PIASSA');
      expect(result.id, 'NIBATM33');
      expect(result.totalBalance, 24442.70);
      expect(result.date, DateTime(2026, 8, 15));
    });

    test('Pattern 7: Utility Payment', () {
      const msg =
          'Dear Customer, you have paid ETB 680.00 for ELECTRIC UTILITY from A/C 440xxxx1122 on 16/08/2026. Available Balance: ETB 23,762.70. Ref: NIBUTL44.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'expense');
      expect(result.amount, 680.00);
      expect(result.counterparty, 'ELECTRIC UTILITY');
      expect(result.id, 'NIBUTL44');
      expect(result.totalBalance, 23762.70);
      expect(result.date, DateTime(2026, 8, 16));
    });

    test('Pattern 8: Direct Salary Credit', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 credited with ETB 22,000.00 by ABC CORP SALARY on 17/08/2026. Available Balance: ETB 45,762.70. Ref: NIBSAL22.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Nib Bank');
      expect(result.type, 'income');
      expect(result.amount, 22000.00);
      expect(result.counterparty, 'ABC CORP SALARY');
      expect(result.id, 'NIBSAL22');
      expect(result.totalBalance, 45762.70);
      expect(result.date, DateTime(2026, 8, 17));
    });

    test('Sender matching via BankSenders', () {
      expect(BankSenders.match('Nib Bank'), 'Nib Bank');
      expect(BankSenders.match('NIB'), 'Nib Bank');
      expect(BankSenders.match('Nib'), 'Nib Bank');
      expect(BankSenders.match('NIBBANK'), 'Nib Bank');
      expect(BankSenders.match('NIB BANK'), 'Nib Bank');
      expect(BankSenders.isSameBank('Nib Bank', 'NIB'), isTrue);
    });

    test('Parse entire docs/Nib Bank.xml backup dataset without failure', () {
      final xmlFile = File('docs/Nib Bank.xml');
      if (xmlFile.existsSync()) {
        final doc = XmlDocument.parse(xmlFile.readAsStringSync());
        final smsElements = doc.findAllElements('sms');
        expect(smsElements.length, 8);

        int parsedCount = 0;
        for (final el in smsElements) {
          final body = el.getAttribute('body') ?? '';
          final dateEpoch = int.tryParse(el.getAttribute('date') ?? '') ?? 0;
          final date = DateTime.fromMillisecondsSinceEpoch(dateEpoch);

          final result = NibParser.parse(body, date);
          expect(result, isNotNull, reason: 'Failed to parse: $body');
          expect(result!.bankName, 'Nib Bank');
          expect(result.amount, greaterThan(0));
          expect(['income', 'expense'], contains(result.type));
          expect(result.counterparty, isNotEmpty);
          parsedCount++;
        }
        expect(parsedCount, 8);
      }
    });
  });
}
