import 'dart:io';
import '../lib/services/cbe_birr_parser.dart';
import '../lib/models/transaction.dart';

void main() {
  final file = File('CBE Birr.xml');
  if (!file.existsSync()) return;

  final lines = file.readAsLinesSync();
  final smsLines = lines.where((l) => l.trim().startsWith('<sms ')).toList();
  final latest100 = smsLines.length > 100 ? smsLines.sublist(smsLines.length - 100) : smsLines;

  print('=== Final Verification of CbeBirrParser on Latest 100 SMS ===');
  int parsedCount = 0;
  int unparsedCount = 0;
  final unparsedList = <String>[];

  for (int i = 0; i < latest100.length; i++) {
    final line = latest100[i];
    final bodyMatch = RegExp(r'body="([^"]*)"').firstMatch(line);
    final dateMatch = RegExp(r'date="(\d+)"').firstMatch(line);
    if (bodyMatch == null) continue;

    String body = bodyMatch.group(1)!;
    body = body
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#10;', '\n');

    DateTime date = DateTime.now();
    if (dateMatch != null) {
      date = DateTime.fromMillisecondsSinceEpoch(int.parse(dateMatch.group(1)!));
    }

    final tx = CbeBirrParser.parse(body, date);
    if (tx != null) {
      parsedCount++;
    } else {
      unparsedCount++;
      unparsedList.add(body);
    }
  }

  print('Parsed Transactions: $parsedCount / 100');
  print('Ignored non-transaction SMS (Vouchers, Wrong PIN): $unparsedCount / 100');
  print('\nIgnored SMS list:');
  for (var u in unparsedList.toSet()) {
    print('  - $u');
  }
}
