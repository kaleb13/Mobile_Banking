import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/models/bank_definition.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';
import 'package:mobile_banking_app/services/dynamic_rule_parser.dart';
import 'package:mobile_banking_app/services/bank_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DynamicRuleParser & BankRegistry Tests', () {
    test('DynamicRuleParser correctly extracts facts from declarative rules', () {
      const bank = BankDefinition(
        id: 'mock_bank',
        bankName: 'Mock Bank',
        officialTitle: 'Mock Bank of Ethiopia',
        subtitle: 'Mock Bank S.C.',
        senderIdentifiers: BankSenderIdentifier(
          canonical: 'Mock Bank',
          keywords: ['mock'],
          exactSenders: ['MOCK_BANK'],
        ),
        branding: BankBranding(
          gradientColorsHex: ['#123456', '#654321'],
        ),
        parsing: BankParsingRule(
          securityFilterRegex: r'(?i)(?:OTP|verification code)',
          patterns: [
            BankPatternRule(
              patternId: 'mock_credit',
              name: 'Credit Alert',
              type: 'income',
              triggerKeywords: ['credited', 'etb'],
              regex: r'(?i)credited with ETB\s*([0-9,.]+)\s+from\s+(.+?)\s+balance is ETB\s*([0-9,.]+)\s+ref\s*:\s*([A-Za-z0-9]+)',
              amountGroup: 1,
              counterpartyGroup: 2,
              balanceGroup: 3,
              idGroup: 4,
            ),
          ],
        ),
      );

      final now = DateTime(2026, 9, 16, 12, 0);
      const sms = 'Your account was credited with ETB 1,500.00 from Abebe Bikila balance is ETB 15,000.00 ref: TX123456789';

      final result = DynamicRuleParser.parse(bank, sms, now);

      expect(result, isNotNull);
      expect(result!.id, 'TX123456789');
      expect(result.bankName, 'Mock Bank');
      expect(result.amount, 1500.0);
      expect(result.type, 'income');
      expect(result.counterparty, 'Abebe Bikila');
      expect(result.totalBalance, 15000.0);
      expect(result.patternType, SmsPatternType.standardTransfer);
      expect(result.rawMessage, sms);
    });

    test('DynamicRuleParser rejects security and OTP messages', () {
      const bank = BankDefinition(
        id: 'mock_bank',
        bankName: 'Mock Bank',
        officialTitle: 'Mock Bank of Ethiopia',
        subtitle: 'Mock Bank S.C.',
        senderIdentifiers: BankSenderIdentifier(canonical: 'Mock Bank'),
        branding: BankBranding(gradientColorsHex: ['#123456', '#654321']),
        parsing: BankParsingRule(
          securityFilterRegex: r'(?i)(?:OTP|verification code)',
          patterns: [
            BankPatternRule(
              patternId: 'any',
              name: 'Any',
              type: 'expense',
              regex: r'(.*)',
              amountGroup: 0,
              counterpartyGroup: 0,
            ),
          ],
        ),
      );

      const otpMsg = 'Your OTP verification code is 849201. Never share this code.';
      final result = DynamicRuleParser.parse(bank, otpMsg, DateTime.now());
      expect(result, isNull);
    });

    test('BankRegistry loads from JSON and matches senders and branding', () {
      const testJson = '''
      {
        "schemaVersion": 1,
        "rulesVersion": 2026091601,
        "banks": [
          {
            "id": "new_cloud_bank",
            "bankName": "Cloud Bank",
            "officialTitle": "Cloud Bank S.C.",
            "subtitle": "Future Cloud Banking",
            "senderIdentifiers": {
              "canonical": "Cloud Bank",
              "keywords": ["cloudbank", "cloud"],
              "exactSenders": ["CLOUDBANK"]
            },
            "branding": {
              "gradientColors": ["#FF0000", "#0000FF"],
              "isDarkTextTheme": false
            },
            "parsing": {
              "patterns": []
            }
          }
        ]
      }
      ''';

      final loaded = BankRegistry.instance.loadFromJsonString(testJson);
      expect(loaded, isTrue);

      final bank = BankRegistry.instance.getBankById('new_cloud_bank');
      expect(bank, isNotNull);
      expect(bank!.bankName, 'Cloud Bank');
      expect(bank.subtitle, 'Future Cloud Banking');

      // Test sender matching
      final match = BankRegistry.instance.matchBankBySender('CLOUDBANK');
      expect(match, isNotNull);
      expect(match!.bankName, 'Cloud Bank');

      // Test branding and gradient colors
      final branding = BankRegistry.instance.getBranding('Cloud Bank');
      expect(branding, isNotNull);
      final colors = branding!.toColorList();
      expect(colors.length, 2);
    });

    test('BankRegistry init loads all 10 banks automatically', () async {
      final registry = BankRegistry.instance;
      await registry.init();
      expect(registry.allBanks.length, greaterThanOrEqualTo(10));
      expect(registry.getBankById('telebirr'), isNotNull);
      expect(registry.getBankById('cbe'), isNotNull);
      expect(registry.getBankById('boa'), isNotNull);
      expect(registry.getBankById('ahadu'), isNotNull);
    });
  });
}
