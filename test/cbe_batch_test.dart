import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/sms_batch_parser.dart';
import 'package:mobile_banking_app/services/sms_service.dart';

void main() {
  test('Verify all CBE messages from CBE and Buna.xml', () {
    final file = File('CBE and Buna.xml');
    expect(file.existsSync(), isTrue);

    final content = file.readAsStringSync();
    final smsRegex = RegExp(r'<sms\s+([^>]+)/>');
    final matches = smsRegex.allMatches(content);

    final bodyRegex = RegExp(r'body="([^"]*)"');
    final addressRegex = RegExp(r'address="([^"]*)"');
    final dateRegex = RegExp(r'date="([^"]*)"');

    int totalCbe = 0;
    int parsedCbe = 0;
    int unparsedCbe = 0;
    final rawMessages = <RawSmsData>[];

    for (final m in matches) {
      final attrs = m.group(1) ?? '';
      final addrMatch = addressRegex.firstMatch(attrs);
      if (addrMatch?.group(1) != 'CBE') continue;
      totalCbe++;

      final bodyMatch = bodyRegex.firstMatch(attrs);
      String body = bodyMatch?.group(1) ?? '';
      body = body
          .replaceAll('&#10;', '\n')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&');

      final dateMatch = dateRegex.firstMatch(attrs);
      final timestamp = int.tryParse(dateMatch?.group(1) ?? '0') ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);

      rawMessages.add(RawSmsData(sender: 'CBE', body: body, date: date));

      final res = CbeParser.parse(body, date);
      if (res != null) {
        parsedCbe++;
      } else {
        unparsedCbe++;
      }
    }

    expect(totalCbe, equals(1024));
    expect(parsedCbe, equals(995));
    expect(unparsedCbe, equals(29));

    // Batch parser test
    final params = BatchParseParams(
      rawMessages: rawMessages,
      pausedBanks: [],
      customSenders: [],
      autoReasonRules: [],
      initialBankBalances: {},
    );

    final batchResult = SmsBatchParser.parseSync(params);
    print('Raw parsed by CbeParser: $parsedCbe');
    print('Batch transactions: ${batchResult.transactions.length}');
    print('Difference: ${parsedCbe - batchResult.transactions.length}');
    expect(batchResult.transactions.length, inInclusiveRange(990, 995));
    expect(batchResult.extractedUserName, isNotNull);
    print('Extracted User: ${batchResult.extractedUserName}');
  });
}
