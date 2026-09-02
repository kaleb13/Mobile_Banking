import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/zemen_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:xml/xml.dart';

void main() {
  group('ZemenParser Unit Tests', () {
    final testDate = DateTime(2026, 8, 10, 10, 0, 0);

    test('Pattern 1: Salary / Direct Deposit Credit', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 has been credited with ETB 35,000.00 by TECH PLC SALARY on 10/08/2026. A/c Available Bal. is ETB 45,200.00. Ref: ZEMSAL260810.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'income');
      expect(result.amount, 35000.00);
      expect(result.counterparty, 'TECH PLC SALARY');
      expect(result.id, 'ZEMSAL260810');
      expect(result.totalBalance, 45200.00);
      expect(result.date, DateTime(2026, 8, 10));
    });

    test('Pattern 2: ATM Cash Withdrawal', () {
      const msg =
          'Dear Customer, ETB 2,000.00 has been withdrawn from your account 100xxxx1234 via ATM at BOLE BRANCH on 11/08/2026. A/c Available Bal. is ETB 43,200.00.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 2000.00);
      expect(result.counterparty, 'ATM (BOLE BRANCH)');
      expect(result.totalBalance, 43200.00);
      expect(result.date, DateTime(2026, 8, 11));
    });

    test('Pattern 3: POS Merchant Purchase', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 has been debited with Birr 1,450.00 due to POS TRANSACTION at FRESH CORNER SUPERMARKET on 12/08/2026. Available balance is Birr 41,750.00. Ref: POS44321.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 1450.00);
      expect(result.counterparty, 'FRESH CORNER SUPERMARKET');
      expect(result.id, 'POS44321');
      expect(result.totalBalance, 41750.00);
      expect(result.date, DateTime(2026, 8, 12));
    });

    test('Pattern 4: Inward RTGS / IPS Transfer', () {
      const msg =
          'Dear Customer, Inward RTGS transfer of ETB 20,000.00 from NATIONAL BANK to your account 100xxxx1234 completed. A/c Available Bal. is ETB 61,750.00. Ref: ZEM987654.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'income');
      expect(result.amount, 20000.00);
      expect(result.counterparty, 'NATIONAL BANK');
      expect(result.id, 'ZEM987654');
      expect(result.totalBalance, 61750.00);
    });

    test('Pattern 5: Mobile P2P Outward Transfer', () {
      const msg =
          'Dear Customer, ETB 5,000.00 transferred from account 100xxxx1234 to DANIEL MEKONNEN on 14/08/2026. Charge ETB 5.00. Available Bal. is ETB 56,745.00. Txn ID: ZEM887766.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 5000.00);
      expect(result.counterparty, 'DANIEL MEKONNEN');
      expect(result.id, 'ZEM887766');
      expect(result.totalBalance, 56745.00);
      expect(result.date, DateTime(2026, 8, 14));
    });

    test('Pattern 6: Telebirr Wallet Outward Transfer', () {
      const msg =
          'Dear Customer, ETB 1,000.00 transferred to Telebirr Wallet 0911223344 from account 100xxxx1234 on 15/08/2026. Available Bal. is ETB 55,745.00. Ref: ZEMTB9911.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 1000.00);
      expect(result.counterparty, 'Telebirr (0911223344)');
      expect(result.id, 'ZEMTB9911');
      expect(result.totalBalance, 55745.00);
      expect(result.date, DateTime(2026, 8, 15));
    });

    test('Pattern 7: Airtime Top-up (Unlocked Reason)', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 has been debited with ETB 350.00 for Airtime top-up on 16/08/2026. Available Bal. is ETB 55,395.00. Ref: ZEMAIR44.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 350.00);
      expect(result.counterparty, 'Airtime');
      expect(result.id, 'ZEMAIR44');
      expect(result.totalBalance, 55395.00);
      expect(result.patternType, SmsPatternType.telebirrAirtime);
      expect(result.isSystemLocked, isFalse);
      expect(result.date, DateTime(2026, 8, 16));
    });

    test('Pattern 8: Inward P2P Credit', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 credited with ETB 4,500.00 from BIRHANU HAILE on 17/08/2026. A/c Available Bal. is ETB 59,895.00. Ref: ZEMCR5511.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'income');
      expect(result.amount, 4500.00);
      expect(result.counterparty, 'BIRHANU HAILE');
      expect(result.id, 'ZEMCR5511');
      expect(result.totalBalance, 59895.00);
      expect(result.date, DateTime(2026, 8, 17));
    });

    test('Pattern 9: Electricity Utility Payment', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 debited with ETB 750.00 for ELECTRICITY UTILITY PAYMENT on 18/08/2026. Available Bal. is ETB 59,145.00. Ref: ZEMUTL88.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 750.00);
      expect(result.counterparty, 'ELECTRICITY UTILITY PAYMENT');
      expect(result.id, 'ZEMUTL88');
      expect(result.totalBalance, 59145.00);
      expect(result.date, DateTime(2026, 8, 18));
    });

    test('Pattern 10: Monthly SMS Service Fee', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 debited with ETB 30.00 for Monthly SMS Service Charge on 19/08/2026. Available Bal. is ETB 59,115.00. Ref: ZEMFEE99.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNotNull);
      expect(result!.bankName, 'Zemen Bank');
      expect(result.type, 'expense');
      expect(result.amount, 30.00);
      expect(result.counterparty, 'Monthly SMS Service Charge');
      expect(result.id, 'ZEMFEE99');
      expect(result.totalBalance, 59115.00);
      expect(result.date, DateTime(2026, 8, 19));
    });

    test('Sender matching via BankSenders', () {
      expect(BankSenders.match('Zemen Bank'), 'Zemen Bank');
      expect(BankSenders.match('ZEMEN'), 'Zemen Bank');
      expect(BankSenders.match('Zemen'), 'Zemen Bank');
      expect(BankSenders.isSameBank('Zemen Bank', 'ZEMEN'), isTrue);
    });

    test('Parse entire docs/Zemen Bank.xml backup dataset without failure', () {
      final xmlFile = File('docs/Zemen Bank.xml');
      if (xmlFile.existsSync()) {
        final doc = XmlDocument.parse(xmlFile.readAsStringSync());
        final smsElements = doc.findAllElements('sms');
        expect(smsElements.length, 10);

        int parsedCount = 0;
        for (final el in smsElements) {
          final body = el.getAttribute('body') ?? '';
          final dateEpoch = int.tryParse(el.getAttribute('date') ?? '') ?? 0;
          final date = DateTime.fromMillisecondsSinceEpoch(dateEpoch);

          final result = ZemenParser.parse(body, date);
          expect(result, isNotNull, reason: 'Failed to parse: $body');
          expect(result!.bankName, 'Zemen Bank');
          expect(result.amount, greaterThan(0));
          expect(['income', 'expense'], contains(result.type));
          expect(result.counterparty, isNotEmpty);
          parsedCount++;
        }
        expect(parsedCount, 10);
      }
    });
  });
}
