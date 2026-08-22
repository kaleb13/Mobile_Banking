import 'dart:convert';
import 'dart:io';
import 'package:mobile_banking_app/services/telebirr_parser.dart';
import 'package:mobile_banking_app/services/cbe_parser.dart';
import 'package:mobile_banking_app/services/boa_parser.dart';
import 'package:mobile_banking_app/services/ahadu_parser.dart';
import 'package:mobile_banking_app/services/dashen_parser.dart';
import 'package:mobile_banking_app/services/cbe_birr_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';

void main() async {
  final file = File('shibre_unrecognized_sms_2026-08-22_20-23.json');
  final content = await file.readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;
  final messages = data['messages'] as List<dynamic>;

  int parsableCount = 0;
  int ignoredCount = 0;
  int unparsableCount = 0;

  Map<String, int> parsableByBank = {};
  Map<String, int> unparsableBySender = {};
  Map<String, List<String>> unparsableBodiesBySender = {};

  for (final msg in messages) {
    final sender = (msg['sender'] ?? '') as String;
    final body = (msg['body'] ?? '') as String;
    final date = DateTime.tryParse(msg['date'] ?? '') ?? DateTime.now();

    // Check if ignored
    if (BankSenders.isIgnoredMessage(body)) {
      ignoredCount++;
      continue;
    }

    // Try parsing
    ParsedSmsResult? result;
    final bankName = BankSenders.match(sender);

    if (bankName == 'Telebirr') {
      result = TelebirrParser.parse(body, date);
    } else if (bankName == 'CBE') {
      result = CbeParser.parse(body, date);
    } else if (bankName == 'BOA') {
      result = BoaParser.parse(body, date);
    } else if (bankName == 'Ahadu Bank') {
      result = AhaduParser.parse(body, date);
    } else if (bankName == 'Dashen Bank') {
      result = DashenParser.parse(body, date);
    } else if (bankName == 'CBE Birr') {
      result = CbeBirrParser.parse(body, date);
    } else {
      result = TelebirrParser.parse(body, date) ??
          CbeParser.parse(body, date) ??
          BoaParser.parse(body, date) ??
          AhaduParser.parse(body, date) ??
          DashenParser.parse(body, date) ??
          CbeBirrParser.parse(body, date);
    }

    if (result != null) {
      parsableCount++;
      final b = result.bankName;
      parsableByBank[b] = (parsableByBank[b] ?? 0) + 1;
    } else {
      unparsableCount++;
      unparsableBySender[sender] = (unparsableBySender[sender] ?? 0) + 1;
      unparsableBodiesBySender.putIfAbsent(sender, () => []).add(body);
    }
  }

  print('=== TOTAL OVERVIEW ===');
  print('Total Messages: ${messages.length}');
  print(
      'Currently Parsable: $parsableCount (${(parsableCount / messages.length * 100).toStringAsFixed(1)}%)');
  print(
      'Currently Auto-Ignored: $ignoredCount (${(ignoredCount / messages.length * 100).toStringAsFixed(1)}%)');
  print(
      'Unparsable: $unparsableCount (${(unparsableCount / messages.length * 100).toStringAsFixed(1)}%)');

  print('\n=== PARSABLE BREAKDOWN BY BANK ===');
  parsableByBank.forEach((k, v) => print('  $k: $v'));

  print('\n=== UNPARSABLE BREAKDOWN BY SENDER ===');
  unparsableBySender.forEach((k, v) => print('  $k: $v'));

  // Save distinct unparsable patterns to file
  final out = StringBuffer();
  out.writeln('=== UNPARSABLE PATTERNS BY SENDER ===\n');
  unparsableBodiesBySender.forEach((sender, bodies) {
    out.writeln('========================================');
    out.writeln('SENDER: $sender (${bodies.length} messages)');
    out.writeln('========================================');
    for (int i = 0; i < bodies.length; i++) {
      out.writeln('[${i + 1}] ${bodies[i]}\n');
    }
  });
  File('scratch/unparsable_patterns.txt').writeAsStringSync(out.toString());
  print('\nWrote all unparsable messages to scratch/unparsable_patterns.txt');
}
