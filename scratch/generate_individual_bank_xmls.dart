import 'dart:io';
import 'package:intl/intl.dart';

class SmsItem {
  final String address;
  final String body;
  final DateTime dateTime;

  SmsItem({
    required this.address,
    required this.body,
    required this.dateTime,
  });
}

void writeXmlFile(String filePath, String bankName, List<SmsItem> items) {
  items.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final buffer = StringBuffer();
  buffer.writeln("<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>");
  buffer.writeln("<!--File Created By SMS Backup & Restore Pro v10.24.003 for $bankName Integration Testing-->");
  buffer.writeln("<!--");
  buffer.writeln("");
  buffer.writeln("To view this file in a more readable format, visit https://synctech.com.au/view-backup/");
  buffer.writeln("");
  buffer.writeln("-->");

  final backupDateMs = DateTime.now().millisecondsSinceEpoch;
  buffer.writeln('<smses count="${items.length}" backup_set="a1b2c3d4-e5f6-7890-abcd-${bankName.hashCode.abs()}" backup_date="$backupDateMs" type="full">');

  final readableFmt = DateFormat("d MMM yyyy h:mm:ss a");

  for (final item in items) {
    final ms = item.dateTime.millisecondsSinceEpoch;
    final dateSentMs = ms - 3000;
    final readable = readableFmt.format(item.dateTime).toLowerCase();

    final escapedBody = item.body
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;')
        .replaceAll('\n', '&#10;');

    buffer.writeln('  <sms protocol="0" address="${item.address}" date="$ms" type="1" subject="null" body="$escapedBody" toa="null" sc_toa="null" service_center="+251971200440" read="1" status="-1" locked="0" date_sent="$dateSentMs" sub_id="1" readable_date="$readable" contact_name="(Unknown)" />');
  }

  buffer.writeln('</smses>');

  File(filePath).writeAsStringSync(buffer.toString());
  print('Successfully generated $filePath with ${items.length} records.');
}

