import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';

void main() {
  test('Verify all exported messages are handled (parsed or ignored)', () {
    final dir = Directory('.');
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('shibre_unrecognized_sms_'))
        .toList();
    if (files.isEmpty) {
      print('No export files found to test.');
      return;
    }
    final file = files.first;
    print('Testing against export file: ${file.path}');
    final data = jsonDecode(file.readAsStringSync());
    final messages = data['messages'] as List<dynamic>;

    int parsedCount = 0;
    int ignoredCount = 0;
    int unhandledCount = 0;

    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final sender = m['sender'] as String;
      final body = m['body'] as String;
      final date = DateTime.tryParse(m['date'] ?? '') ?? DateTime.now();

      if (BankSenders.isIgnoredMessage(body)) {
        ignoredCount++;
        continue;
      }

      final bank = BankSenders.match(sender);
      if (bank == 'Telebirr') {
        final parsed = TelebirrParser.parse(body, date);
        if (parsed != null) {
          parsedCount++;
          continue;
        }
      } else if (bank == 'CBE') {
        final parsed = CbeParser.parse(body, date);
        if (parsed != null) {
          parsedCount++;
          continue;
        }
      }

      unhandledCount++;
      print('UNHANDLED [${i + 1}] ($sender): ${body.replaceAll('\n', ' ')}');
    }

    print('\n========================================');
    print('Total Messages: ${messages.length}');
    print('Successfully Ignored (Non-financial): $ignoredCount');
    print('Successfully Parsed (Financial facts): $parsedCount');
    print('Remaining Unhandled: $unhandledCount');
    print('========================================\n');

    expect(unhandledCount, 0);
  });
}
