import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('shibre_unrecognized_sms_2026-08-22_20-23.json');
  final content = await file.readAsString();
  final data = jsonDecode(content) as Map<String, dynamic>;
  final messages = data['messages'] as List<dynamic>;

  Map<String, int> patternGroups = {};
  Map<String, String> sampleByGroup = {};

  for (final msg in messages) {
    final body = (msg['body'] ?? '') as String;
    String clean = body.toLowerCase();

    String groupKey = 'unknown';
    if (clean.contains('transfered') || clean.contains('transferred')) {
      groupKey = 'CBE transfered/transferred';
    } else if (clean.contains('credited')) {
      groupKey = 'CBE credited';
    } else if (clean.contains('debited')) {
      groupKey = 'CBE debited';
    } else if (clean.contains('received')) {
      groupKey = 'CBE received';
    } else if (clean.contains('debit transaction')) {
      groupKey = 'CBE debit transaction';
    } else if (clean.contains('payment')) {
      groupKey = 'CBE payment';
    } else if (clean.contains('bought')) {
      groupKey = 'CBE bought/airtime';
    } else {
      groupKey =
          'Other: ${clean.substring(0, clean.length > 40 ? 40 : clean.length)}';
    }

    patternGroups[groupKey] = (patternGroups[groupKey] ?? 0) + 1;
    sampleByGroup.putIfAbsent(groupKey, () => body);
  }

  print('=== PATTERN GROUPS IN 575 MESSAGES ===');
  patternGroups.forEach((k, v) {
    print('\nGroup: "$k" ($v messages)');
    print('Sample: ${sampleByGroup[k]}');
  });
}
