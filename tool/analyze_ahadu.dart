import 'dart:io';
import 'package:mobile_banking_app/services/ahadu_parser.dart';

import 'package:mobile_banking_app/services/bank_senders.dart';

void main() {
  const row67 = '''Dear KALEB,
You have made a transfer of ETB 20,000.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 972665987 with reference number w2b17883520939961797 on 02-SEP-26. 
Your Available Balance is ETB 10,475.90. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/02-SEP-26/ 5466
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''';

  print('IS ROW 67 IGNORED: ${BankSenders.isIgnoredMessage(row67)}');
  final r67 = AhaduParser.parse(row67, DateTime.now());
  print('=== ROW 67 (NEW MESSAGE) PARSE RESULT ===');
  if (r67 != null) {
    print('SUCCESS amt=${r67.amount} bal=${r67.totalBalance} id=${r67.id} party=${r67.counterparty}');
  } else {
    print('NULL - FAILED TO PARSE!');
  }

  final file = File('Ahadu SMS.xml');
  if (!file.existsSync()) {
    print('Ahadu SMS.xml not found');
    return;
  }

  final content = file.readAsStringSync();
  final smsPattern = RegExp(r'<sms\s+([^>]*?)>', caseSensitive: false, dotAll: true);
  final matches = smsPattern.allMatches(content).toList();

  final List<Map<String, dynamic>> allMessages = [];

  for (int i = 0; i < matches.length; i++) {
    final attrString = matches[i].group(1) ?? '';
    final addressMatch = RegExp(r'address="([^"]*)"').firstMatch(attrString);
    final address = addressMatch?.group(1) ?? '';
    final bodyMatch = RegExp(r'body="([^"]*)"', dotAll: true).firstMatch(attrString);
    String body = bodyMatch?.group(1) ?? '';
    body = body
        .replaceAll('&#10;', '\n')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&apos;', "'");
    final dateMatch = RegExp(r'date="([^"]*)"').firstMatch(attrString);
    final dateMillis = int.tryParse(dateMatch?.group(1) ?? '0') ?? 0;
    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);

    allMessages.add({
      'index': i + 1,
      'address': address,
      'body': body,
      'date': date,
    });
  }

  print('TOTAL SMS IN XML: ${allMessages.length}');

  final nonFinancial = <Map<String, dynamic>>[];
  final financial = <Map<String, dynamic>>[];

  for (final msg in allMessages) {
    final body = msg['body'] as String;
    final lower = body.toLowerCase();
    final isOtp = lower.contains('otp') || lower.contains('one time password');
    final isActivation = lower.contains('activated successfully') || lower.contains('registered for mobile banking');
    final isFayda = lower.contains('ፋይዳ') || lower.contains('fayda');
    final isHoliday = lower.contains('ትንሣኤ') || lower.contains('በዓል');

    if (isOtp || isActivation || isFayda || isHoliday || (!lower.contains('etb') && !lower.contains('ብር') && !lower.contains('debit') && !lower.contains('deposit'))) {
      nonFinancial.add(msg);
    } else {
      financial.add(msg);
    }
  }

  print('NON-FINANCIAL (OTP/Fayda/Activation/Holiday): ${nonFinancial.length}');
  final nonFinBreakdown = <String, int>{};
  for (final msg in nonFinancial) {
    final body = (msg['body'] as String).toLowerCase();
    if (body.contains('otp') || body.contains('one time password')) {
      nonFinBreakdown['OTP / Password'] = (nonFinBreakdown['OTP / Password'] ?? 0) + 1;
    } else if (body.contains('activated successfully') || body.contains('registered for mobile banking')) {
      nonFinBreakdown['Account Activation / Registration'] = (nonFinBreakdown['Account Activation / Registration'] ?? 0) + 1;
    } else if (body.contains('ፋይዳ') || body.contains('fayda')) {
      nonFinBreakdown['Fayda / National ID Reminders'] = (nonFinBreakdown['Fayda / National ID Reminders'] ?? 0) + 1;
    } else if (body.contains('ትንሣኤ') || body.contains('በዓል') || body.contains('እንኳን')) {
      nonFinBreakdown['Holiday Greetings / Announcements'] = (nonFinBreakdown['Holiday Greetings / Announcements'] ?? 0) + 1;
    } else {
      nonFinBreakdown['Other Non-financial'] = (nonFinBreakdown['Other Non-financial'] ?? 0) + 1;
      print('=== OTHER NON-FINANCIAL #${msg['index']} ===\n${msg['body']}\n');
    }
  }
  print('NON-FINANCIAL BREAKDOWN: $nonFinBreakdown');
  print('FINANCIAL MESSAGES: ${financial.length}');

  int parsedCount = 0;
  final Map<String, List<int>> idToIndices = {};
  final List<Map<String, dynamic>> financialParsed = [];
  final List<Map<String, dynamic>> financialFailed = [];

  for (final msg in financial) {
    final body = msg['body'] as String;
    final date = msg['date'] as DateTime;
    final idx = msg['index'] as int;

    final parsed = AhaduParser.parse(body, date);
    if (parsed != null) {
      parsedCount++;
      idToIndices.putIfAbsent(parsed.id, () => []).add(idx);
      financialParsed.add({
        'msg': msg,
        'parsed': parsed,
      });
    } else {
      financialFailed.add(msg);
    }
  }

  print('FINANCIAL PARSED BY CURRENT PARSER: $parsedCount');
  print('FINANCIAL FAILED CURRENT PARSER: ${financialFailed.length}');
  print('UNIQUE TRANSACTION IDS GENERATED: ${idToIndices.length}');

  print('\n=== DUPLICATE MESSAGES IN XML ===');
  idToIndices.forEach((id, indices) {
    if (indices.length > 1) {
      print('ID $id appears in ${indices.length} SMS entries: indices $indices');
    }
  });

  print('\n=== FAILED FINANCIAL MESSAGES (${financialFailed.length}) ===');
  for (final f in financialFailed) {
    print('--- Msg #${f['index']} on ${f['date']} ---');
    print(f['body']);
  }

  print('\n=== PARSED FINANCIAL MESSAGES WITH PARSED FIELDS (${financialParsed.length}) ===');
  for (final p in financialParsed) {
    final m = p['msg'] as Map<String, dynamic>;
    final res = p['parsed'];
    print('--- Msg #${m['index']} | ID: ${res.id} | ${res.type.toUpperCase()} ETB ${res.amount} | Bal: ${res.totalBalance} | Party: ${res.counterparty} | Date: ${res.date} ---');
  }

  print('\n=== TESTING IMPROVED AHADU PARSING ON ALL 26 MESSAGES ===');
  for (final msg in financial) {
    final body = msg['body'] as String;
    final singleLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = singleLine.toLowerCase();
    final isIncome = lower.contains('received') || lower.contains('credited') || lower.contains('credit') || lower.contains('deposit');
    
    // Test Balance
    final balMatch = RegExp(
      r'(?:Available\s+Balance|Current\s+Balance|Balance)\s*(?:is|:)?\s*(?:ETB\s*)?(-?[0-9,]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(singleLine);
    double bal = 0.0;
    if (balMatch != null) {
      String bStr = balMatch.group(1)?.replaceAll(',', '') ?? '0';
      if (bStr.endsWith('.')) bStr = bStr.substring(0, bStr.length - 1);
      bal = double.tryParse(bStr) ?? 0.0;
    }

    // Test Counterparty
    String party = '';
    if (isIncome) {
      final fromMatch = RegExp(
        r'from\s+(.*?)\s+(?:with\s+(?:transaction\s+)?ref(?:erence)?|with\s+ref|on\s+\d{1,2}-|\.)',
        caseSensitive: false,
      ).firstMatch(singleLine);
      if (fromMatch != null) {
        party = fromMatch.group(1)?.trim() ?? '';
      }
      if (party.isEmpty) party = 'Ahadu Deposit';
    } else {
      final toMatch = RegExp(
        r'to\s+(.*?)\s+(?:with\s+(?:transaction\s+)?ref(?:erence)?|with\s+ref|on\s+\d{1,2}-|\.)',
        caseSensitive: false,
      ).firstMatch(singleLine);
      if (toMatch != null) {
        party = toMatch.group(1)?.trim() ?? '';
      }
      if (party.isEmpty) party = 'Ahadu Transfer';
    }

    print('Msg #${msg['index']} -> ${isIncome ? "INCOME" : "EXPENSE"} | Bal: $bal | Party: $party');
  }
}
