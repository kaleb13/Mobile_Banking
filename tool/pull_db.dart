import 'dart:convert';
import 'dart:io';

void main() async {
  final process = await Process.start('adb', [
    '-s',
    'adb-RF8T904ZDKR-KZ60da._adb-tls-connect._tcp',
    'exec-out',
    'run-as',
    'com.example.mobile_banking_app',
    'base64',
    'databases/finance_v3.db',
  ]);

  final b64Buffer = StringBuffer();
  process.stdout.transform(utf8.decoder).listen((data) {
    b64Buffer.write(data);
  });

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    print('Failed to pull base64 db, exitCode: $exitCode');
    return;
  }

  final cleanB64 = b64Buffer.toString().replaceAll(RegExp(r'\s+'), '');
  final bytes = base64Decode(cleanB64);
  final file = File('tool/phone_finance.db');
  file.writeAsBytesSync(bytes);
  print('Successfully saved phone_finance.db, size: ${bytes.length} bytes');
}
