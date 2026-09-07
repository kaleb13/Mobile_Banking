import 'package:mobile_banking_app/services/ahadu_parser.dart';
import 'package:mobile_banking_app/services/bank_senders.dart';

void main() {
  final testMessages = [
    '''Dear KALEB,
You have made a transfer of ETB 20,000.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 972665987 with reference number w2b17883520939961797 on 02-SEP-26. 
Your Available Balance is ETB 10,475.90. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/02-SEP-26/ 5466
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''',

    '''Dear KALEB ,

A Deposit of ETB ETB 30,867.00 to your account number XXXXXXXXX0101 on 02-09-2026 . Your current Balance is ETB  31073.9 .

Ahadu Bank.''',

    '''Dear KALEB,
You have made a transfer of ETB 300.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 935389104 with reference number w2b17881056991545868 on 30-AUG-26. 
Your Available Balance is ETB 161.79. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/30-AUG-26/ 5545
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''',

    '''Dear KALEB,
You have made a transfer of ETB 1,000.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 972665987 with reference number w2b17868146592474446 on 15-AUG-26. 
Your Available Balance is ETB 463.23. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/15-AUG-26/ 8503
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''',

    '''Dear KALEB,
You have made a transfer of ETB 500.00. Including Service charge and VAT (15%) from account number 008XXXXXX0101 to Telebirr of 922557340 with reference number w2b17868144664623378 on 15-AUG-26. 
Your Available Balance is ETB 1,468.03. 
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/15-AUG-26/ 8482
For Fayda ID Update
https://verifayda.ahadubank.com/
Ahadu Bank!''',

    '''Dear Customer,
A debit of ETB 341.00 from your account XXXXXXXXX0101 on 14-08-2026 . Your Current balance is ETB 2,020.43  (A transaction fee with 15% VAT is applied).

Ahadu Bank
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/14-AUG-26/3926
For Fayda ID Update
https://verifayda.ahadubank.com/''',

    '''Dear Customer,
A debit of ETB 690.00 from your account XXXXXXXXX0101 on 12-08-2026 . Your Current balance is ETB 2,361.43  (A transaction fee with 15% VAT is applied).

Ahadu Bank
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/12-AUG-26/4418
For Fayda ID Update
https://verifayda.ahadubank.com/''',

    '''Dear Customer,
A Credit of ETB 173.00 to your account no XXXXXXXXX0101 from  on 10-08-2026 . Current Balance is ETB 3,051.43 .

Ahadu Bank
https://receipt.ahadubank.com/digitalreceipt?es=1008700007948/10-AUG-26/11860
For Fayda ID Update
https://verifayda.ahadubank.com/'''
  ];

  for (int i = 0; i < testMessages.length; i++) {
    final msg = testMessages[i];
    final isIgnored = BankSenders.isIgnoredMessage(msg);
    final parsed = AhaduParser.parse(msg, DateTime.now());
    print('Message #${i + 1}: isIgnored=$isIgnored | parsed=${parsed != null ? "${parsed.type.toUpperCase()} ETB ${parsed.amount} | Bal: ${parsed.totalBalance} | Party: ${parsed.counterparty} | ID: ${parsed.id}" : "FAILED"}');
  }
}
