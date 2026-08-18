import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/sms_service.dart';
import 'package:mobile_banking_app/services/sms_batch_parser.dart';
import 'package:mobile_banking_app/models/sender.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final baseDate = DateTime(2026, 4, 24, 10, 0);

  group('SmsBatchParser in Isolate', () {
    test('parses multi-bank messages and extracts user name and balances in isolate', () async {
      final rawSms = [
        RawSmsData(
          sender: 'CBE',
          body: "Dear Kaleb, your Account 1*********2757 has been Credited with ETB 207.50 from Kaleab Afesha, on 24/04/2026 at 13:44:16 with Ref No FT26114Y5F42 Your Current Balance is ETB 556.87. Thank you for Banking with CBE!",
          date: baseDate.add(const Duration(hours: 1)),
        ),
        RawSmsData(
          sender: 'Telebirr',
          body: "You have transferred ETB 150.00 to Abebe Kebede on 24/04/2026 14:00:00. Your current balance is ETB 850.00. transaction number is TXN998811.",
          date: baseDate.add(const Duration(hours: 2)),
        ),
        RawSmsData(
          sender: 'CBEBirr',
          body: "Your CBE Birr account has been credited with 500.00Br. on 24/04/26 15:00, txn id CB123456. Account Balance is 1500.00Br.",
          date: baseDate.add(const Duration(hours: 3)),
        ),
        // Amharic message (should be dropped)
        RawSmsData(
          sender: 'Telebirr',
          body: "ውድ ደንበኛ የቴሌብር አገልግሎት ስለተጠቀሙ እናመሰግናለን",
          date: baseDate.add(const Duration(hours: 4)),
        ),
        // Security OTP message (should be dropped)
        RawSmsData(
          sender: 'CBE',
          body: "Your verification code is 492019. Do not share this OTP with anyone.",
          date: baseDate.add(const Duration(hours: 5)),
        ),
      ];

      final autoRules = [
        const AutoReasonRule(
          id: 42,
          name: 'Freelance',
          sender: 'Kaleab Afesha',
          type: 'income',
        ),
      ];

      final params = BatchParseParams(
        rawMessages: rawSms,
        pausedBanks: [],
        customSenders: [],
        autoReasonRules: autoRules,
        initialBankBalances: {},
      );

      final result = await SmsBatchParser.parseInIsolate(params);

      // Verify transactions
      expect(result.transactions.length, equals(3));
      expect(result.extractedUserName, equals('Kaleb'));

      // Check CBE tx
      final cbeTx = result.transactions.firstWhere((t) => t.name == 'CBE');
      expect(cbeTx.amount, equals(207.50));
      expect(cbeTx.type, equals('income'));
      expect(cbeTx.sender, equals('Kaleab Afesha'));
      expect(cbeTx.totalBalance, equals(556.87));
      expect(cbeTx.reasonId, equals(42));
      expect(cbeTx.reason, equals('Freelance'));

      // Check Telebirr tx
      final telebirrTx = result.transactions.firstWhere((t) => t.name == 'Telebirr');
      expect(telebirrTx.amount, equals(150.00));
      expect(telebirrTx.type, equals('expense'));
      expect(telebirrTx.totalBalance, equals(850.00));

      // Check CBE Birr tx
      final cbeBirrTx = result.transactions.firstWhere((t) => t.name == 'CBE Birr');
      expect(cbeBirrTx.amount, equals(500.00));
      expect(cbeBirrTx.type, equals('income'));
      expect(cbeBirrTx.totalBalance, equals(1500.00));
    });

    test('ignores paused bank messages', () async {
      final rawSms = [
        RawSmsData(
          sender: 'Telebirr',
          body: "You have received 300.00 ETB from John Doe on 24/04/2026 10:00. Balance: 1300.00 ETB.",
          date: baseDate,
        ),
        RawSmsData(
          sender: 'CBE',
          body: "Dear Customer, your Account 1*********2757 has been Credited with ETB 500.00 from Jane, on 24/04/2026. Current Balance is ETB 2000.00.",
          date: baseDate.add(const Duration(minutes: 5)),
        ),
      ];

      final params = BatchParseParams(
        rawMessages: rawSms,
        pausedBanks: ['Telebirr'],
        customSenders: [],
        autoReasonRules: [],
        initialBankBalances: {},
      );

      final result = await SmsBatchParser.parseInIsolate(params);

      expect(result.transactions.length, equals(1));
      expect(result.transactions.first.name, equals('CBE'));
    });
  });
}
