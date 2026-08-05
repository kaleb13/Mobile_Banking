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

    test('identifies password, PIN, and auth error messages correctly', () {
      const msg = '''
Sorry, your PIN or password is incorrect. please check and try again.
For any support and information related to telebirr service 
Send SMS to 126 or Contact us via
Telegram: https://t.me/telebirr 
Facebook: https://facebook.com/telebirr or
Visit our website :https://www.ethiotelecom.et/telebirr/  
Thank you for using telebirr
Ethio telecom
''';
      expect(BankSenders.isSecurityOrAuthMessage(msg), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Your OTP code is 123456'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('You have received ETB 500.00'), isFalse);
    });
  });
}
