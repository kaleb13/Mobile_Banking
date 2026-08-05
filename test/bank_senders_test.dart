import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';

void main() {
  group('BankSenders', () {
    test('matches genuine bank sender IDs correctly', () {
      expect(BankSenders.match('CBE'), equals('CBE'));
      expect(BankSenders.match('cbe'), equals('CBE'));
      expect(BankSenders.match('CBEBirr'), equals('CBE Birr'));
      expect(BankSenders.match('CBE BIRR'), equals('CBE Birr'));
      expect(BankSenders.match('Telebirr'), equals('Telebirr'));
      expect(BankSenders.match('TELEBIRR'), equals('Telebirr'));
      expect(BankSenders.match('127'), equals('Telebirr'));
      expect(BankSenders.match('Ahadu Bank'), equals('Ahadu Bank'));
      expect(BankSenders.match('AHADU'), equals('Ahadu Bank'));
    });

    test('rejects personal phone numbers and invalid senders', () {
      expect(BankSenders.match('+251911234567'), isNull);
      expect(BankSenders.match('0911234567'), isNull);
      expect(BankSenders.match('251911234567'), isNull);
      expect(BankSenders.match('RandomUser'), isNull);
      expect(BankSenders.match(''), isNull);
      expect(BankSenders.match(null), isNull);
    });
  });
}
