import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/utils/link_extractor.dart';
import 'package:mobile_banking_app/models/transaction.dart';

void main() {
  group('LinkExtractor Unit Tests', () {
    test('extracts single HTTPS link from CBE SMS', () {
      const sms =
          'Dear Kaleb your Account 1*********2757 has been Credited with ETB 200.00 from Abebe. https://apps.cbe.com.et:9292/receipt/TX123456. Thank you for Banking with CBE!';
      final links = LinkExtractor.extractUrls(sms);
      expect(links.length, equals(1));
      expect(links.first, equals('https://apps.cbe.com.et:9292/receipt/TX123456'));
    });

    test('extracts Telebirr receipt URL cleanly stripping trailing punctuation', () {
      const sms =
          'You have transferred ETB 1,500.00 to Almaz. Receipt: http://receipt.telebirr.et/qr?id=987654.';
      final links = LinkExtractor.extractUrls(sms);
      expect(links.length, equals(1));
      expect(links.first, equals('http://receipt.telebirr.et/qr?id=987654'));
    });

    test('extracts multiple URLs from a single SMS', () {
      const sms =
          'Check your receipt at https://bank.et/r/123 or visit www.bank.et/help for more info.';
      final links = LinkExtractor.extractUrls(sms);
      expect(links.length, equals(2));
      expect(links[0], equals('https://bank.et/r/123'));
      expect(links[1], equals('www.bank.et/help'));
    });

    test('normalizes www URLs with https prefix', () {
      expect(
        LinkExtractor.normalizeUrl('www.cbe.com.et/receipt/123'),
        equals('https://www.cbe.com.et/receipt/123'),
      );
      expect(
        LinkExtractor.normalizeUrl('https://telebirr.et/r/123'),
        equals('https://telebirr.et/r/123'),
      );
    });

    test('returns empty list for SMS without links', () {
      const sms =
          'Your account 12345 has been credited with ETB 500.00 on 12/08/2026.';
      final links = LinkExtractor.extractUrls(sms);
      expect(links, isEmpty);
    });

    test('AppTransaction hasLinks and extractedLinks getters work accurately', () {
      final txWithLink = AppTransaction(
        id: 'tx_1',
        name: 'CBE',
        amount: 250.0,
        type: 'income',
        date: DateTime.now(),
        sender: 'Abebe',
        category: 'Income',
        rawMessage: 'Payment received. Receipt: https://apps.cbe.com.et/r/999',
        isAutoDetected: true,
      );

      final txWithoutLink = AppTransaction(
        id: 'tx_2',
        name: 'Telebirr',
        amount: 100.0,
        type: 'expense',
        date: DateTime.now(),
        sender: 'Store',
        category: 'Shopping',
        rawMessage: 'You have paid 100 ETB to Store.',
        isAutoDetected: true,
      );

      expect(txWithLink.hasLinks, isTrue);
      expect(txWithLink.extractedLinks, equals(['https://apps.cbe.com.et/r/999']));

      expect(txWithoutLink.hasLinks, isFalse);
      expect(txWithoutLink.extractedLinks, isEmpty);
    });
  });
}
