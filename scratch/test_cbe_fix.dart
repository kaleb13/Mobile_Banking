import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:mobile_banking_app/models/parsed_sms_result.dart';

ParsedSmsResult? testCbeParse(String message, DateTime fallbackDate) {
  if (message.isEmpty) return null;

  final lowerMsg = message.toLowerCase();

  String type = '';
  double amount = 0.0;
  String senderOrRecipient = '';

  double extractAmount(RegExp regex) {
    final match = regex.firstMatch(message);
    if (match != null) {
      String amtStr = match.group(1)?.replaceAll(',', '') ?? '0';
      if (amtStr.endsWith('.')) {
        amtStr = amtStr.substring(0, amtStr.length - 1);
      }
      return double.tryParse(amtStr) ?? 0.0;
    }
    return 0.0;
  }

  // 1. Check credited first
  if (lowerMsg.contains('credited')) {
    type = 'income';

    amount = extractAmount(
        RegExp(r'credited\s+with\s+ETB\s*([0-9,.]+)', caseSensitive: false));
    if (amount <= 0) {
      amount = extractAmount(RegExp(
          r'credited\s+by\s+.+?\s+with\s+ETB\s*([0-9,.]+)',
          caseSensitive: false));
    }

    final fromMatch =
        RegExp(r'from\s+(.*?)(?=\s*,|\s+on|\.\s+)').firstMatch(message);
    if (fromMatch != null) {
      senderOrRecipient = fromMatch.group(1)?.trim() ?? '';
    }

    if (senderOrRecipient.isEmpty) {
      final creditedByMatch =
          RegExp(r'credited\s+by\s+(.*?)\s+with\s+ETB', caseSensitive: false)
              .firstMatch(message);
      if (creditedByMatch != null) {
        senderOrRecipient = creditedByMatch.group(1)?.trim() ?? '';
      }
    }
  } else if (lowerMsg.contains('received')) {
    type = 'income';
    amount = extractAmount(
        RegExp(r'received\s+ETB\s*([0-9,.]+)', caseSensitive: false));

    final fromMatchParens =
        RegExp(r'from\s+account\s+[\d*]+\s+\(([^)]+)\)', caseSensitive: false)
            .firstMatch(message);
    if (fromMatchParens != null) {
      senderOrRecipient = fromMatchParens.group(1)?.trim() ?? '';
    }
  } else if (lowerMsg.contains('transfer')) {
    // IMPORTANT: Check transfer BEFORE generic debited because transfer messages often
    // contain "Your account has been debited with a S.charge of ETB..."
    type = 'expense';
    amount = extractAmount(
        RegExp(r'transferr?ed\s+ETB\s*([0-9,.]+)', caseSensitive: false));
    if (amount <= 0) {
      amount = extractAmount(
          RegExp(r'transfer\s+of\s+ETB\s*([0-9,.]+)', caseSensitive: false));
    }

    // Pattern 1: "to <Name> on DD/MM/YYYY" (older / standard format)
    final toMatchWithDate =
        RegExp(r'to\s+(.*?)\s+on\s+\d{2}/\d{2}').firstMatch(message);
    if (toMatchWithDate != null) {
      senderOrRecipient = toMatchWithDate.group(1)?.trim() ?? '';
    }

    // Pattern 2: "to account 1****1234 (Recipient Name)" (newer format)
    if (senderOrRecipient.isEmpty) {
      final toMatchParens =
          RegExp(r'to\s+account\s+[\d*]+\s+\(([^)]+)\)', caseSensitive: false)
              .firstMatch(message);
      if (toMatchParens != null) {
        senderOrRecipient = toMatchParens.group(1)?.trim() ?? '';
      }
    }
  } else if (lowerMsg.contains('debited')) {
    type = 'expense';
    senderOrRecipient = 'ATM or Other';

    final startStr = 'has been debited with ETB';
    final startIdx = message.toLowerCase().indexOf(startStr.toLowerCase());
    if (startIdx != -1) {
      final valStart = startIdx + startStr.length;
      int numStart = valStart;
      while (numStart < message.length && message[numStart] == ' ') {
        numStart++;
      }
      int valEnd = -1;
      for (final marker in [' .', '.Including', ' including', ' Including']) {
        final idx = message.indexOf(marker, numStart);
        if (idx != -1 && (valEnd == -1 || idx < valEnd)) {
          valEnd = idx;
        }
      }
      if (valEnd == -1) valEnd = message.indexOf(' ', numStart);
      if (valEnd != -1) {
        String amtStr =
            message.substring(numStart, valEnd).replaceAll(',', '').trim();
        if (amtStr.endsWith('.')) {
          amtStr = amtStr.substring(0, amtStr.length - 1);
        }
        amount = double.tryParse(amtStr) ?? 0.0;
      }
    }
    if (amount <= 0) {
      amount = extractAmount(
          RegExp(r'debited\s+with\s+ETB\s*([0-9,.]+)', caseSensitive: false));
    }
  } else if (lowerMsg.contains('debit transaction')) {
    type = 'expense';
    senderOrRecipient = 'ATM or Other';
    amount = extractAmount(
        RegExp(r'debit transaction of ETB\s*([0-9,.]+)', caseSensitive: false));
  } else {
    return null;
  }

  if (amount <= 0) return null;

  // Extract Ref No / Transaction ID
  String? id;
  final idStartStr = 'id=';
  final idIdx = message.indexOf(idStartStr);
  if (idIdx != -1) {
    final valStart = idIdx + idStartStr.length;
    int valEnd = message.indexOf(' ', valStart);
    if (valEnd == -1) valEnd = message.length;
    id = message.substring(valStart, valEnd).trim();
  } else {
    final refRegex1 =
        RegExp(r'Ref\s*No\.?\s*([A-Za-z0-9]+)', caseSensitive: false);
    final refMatch1 = refRegex1.firstMatch(message);
    if (refMatch1 != null) {
      id = refMatch1.group(1);
    } else {
      final ftRegex = RegExp(r'(FT[0-9A-Z]+)', caseSensitive: true);
      final ftMatch = ftRegex.firstMatch(message);
      if (ftMatch != null) {
        id = ftMatch.group(1);
      }
    }
  }

  if (id == null) {
    final normalised = message.replaceAll(RegExp(r'\s+'), ' ').trim();
    final hash = sha256.convert(utf8.encode(normalised)).toString();
    id = 'CBE-${hash.substring(0, 16)}';
  }

  // Extract Balance
  double totalBalance = 0.0;
  String singleLineMsg = message.replaceAll('\n', ' ').replaceAll('\r', ' ');

  final balanceMatch = RegExp(
          r'[Cc]urrent\s+[Bb]alance\s+is\s+ETB\s*([0-9,]+\.?\d*)',
          caseSensitive: false)
      .firstMatch(singleLineMsg);
  if (balanceMatch != null) {
    String strippedBalance = balanceMatch.group(1)?.replaceAll(',', '') ?? '0';
    if (strippedBalance.endsWith('.')) {
      strippedBalance =
          strippedBalance.substring(0, strippedBalance.length - 1);
    }
    totalBalance = double.tryParse(strippedBalance) ?? 0.0;
  }

  // Extract Date
  DateTime txDate = fallbackDate;
  final dateRegex = RegExp(
      r'on\s+(\d{2}/\d{2}/\d{4})\s+at\s+(\d{2}:\d{2}:\d{2})',
      caseSensitive: false);
  final dateMatch = dateRegex.firstMatch(message);
  if (dateMatch != null) {
    try {
      final dateStr = '${dateMatch.group(1)} ${dateMatch.group(2)}';
      final format = DateFormat('dd/MM/yyyy HH:mm:ss');
      txDate = format.parse(dateStr);
    } catch (e) {
      // ignore
    }
  }

  return ParsedSmsResult(
    id: id,
    bankName: 'CBE',
    amount: amount,
    type: type,
    date: txDate,
    counterparty: senderOrRecipient.isNotEmpty ? senderOrRecipient : 'CBE',
    totalBalance: totalBalance,
    rawMessage: message,
    patternType: SmsPatternType.standardTransfer,
  );
}

void main() async {
  final file = File('shibre_unrecognized_sms_2026-08-22_20-23.json');
  final content = await file.readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;
  final messages = data['messages'] as List<dynamic>;

  int parsedCount = 0;
  int failedCount = 0;

  for (final msg in messages) {
    final body = (msg['body'] ?? '') as String;
    final date = DateTime.tryParse(msg['date'] ?? '') ?? DateTime.now();

    final res = testCbeParse(body, date);
    if (res != null) {
      parsedCount++;
    } else {
      failedCount++;
      print('FAILED: $body');
    }
  }

  print('=== TEST RESULTS ON 575 MESSAGES ===');
  print(
      'Successfully parsed: $parsedCount / ${messages.length} (${(parsedCount / messages.length * 100).toStringAsFixed(1)}%)');
  print('Failed to parse: $failedCount');
}
