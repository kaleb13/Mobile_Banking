import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/zemen_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';

void main() {
  group('ZemenParser Tests (Disabled Pending Authentic Samples)', () {
    final testDate = DateTime(2026, 8, 10, 10, 0, 0);

    test('ZemenParser.parse returns null so messages route to unread notifications', () {
      const msg =
          'Dear Customer, your account 100xxxx1234 has been credited with ETB 35,000.00 by TECH PLC SALARY on 10/08/2026. A/c Available Bal. is ETB 45,200.00. Ref: ZEMSAL260810.';
      final result = ZemenParser.parse(msg, testDate);
      expect(result, isNull, reason: 'Parser disabled until authentic user SMS samples are collected');
    });

    test('Sender matching via BankSenders remains active', () {
      expect(BankSenders.match('Zemen Bank'), 'Zemen Bank');
      expect(BankSenders.match('ZEMEN'), 'Zemen Bank');
      expect(BankSenders.match('Zemen'), 'Zemen Bank');
      expect(BankSenders.isSameBank('Zemen Bank', 'ZEMEN'), isTrue);
    });

    test('extractOwnerName returns null while disabled', () {
      expect(ZemenParser.extractOwnerName('Dear KALEB, welcome'), isNull);
    });
  });
}
