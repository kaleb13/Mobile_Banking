import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/nib_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';

void main() {
  group('NibParser Tests (Disabled Pending Authentic Samples)', () {
    final testDate = DateTime(2026, 8, 10, 10, 0, 0);

    test('NibParser.parse returns null so messages route to unread notifications', () {
      const msg =
          'Dear Customer, your A/C 440xxxx1122 has been credited with ETB 6,000.00 by BIRUK ASSEFA on 10/08/2026. Available Balance: ETB 18,500.00. Ref: NIB112233.';
      final result = NibParser.parse(msg, testDate);
      expect(result, isNull, reason: 'Parser disabled until authentic user SMS samples are collected');
    });

    test('Sender matching via BankSenders remains active', () {
      expect(BankSenders.match('Nib Bank'), 'Nib Bank');
      expect(BankSenders.match('NIB'), 'Nib Bank');
      expect(BankSenders.match('NIB BANK'), 'Nib Bank');
      expect(BankSenders.match('nib'), 'Nib Bank');
      expect(BankSenders.isSameBank('Nib Bank', 'NIB'), isTrue);
    });

    test('extractOwnerName returns null while disabled', () {
      expect(NibParser.extractOwnerName('Dear KALEB, welcome'), isNull);
    });
  });
}
