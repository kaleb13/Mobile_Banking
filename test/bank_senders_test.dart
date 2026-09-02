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
      expect(BankSenders.match('Awash Bank'), equals('Awash Bank'));
      expect(BankSenders.match('AWASH'), equals('Awash Bank'));
      expect(BankSenders.match('AwashBirr'), equals('Awash Bank'));
      expect(BankSenders.match('Zemen Bank'), equals('Zemen Bank'));
      expect(BankSenders.match('ZEMEN'), equals('Zemen Bank'));
      expect(BankSenders.match('zemen'), equals('Zemen Bank'));
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

    test('filters all OTP and one-time password variations', () {
      expect(BankSenders.isSecurityOrAuthMessage('Your OTP is 4532'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('One-Time Password: 9999'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('One time password for your account is 1234'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('OTP code 567890 expires in 5 min'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Your OTP 1234 is valid for 3 minutes'), isTrue);
    });

    test('filters wrong/invalid PIN and password messages', () {
      expect(BankSenders.isSecurityOrAuthMessage('Incorrect PIN. Try again.'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Invalid password entered'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Wrong PIN detected on your account'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Wrong password. Account temporarily locked.'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('PIN is incorrect'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Password is incorrect'), isTrue);
    });

    test('filters PIN reset and change prompts', () {
      expect(BankSenders.isSecurityOrAuthMessage('PIN reset successful'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Password reset link sent to your email'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Please reset your PIN'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Reset your password to continue'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Change your PIN for better security'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Change your password immediately'), isTrue);
    });

    test('filters auth and verification codes', () {
      expect(BankSenders.isSecurityOrAuthMessage('Your auth code is 789012'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('Verification code 4567 for login'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('<#>CBEBirrApp: Your code is 921486 Yf9mxp4+Cps'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('860421 is your CBEBirr App Verification Number.Thank You!'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('068412 is your CBEBirr App Verification Number.Thank You!'), isTrue);
      expect(BankSenders.isSecurityOrAuthMessage('364820 is your CBEBirr App Verification Number.Thank You!'), isTrue);
    });

    test('allows legitimate banking transactions through security filter', () {
      expect(BankSenders.isSecurityOrAuthMessage(
        'You have received ETB 1,500.00 from ABCD. Your balance is ETB 5,000.00'), isFalse);
      expect(BankSenders.isSecurityOrAuthMessage(
        'Your account has been debited ETB 200.00. Available balance: ETB 3,800.00'), isFalse);
      expect(BankSenders.isSecurityOrAuthMessage(
        'Payment of Birr 500.00 sent to Merchant XYZ successfully'), isFalse);
      expect(BankSenders.isSecurityOrAuthMessage(
        'Transfer of ETB 1000.00 completed. Ref: TXN12345'), isFalse);
      expect(BankSenders.isSecurityOrAuthMessage(
        'Loan disbursement of ETB 5000 credited to your account'), isFalse);
    });
  });
}
