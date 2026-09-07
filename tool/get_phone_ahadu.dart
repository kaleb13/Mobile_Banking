import 'dart:convert';
import 'dart:io';

void main() async {
  final process = await Process.start('adb', [
    '-s',
    'adb-RF8T904ZDKR-KZ60da._adb-tls-connect._tcp',
    'shell',
    'content',
    'query',
    '--uri',
    'content://sms',
    '--projection',
    'address:date:body',
  ]);

  final lines = <String>[];
  process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    lines.add(line);
  });

  await process.exitCode;

  print('Total raw lines: ${lines.length}');
  final ahaduRows = <String>[];
  String? current;

  for (final l in lines) {
    if (l.startsWith('Row: ')) {
      if (current != null && current.contains('address=Ahadu Bank')) {
        ahaduRows.add(current);
      }
      current = l;
    } else if (current != null) {
      current += '\n$l';
    }
  }
  if (current != null && current.contains('address=Ahadu Bank')) {
    ahaduRows.add(current);
  }

  print('Found ${ahaduRows.length} Ahadu rows on phone.');
  print('\n=== LATEST 10 AHADU MESSAGES ON PHONE ===');
  for (int i = 0; i < (ahaduRows.length > 10 ? 10 : ahaduRows.length); i++) {
    print('-----------------------------------------');
    print(ahaduRows[i]);
  }
}