void main() {
  final dir = Directory('c:/Users/kaleb/Documents/Mobile_Banking/docs');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. M-PESA (Safaricom Ethiopia) - Sender: MPESA
  // ═══════════════════════════════════════════════════════════════════════════
  final mpesaItems = [
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 10, 9, 15, 0),
      body: 'You have received ETB 1,200.00 from ABEBE KEBEDE 0970112233 on 10/08/2026 at 09:15:00. New M-PESA balance is ETB 1,200.00. Transaction ID: MP2608100012.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 11, 14, 30, 0),
      body: 'You have sent ETB 350.00 to MERON GETACHEW 0970445566 on 11/08/2026 at 14:30:00. Fee ETB 0.00. New M-PESA balance is ETB 850.00. Transaction ID: MP2608110045.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 12, 11, 45, 0),
      body: 'You have paid ETB 280.00 to KALDIS COFFEE (Till 883322) on 12/08/2026 at 11:45:00. Fee ETB 0.00. New M-PESA balance is ETB 570.00. Transaction ID: MP2608120088.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 13, 10, 0, 0),
      body: 'You bought ETB 100.00 of airtime on 13/08/2026 at 10:00:00. New M-PESA balance is ETB 470.00. Transaction ID: MP2608130105.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 13, 15, 20, 0),
      body: 'You bought ETB 50.00 of airtime for 0970112233 on 13/08/2026 at 15:20:00. New M-PESA balance is ETB 420.00. Transaction ID: MP2608130115.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 14, 8, 45, 0),
      body: 'You bought ETB 150.00 of Monthly Data Bundle on 14/08/2026 at 08:45:00. New M-PESA balance is ETB 270.00. Transaction ID: MP2608140201.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 14, 16, 20, 0),
      body: 'ETB 5,000.00 transferred from CBE Account 1000xxxx1234 to your M-PESA account on 14/08/2026 at 16:20:00. New M-PESA balance is ETB 5,270.00. Transaction ID: MP2608140210.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 15, 12, 10, 0),
      body: 'You have transferred ETB 1,500.00 to Bank of Abyssinia Account 124xxxx5566 on 15/08/2026 at 12:10:00. Fee ETB 10.00. New M-PESA balance is ETB 3,760.00. Transaction ID: MP2608150315.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 16, 18, 0, 0),
      body: 'You have withdrawn ETB 1,000.00 from Agent 2519709988 on 16/08/2026 at 18:00:00. Fee ETB 15.00. New M-PESA balance is ETB 2,745.00. Transaction ID: MP2608160420.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 17, 13, 30, 0),
      body: 'You have deposited ETB 4,000.00 at Agent 2519701122 on 17/08/2026 at 13:30:00. New M-PESA balance is ETB 6,745.00. Transaction ID: MP2608170525.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 18, 15, 0, 0),
      body: 'Transaction MP2608110045 has been reversed. ETB 350.00 has been credited to your M-PESA account on 18/08/2026 at 15:00:00. New M-PESA balance is ETB 7,095.00. Transaction ID: MP2608180630.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 19, 19, 15, 0),
      body: 'You have paid ETB 600.00 to TOTALENERGIES BOLE (Till 994411) on 19/08/2026 at 19:15:00. Fee ETB 0.00. New M-PESA balance is ETB 6,495.00. Transaction ID: MP2608190740.',
    ),
  ];
  writeXmlFile('c:/Users/kaleb/Documents/Mobile_Banking/docs/M-Pesa.xml', 'M-Pesa', mpesaItems);

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. ZEMEN BANK - Sender: Zemen Bank
  // ═══════════════════════════════════════════════════════════════════════════
  final zemenItems = [
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 10, 10, 0, 0),
      body: 'Dear Customer, your account 100xxxx1234 has been credited with ETB 35,000.00 by TECH PLC SALARY on 10/08/2026. A/c Available Bal. is ETB 45,200.00. Ref: ZEMSAL260810.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 11, 15, 10, 0),
      body: 'Dear Customer, ETB 2,000.00 has been withdrawn from your account 100xxxx1234 via ATM at BOLE BRANCH on 11/08/2026. A/c Available Bal. is ETB 43,200.00.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 12, 13, 25, 0),
      body: 'Dear Customer, your account 100xxxx1234 has been debited with Birr 1,450.00 due to POS TRANSACTION at FRESH CORNER SUPERMARKET on 12/08/2026. Available balance is Birr 41,750.00. Ref: POS44321.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 13, 17, 40, 0),
      body: 'Dear Customer, Inward RTGS transfer of ETB 20,000.00 from NATIONAL BANK to your account 100xxxx1234 completed. A/c Available Bal. is ETB 61,750.00. Ref: ZEM987654.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 14, 11, 15, 0),
      body: 'Dear Customer, ETB 5,000.00 transferred from account 100xxxx1234 to DANIEL MEKONNEN on 14/08/2026. Charge ETB 5.00. Available Bal. is ETB 56,745.00. Txn ID: ZEM887766.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 15, 16, 50, 0),
      body: 'Dear Customer, ETB 1,000.00 transferred to Telebirr Wallet 0911223344 from account 100xxxx1234 on 15/08/2026. Available Bal. is ETB 55,745.00. Ref: ZEMTB9911.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 16, 12, 30, 0),
      body: 'Dear Customer, your account 100xxxx1234 has been debited with ETB 350.00 for Airtime top-up on 16/08/2026. Available Bal. is ETB 55,395.00. Ref: ZEMAIR44.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 17, 14, 20, 0),
      body: 'Dear Customer, your account 100xxxx1234 credited with ETB 4,500.00 from BIRHANU HAILE on 17/08/2026. A/c Available Bal. is ETB 59,895.00. Ref: ZEMCR5511.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 18, 9, 45, 0),
      body: 'Dear Customer, your account 100xxxx1234 debited with ETB 750.00 for ELECTRICITY UTILITY PAYMENT on 18/08/2026. Available Bal. is ETB 59,145.00. Ref: ZEMUTL88.',
    ),
    SmsItem(
      address: 'Zemen Bank',
      dateTime: DateTime(2026, 8, 19, 18, 0, 0),
      body: 'Dear Customer, your account 100xxxx1234 debited with ETB 30.00 for Monthly SMS Service Charge on 19/08/2026. Available Bal. is ETB 59,115.00. Ref: ZEMFEE99.',
    ),
  ];
  writeXmlFile('c:/Users/kaleb/Documents/Mobile_Banking/docs/Zemen Bank.xml', 'Zemen Bank', zemenItems);

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. NIB BANK - Sender: NIB
  // ═══════════════════════════════════════════════════════════════════════════
  final nibItems = [
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 10, 11, 0, 0),
      body: 'Dear Customer, your A/C 440xxxx1122 has been credited with ETB 6,000.00 by BIRUK ASSEFA on 10/08/2026. Available Balance: ETB 18,500.00. Ref: NIB112233.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 11, 16, 45, 0),
      body: 'Dear Customer, your A/C 440xxxx1122 has been debited with ETB 1,500.00 on 11/08/2026. Service Charge: ETB 5.00. Total Debited: ETB 1,505.00. Available Balance: ETB 16,995.00. Ref: NIB889900.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 12, 14, 10, 0),
      body: 'Dear Customer, you have transferred ETB 2,000.00 from A/C 440xxxx1122 to SELAMAWIT KASSA on 12/08/2026. Service Charge: ETB 2.00 VAT: ETB 0.30. Available Balance: ETB 14,992.70. Ref: NIB556677.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 13, 9, 30, 0),
      body: 'Dear Customer, you have purchased airtime of ETB 50.00 for 0911554433 from A/C 440xxxx1122 on 13/08/2026. Available Balance: ETB 14,942.70. Ref: NIBAIR88.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 14, 18, 20, 0),
      body: 'Dear Customer, your A/C 440xxxx1122 has been credited with ETB 12,500.00 via IPS from CBE on 14/08/2026. Available Balance: ETB 27,442.70. Ref: NIBIPS99.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 15, 12, 0, 0),
      body: 'Dear Customer, your A/C 440xxxx1122 has been debited with ETB 3,000.00 at ATM PIASSA on 15/08/2026. Available Balance: ETB 24,442.70. Ref: NIBATM33.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 16, 15, 40, 0),
      body: 'Dear Customer, you have paid ETB 680.00 for ELECTRIC UTILITY from A/C 440xxxx1122 on 16/08/2026. Available Balance: ETB 23,762.70. Ref: NIBUTL44.',
    ),
    SmsItem(
      address: 'NIB',
      dateTime: DateTime(2026, 8, 17, 10, 15, 0),
      body: 'Dear Customer, your A/C 440xxxx1122 credited with ETB 22,000.00 by ABC CORP SALARY on 17/08/2026. Available Balance: ETB 45,762.70. Ref: NIBSAL22.',
    ),
  ];
  writeXmlFile('c:/Users/kaleb/Documents/Mobile_Banking/docs/Nib Bank.xml', 'Nib Bank', nibItems);

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. AMHARA BANK - Sender: Amhara Bank
  // ═══════════════════════════════════════════════════════════════════════════
  final amharaItems = [
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 10, 8, 30, 0),
      body: 'Your Account 330xxxx9911 credited with ETB 2,500.00 from TESFAYE TADESSE on 10/08/2026. Current Balance ETB 12,000.00. Ref: AMH332211 Receipt: https://amharabank.et/receipt/AMH332211',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 11, 12, 15, 0),
      body: 'Your Account 330xxxx9911 debited with ETB 1,000.00 transferred to MESERET BEKELE on 11/08/2026. Current Balance ETB 11,000.00. Ref: AMH445566',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 12, 17, 0, 0),
      body: 'Your Account 330xxxx9911 credited with ETB 8,000.00 via IPS from CBE (YOHANNES ALEMU) on 12/08/2026. Current Balance ETB 19,000.00. Ref: AMH887766',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 13, 15, 45, 0),
      body: 'Your Account 330xxxx9911 debited with ETB 650.00 for WATER UTILITY on 13/08/2026. Current Balance ETB 18,350.00. Ref: AMHUTIL99',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 14, 11, 30, 0),
      body: 'Your Account 330xxxx9911 debited with ETB 2,000.00 at ATM BAHIR DAR on 14/08/2026. Current Balance ETB 16,350.00. Ref: AMHATM77',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 15, 14, 10, 0),
      body: 'Your Account 330xxxx9911 credited with ETB 15,000.00 by SALARY TRANSFER on 15/08/2026. Current Balance ETB 31,350.00. Ref: AMHSAL88',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 16, 10, 20, 0),
      body: 'Your Account 330xxxx9911 debited with ETB 100.00 for Airtime purchase on 16/08/2026. Current Balance ETB 31,250.00. Ref: AMHAIR12',
    ),
    SmsItem(
      address: 'Amhara Bank',
      dateTime: DateTime(2026, 8, 17, 16, 40, 0),
      body: 'Your Account 330xxxx9911 debited with ETB 1,500.00 transferred to Telebirr 0918112233 on 17/08/2026. Current Balance ETB 29,750.00. Ref: AMHTB55',
    ),
  ];
  writeXmlFile('c:/Users/kaleb/Documents/Mobile_Banking/docs/Amhara Bank.xml', 'Amhara Bank', amharaItems);
}
