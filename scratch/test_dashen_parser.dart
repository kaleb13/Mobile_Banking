import 'dart:io';
import 'package:mobile_banking_app/services/dashen_parser.dart';

void main() {
  final file = File('Dashin_Bank_SMS.xml');
  if (!file.existsSync()) {
    print('File Dashin_Bank_SMS.xml not found!');
    return;
  }

  final content = file.readAsStringSync();
  final bodyRegex = RegExp(r'body="([^"]+)"');
  final matches = bodyRegex.allMatches(content).toList();

  print('Found ${matches.length} messages in Dashin_Bank_SMS.xml\n');

  int parsedCount = 0;
  int failedCount = 0;
  String? extractedOwner;

  for (int i = 0; i < matches.length; i++) {
    String rawBody = matches[i].group(1)!;
    // Decode XML entities
    rawBody = rawBody
        .replaceAll('&#10;', '\n')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    final owner = DashenParser.extractOwnerName(rawBody);
    if (owner != null && extractedOwner == null) {
      extractedOwner = owner;
    }

    final tx = DashenParser.parse(rawBody, DateTime(2026, 8, 17));

    if (tx != null) {
      parsedCount++;
      print(
          '[$parsedCount/${matches.length}] [OK] ${tx.type.toUpperCase().padRight(7)} | ETB ${tx.amount.toStringAsFixed(2).padLeft(9)} | Bal: ETB ${tx.totalBalance.toStringAsFixed(2).padLeft(9)} | Bank: ${tx.name} | Party: ${tx.sender} | Date: ${tx.date}');
    } else {
      failedCount++;
      print('[FAIL #${i + 1}] Could not parse:\n$rawBody\n');
    }
  }

  print('\n=== Dashen Bank Parsing Summary ===');
  print('Total Messages: ${matches.length}');
  print(
      'Parsed Successfully: $parsedCount (${(parsedCount / matches.length * 100).toStringAsFixed(1)}%)');
  print('Failed: $failedCount');
  print('Extracted Owner Name: $extractedOwner');

  if (failedCount > 0) {
    exit(1);
  }
}
