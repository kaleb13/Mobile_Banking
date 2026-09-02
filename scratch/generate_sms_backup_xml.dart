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

void main() {
  final List<SmsItem> items = [
    // ═════════════════════════════════════════════════════════════════════════
    // 1. M-PESA (Safaricom Ethiopia) - Sender: MPESA
    // ═════════════════════════════════════════════════════════════════════════
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
      body: 'You have paid ETB 280.00 to KALDIS COFFEE on 12/08/2026 at 11:45:00. New M-PESA balance is ETB 570.00. Transaction ID: MP2608120088.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 13, 10, 0, 0),
      body: 'You bought ETB 100.00 of airtime on 13/08/2026 at 10:00:00. New M-PESA balance is ETB 470.00. Transaction ID: MP2608130105.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 14, 16, 20, 0),
      body: 'ETB 5,000.00 transferred from CBE Account 1000xxxx1234 to your M-PESA account on 14/08/2026 at 16:20:00. New M-PESA balance is ETB 5,470.00. Transaction ID: MP2608140210.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 15, 12, 10, 0),
      body: 'You have transferred ETB 1,500.00 to Bank of Abyssinia Account 124xxxx5566 on 15/08/2026 at 12:10:00. Fee ETB 10.00. New M-PESA balance is ETB 3,960.00. Transaction ID: MP2608150315.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 16, 18, 0, 0),
      body: 'You have withdrawn ETB 1,000.00 from Agent 2519709988 on 16/08/2026 at 18:00:00. Fee ETB 15.00. New M-PESA balance is ETB 2,945.00. Transaction ID: MP2608160420.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 17, 8, 45, 0),
      body: 'You bought ETB 150.00 of Monthly Data Bundle on 17/08/2026 at 08:45:00. New M-PESA balance is ETB 2,795.00. Transaction ID: MP2608170511.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 18, 15, 30, 0),
      body: 'You have received ETB 3,000.00 from WORKU TESSEMA 0970556677 on 18/08/2026 at 15:30:00. New M-PESA balance is ETB 5,795.00. Transaction ID: MP2608180622.',
    ),
    SmsItem(
      address: 'MPESA',
      dateTime: DateTime(2026, 8, 19, 19, 15, 0),
      body: 'You have paid ETB 450.00 to TOTALENERGIES BOLE on 19/08/2026 at 19:15:00. New M-PESA balance is ETB 5,345.00. Transaction ID: MP2608190733.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 2. ZEMEN BANK - Sender: Zemen Bank / ZEMEN
    // ═════════════════════════════════════════════════════════════════════════
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

    // ═════════════════════════════════════════════════════════════════════════
    // 3. NIB BANK - Sender: NIB / Nib Bank
    // ═════════════════════════════════════════════════════════════════════════
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

    // ═════════════════════════════════════════════════════════════════════════
    // 4. AMHARA BANK - Sender: Amhara Bank / AMHARA
    // ═════════════════════════════════════════════════════════════════════════
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

    // ═════════════════════════════════════════════════════════════════════════
    // 5. HIBRET BANK - Sender: Hibret Bank / Hibir Mobile
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 10, 14, 0, 0),
      body: 'Dear Customer, your account 112xxxx8899 has been credited with ETB 7,500.00 by SOLOMON HAILE on 10/08/2026. Available Balance is ETB 28,500.00. Ref: HIB334455.',
    ),
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 11, 18, 30, 0),
      body: 'Dear Customer, You have transferred ETB 3,500.00 from account 112xxxx8899 to DANIEL MEKONNEN. Transaction Ref: HIB998877. Available Balance is ETB 25,000.00.',
    ),
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 12, 10, 15, 0),
      body: 'Dear Customer, ETB 1,000.00 transferred to Telebirr Wallet 0911000000 from account 112xxxx8899. Fee: ETB 0.00. Available Balance: ETB 24,000.00. Ref: HIB123456.',
    ),
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 13, 16, 40, 0),
      body: 'Dear Customer, ETB 2,000.00 withdrawn from ATM at MEGENAGNA on 13/08/2026 from account 112xxxx8899. Available Balance is ETB 22,000.00. Ref: HIBATM99.',
    ),
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 14, 13, 20, 0),
      body: 'Dear Customer, you have paid ETB 850.00 due to POS Purchase at NOVAS SUPERMARKET on 14/08/2026. Available Balance: ETB 21,150.00. Ref: HIBPOS22.',
    ),
    SmsItem(
      address: 'Hibret Bank',
      dateTime: DateTime(2026, 8, 15, 9, 10, 0),
      body: 'Dear Customer, you have bought ETB 50.00 airtime for 0911443322 from account 112xxxx8899 on 15/08/2026. Available Balance: ETB 21,100.00. Ref: HIBAIR44.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 6. BERHAN BANK - Sender: Berhan Bank / BERHAN
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Berhan Bank',
      dateTime: DateTime(2026, 8, 10, 12, 0, 0),
      body: 'Dear Customer, your A/C 220xxxx5544 credited with ETB 10,000.00 by ALMAZ WORKU on 10/08/2026. Bal: ETB 18,500.00. Txn Ref: BRH112233.',
    ),
    SmsItem(
      address: 'Berhan Bank',
      dateTime: DateTime(2026, 8, 11, 15, 30, 0),
      body: 'Dear Customer, ETB 4,000.00 debited from A/C 220xxxx5544 for Transfer to KASSAHUN GEMECHU on 11/08/2026. Bal: ETB 14,500.00. Txn Ref: BRH554433.',
    ),
    SmsItem(
      address: 'Berhan Bank',
      dateTime: DateTime(2026, 8, 12, 17, 15, 0),
      body: 'Dear Customer, ETB 800.00 debited from A/C 220xxxx5544 for Telebirr Transfer to 0922334455 on 12/08/2026. Bal: ETB 13,700.00. Txn Ref: BRHTB88.',
    ),
    SmsItem(
      address: 'Berhan Bank',
      dateTime: DateTime(2026, 8, 13, 11, 45, 0),
      body: 'Dear Customer, ETB 1,500.00 debited from A/C 220xxxx5544 at ATM BOLE on 13/08/2026. Bal: ETB 12,200.00. Txn Ref: BRHATM44.',
    ),
    SmsItem(
      address: 'Berhan Bank',
      dateTime: DateTime(2026, 8, 14, 14, 0, 0),
      body: 'Dear Customer, your A/C 220xxxx5544 credited with ETB 20,000.00 by SALARY TRANSFER on 14/08/2026. Bal: ETB 32,200.00. Txn Ref: BRHSAL55.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 7. APOLLO (BOA Digital) - Sender: Apollo / APOLLO
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Apollo',
      dateTime: DateTime(2026, 8, 10, 16, 0, 0),
      body: 'You received ETB 1,800.00 from GIRMA CHALA via EthSwitch to your Apollo account on 10/08/2026. Balance: ETB 6,200.00. Ref: APL776655.',
    ),
    SmsItem(
      address: 'Apollo',
      dateTime: DateTime(2026, 8, 11, 11, 20, 0),
      body: 'You sent ETB 500.00 to MERON GETACHEW from your Apollo account on 11/08/2026. Balance: ETB 5,700.00. Ref: APL223344.',
    ),
    SmsItem(
      address: 'Apollo',
      dateTime: DateTime(2026, 8, 12, 13, 45, 0),
      body: 'You bought ETB 50.00 airtime for 0911223344 on 12/08/2026. Balance: ETB 5,650.00. Ref: APLAIR11.',
    ),
    SmsItem(
      address: 'Apollo',
      dateTime: DateTime(2026, 8, 13, 18, 10, 0),
      body: 'You paid ETB 350.00 via Apollo QR to BAKER BASKET on 13/08/2026. Balance: ETB 5,300.00. Ref: APLQR99.',
    ),
    SmsItem(
      address: 'Apollo',
      dateTime: DateTime(2026, 8, 14, 15, 30, 0),
      body: 'You transferred ETB 1,000.00 to Telebirr Wallet 0935112233 on 14/08/2026. Balance: ETB 4,300.00. Ref: APLTB88.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 8. COOPERATIVE BANK OF OROMIA - Sender: Coopbank / COOP
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 10, 13, 15, 0),
      body: 'Dear Customer, your account 1000xxxx7788 has been credited with ETB 4,500.00 from GUYE TOLOSA on 10/08/2026. Available Balance is ETB 14,500.00. Ref: CPB991122.',
    ),
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 11, 17, 0, 0),
      body: 'Dear Customer, you transferred ETB 1,200.00 to BIKILA DERESE on 11/08/2026. Service fee ETB 2.00. Available Balance is ETB 13,298.00. Ref: CPB334455.',
    ),
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 12, 10, 45, 0),
      body: 'Dear Customer, ETB 500.00 transferred to Coopay Wallet from account 1000xxxx7788 on 12/08/2026. Available Balance is ETB 12,798.00. Ref: CPBWL88.',
    ),
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 13, 14, 20, 0),
      body: 'Dear Customer, you have withdrawn ETB 2,000.00 at ATM ADAMA on 13/08/2026. Available Balance is ETB 10,798.00. Ref: CPBATM11.',
    ),
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 14, 16, 50, 0),
      body: 'Dear Customer, you have purchased airtime of ETB 100.00 for 0922445566 on 14/08/2026. Available Balance is ETB 10,698.00. Ref: CPBAIR99.',
    ),
    SmsItem(
      address: 'Coopbank',
      dateTime: DateTime(2026, 8, 15, 11, 30, 0),
      body: 'Dear Customer, your account 1000xxxx7788 has been credited with ETB 18,000.00 by COOP SALARY on 15/08/2026. Available Balance is ETB 28,698.00. Ref: CPBSAL77.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 9. SIINQEE BANK - Sender: Siinqee Bank / SIINQEE
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Siinqee Bank',
      dateTime: DateTime(2026, 8, 10, 10, 30, 0),
      body: "Kabajamoo Maamila, herregni keessan 104xxxx2233 qarshii 3,000.00 obbo CHALA BOGALE irraa galii ta'eera. Haalli herregaa ETB 8,500.00. Ref: SQB112233.",
    ),
    SmsItem(
      address: 'Siinqee Bank',
      dateTime: DateTime(2026, 8, 11, 14, 45, 0),
      body: 'Kabajamoo Maamila, herrega keessan 104xxxx2233 irraa qarshiin 1,000.00 gara TOLERA GEDA ti dabarfameera. Haalli herregaa ETB 7,500.00. Ref: SQB445566.',
    ),
    SmsItem(
      address: 'Siinqee Bank',
      dateTime: DateTime(2026, 8, 12, 12, 10, 0),
      body: 'Dear Customer, your account 104xxxx2233 has been credited with ETB 5,000.00 from KEBEDE TADESSE on 12/08/2026. Available Balance: ETB 12,500.00. Ref: SQB778899.',
    ),
    SmsItem(
      address: 'Siinqee Bank',
      dateTime: DateTime(2026, 8, 13, 16, 20, 0),
      body: 'Dear Customer, you have transferred ETB 2,500.00 to HUNDE DUGASA on 13/08/2026. Available Balance: ETB 10,000.00. Ref: SQB990011.',
    ),
    SmsItem(
      address: 'Siinqee Bank',
      dateTime: DateTime(2026, 8, 14, 9, 50, 0),
      body: 'Dear Customer, you have bought airtime worth ETB 50.00 on 14/08/2026. Available Balance: ETB 9,950.00. Ref: SQBAIR22.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 10. OROMIA BANK - Sender: Oromia Bank / OROMIA
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Oromia Bank',
      dateTime: DateTime(2026, 8, 10, 15, 0, 0),
      body: 'Dear Customer, your account 101xxxx4455 has been credited with ETB 5,000.00 by GADISA ABERA on 10/08/2026. Available Balance: ETB 18,200.00. Ref: ORB778899.',
    ),
    SmsItem(
      address: 'Oromia Bank',
      dateTime: DateTime(2026, 8, 11, 18, 10, 0),
      body: 'Dear Customer, you have transferred ETB 2,500.00 to HAWINE DANIEL on 11/08/2026. Available Balance: ETB 15,700.00. Ref: ORB223344.',
    ),
    SmsItem(
      address: 'Oromia Bank',
      dateTime: DateTime(2026, 8, 12, 11, 30, 0),
      body: 'Dear Customer, ETB 1,000.00 withdrawn from ATM at JIMMA on 12/08/2026. Available Balance: ETB 14,700.00. Ref: ORBATM55.',
    ),
    SmsItem(
      address: 'Oromia Bank',
      dateTime: DateTime(2026, 8, 13, 14, 40, 0),
      body: 'Dear Customer, you bought ETB 100.00 Airtime for 0911778899 on 13/08/2026. Available Balance: ETB 14,600.00. Ref: ORBAIR66.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 11. WEGAGEN BANK - Sender: Wegagen Bank / WEGAGEN
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Wegagen Bank',
      dateTime: DateTime(2026, 8, 10, 11, 45, 0),
      body: 'Dear Customer, your Account 089xxxx1122 has been credited with ETB 3,800.00 from HAGOS BERHE on 10/08/2026. Available Balance: ETB 11,400.00. Txn Ref: WGB556677.',
    ),
    SmsItem(
      address: 'Wegagen Bank',
      dateTime: DateTime(2026, 8, 11, 16, 20, 0),
      body: 'Dear Customer, your Account 089xxxx1122 has been debited with ETB 1,500.00 transferred to KIROS GEBRE on 11/08/2026. Available Balance: ETB 9,900.00. Txn Ref: WGB889900.',
    ),
    SmsItem(
      address: 'Wegagen Bank',
      dateTime: DateTime(2026, 8, 12, 13, 10, 0),
      body: 'Dear Customer, your Account 089xxxx1122 debited with ETB 800.00 for POS Purchase at MEKELLE MART on 12/08/2026. Available Balance: ETB 9,100.00. Txn Ref: WGBPOS11.',
    ),
    SmsItem(
      address: 'Wegagen Bank',
      dateTime: DateTime(2026, 8, 13, 17, 30, 0),
      body: 'Dear Customer, your Account 089xxxx1122 debited with ETB 2,000.00 at ATM on 13/08/2026. Available Balance: ETB 7,100.00. Txn Ref: WGBATM22.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 12. ENAT BANK - Sender: Enat Bank / ENAT
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Enat Bank',
      dateTime: DateTime(2026, 8, 10, 14, 30, 0),
      body: 'Dear Customer, Account 055xxxx3344 credited with ETB 4,000.00 by RAHEL TADESSE on 10/08/2026. Balance: ETB 16,000.00. Ref: ENT112233.',
    ),
    SmsItem(
      address: 'Enat Bank',
      dateTime: DateTime(2026, 8, 11, 10, 15, 0),
      body: 'Dear Customer, Account 055xxxx3344 debited with ETB 1,200.00 transferred to HELEN KEBEDE on 11/08/2026. Balance: ETB 14,800.00. Ref: ENT445566.',
    ),
    SmsItem(
      address: 'Enat Bank',
      dateTime: DateTime(2026, 8, 12, 15, 45, 0),
      body: 'Dear Customer, Account 055xxxx3344 debited with ETB 500.00 for POS payment on 12/08/2026. Balance: ETB 14,300.00. Ref: ENTPOS77.',
    ),
    SmsItem(
      address: 'Enat Bank',
      dateTime: DateTime(2026, 8, 13, 12, 0, 0),
      body: 'Dear Customer, Account 055xxxx3344 debited with ETB 100.00 for Airtime on 13/08/2026. Balance: ETB 14,200.00. Ref: ENTAIR88.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 13. BUNNA BANK - Sender: Bunna Bank / BUNNA
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Bunna Bank',
      dateTime: DateTime(2026, 8, 10, 13, 0, 0),
      body: 'Dear Customer, your A/C 023xxxx9988 has been credited with ETB 2,200.00 by YIDNEKACHEW MELESE on 10/08/2026. Available Balance: ETB 9,700.00. Ref: BNB123456.',
    ),
    SmsItem(
      address: 'Bunna Bank',
      dateTime: DateTime(2026, 8, 11, 17, 30, 0),
      body: 'Dear Customer, your A/C 023xxxx9988 has been debited with ETB 800.00 transferred to DAWIT ASSEFA on 11/08/2026. Available Balance: ETB 8,900.00. Ref: BNB789012.',
    ),
    SmsItem(
      address: 'Bunna Bank',
      dateTime: DateTime(2026, 8, 12, 11, 15, 0),
      body: 'Dear Customer, your A/C 023xxxx9988 debited with ETB 1,000.00 at ATM GERJI on 12/08/2026. Available Balance: ETB 7,900.00. Ref: BNBATM33.',
    ),
    SmsItem(
      address: 'Bunna Bank',
      dateTime: DateTime(2026, 8, 13, 16, 0, 0),
      body: 'Dear Customer, your A/C 023xxxx9988 debited with ETB 50.00 for Airtime topup on 13/08/2026. Available Balance: ETB 7,850.00. Ref: BNBAIR44.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 14. HIJRA BANK - Sender: Hijra Bank / HIJRA
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Hijra Bank',
      dateTime: DateTime(2026, 8, 10, 9, 45, 0),
      body: 'Dear Customer, your Amanah Account 077xxxx1122 has been credited with ETB 6,500.00 from MOHAMMED ALI on 10/08/2026. Balance: ETB 21,500.00. Ref: HJR445566.',
    ),
    SmsItem(
      address: 'Hijra Bank',
      dateTime: DateTime(2026, 8, 11, 14, 15, 0),
      body: 'Dear Customer, you have transferred ETB 2,000.00 from Amanah Account 077xxxx1122 to FATIMA AHMED on 11/08/2026. Balance: ETB 19,500.00. Ref: HJR778899.',
    ),
    SmsItem(
      address: 'Hijra Bank',
      dateTime: DateTime(2026, 8, 12, 18, 0, 0),
      body: 'Dear Customer, ETB 1,500.00 withdrawn from ATM MERKATO from account 077xxxx1122 on 12/08/2026. Balance: ETB 18,000.00. Ref: HJRATM11.',
    ),
    SmsItem(
      address: 'Hijra Bank',
      dateTime: DateTime(2026, 8, 13, 10, 30, 0),
      body: 'Dear Customer, ETB 100.00 debited for Airtime from account 077xxxx1122 on 13/08/2026. Balance: ETB 17,900.00. Ref: HJRAIR22.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 15. TSEDEY BANK - Sender: Tsedey Bank / TSEDEY
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Tsedey Bank',
      dateTime: DateTime(2026, 8, 10, 11, 10, 0),
      body: 'Dear Customer, your Account 066xxxx8877 credited with ETB 1,800.00 by ASTER BEKELE on 10/08/2026. Available Balance: ETB 7,300.00. Ref: TSD112233.',
    ),
    SmsItem(
      address: 'Tsedey Bank',
      dateTime: DateTime(2026, 8, 11, 15, 40, 0),
      body: 'Dear Customer, you have transferred ETB 500.00 to TADESSE WORKU on 11/08/2026. Available Balance: ETB 6,800.00. Ref: TSD445566.',
    ),
    SmsItem(
      address: 'Tsedey Bank',
      dateTime: DateTime(2026, 8, 12, 13, 20, 0),
      body: 'Dear Customer, ETB 1,000.00 withdrawn from ATM on 12/08/2026. Available Balance: ETB 5,800.00. Ref: TSDATM77.',
    ),
    SmsItem(
      address: 'Tsedey Bank',
      dateTime: DateTime(2026, 8, 13, 9, 15, 0),
      body: 'Dear Customer, you bought ETB 50.00 airtime on 13/08/2026. Available Balance: ETB 5,750.00. Ref: TSDAIR88.',
    ),

    // ═════════════════════════════════════════════════════════════════════════
    // 16. GLOBAL BANK ETHIOPIA - Sender: Global Bank / GLOBAL
    // ═════════════════════════════════════════════════════════════════════════
    SmsItem(
      address: 'Global Bank',
      dateTime: DateTime(2026, 8, 10, 12, 45, 0),
      body: 'Dear Customer, Account 044xxxx5566 has been credited with ETB 3,500.00 from KINFE GEBRE on 10/08/2026. Available Balance: ETB 12,500.00. Ref: GBL998877.',
    ),
    SmsItem(
      address: 'Global Bank',
      dateTime: DateTime(2026, 8, 11, 16, 50, 0),
      body: 'Dear Customer, Account 044xxxx5566 has been debited with ETB 1,000.00 transferred to EDEN NEGASH on 11/08/2026. Available Balance: ETB 11,500.00. Ref: GBL223344.',
    ),
    SmsItem(
      address: 'Global Bank',
      dateTime: DateTime(2026, 8, 12, 14, 30, 0),
      body: 'Dear Customer, Account 044xxxx5566 debited with ETB 450.00 due to POS Purchase on 12/08/2026. Available Balance: ETB 11,050.00. Ref: GBLPOS55.',
    ),
    SmsItem(
      address: 'Global Bank',
      dateTime: DateTime(2026, 8, 13, 11, 0, 0),
      body: 'Dear Customer, Account 044xxxx5566 debited with ETB 1,500.00 at ATM on 13/08/2026. Available Balance: ETB 9,550.00. Ref: GBLATM66.',
    ),
  ];

  // Sort chronologically
  items.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final buffer = StringBuffer();
  buffer.writeln("<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>");
  buffer.writeln("<!--File Created By SMS Backup & Restore Pro v10.24.003 for Multi-Bank Integration Testing-->");
  buffer.writeln("<!--");
  buffer.writeln("");
  buffer.writeln("To view this file in a more readable format, visit https://synctech.com.au/view-backup/");
  buffer.writeln("");
  buffer.writeln("-->");

  final backupDateMs = DateTime.now().millisecondsSinceEpoch;
  buffer.writeln('<smses count="${items.length}" backup_set="f47a8b12-98c3-4de1-90fa-88127394ab56" backup_date="$backupDateMs" type="full">');

  final readableFmt = DateFormat("d MMM yyyy h:mm:ss a");

  for (final item in items) {
    final ms = item.dateTime.millisecondsSinceEpoch;
    final dateSentMs = ms - 3000;
    final readable = readableFmt.format(item.dateTime).toLowerCase();

    // Escape XML entities
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

  final outPath = 'c:/Users/kaleb/Documents/Mobile_Banking/Multi_Bank_Test_SMS_Backup.xml';
  File(outPath).writeAsStringSync(buffer.toString());
  print('Successfully generated $outPath with ${items.length} SMS records across 16 banks!');
}
